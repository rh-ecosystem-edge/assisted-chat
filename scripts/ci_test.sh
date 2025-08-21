#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

SECRETS_BASE_PATH="${SECRETS_BASE_PATH:-/var/run/secrets}"

oc create secret generic -n "$NAMESPACE" assisted-chat-ssl-ci --from-file=client_id=/var/run/secrets/sso-ci/client_id \
    --from-file=client_secret=/var/run/secrets/sso-ci/client_secret

oc process -p IMAGE_NAME="$ASSISTED_CHAT_TEST" -p SSL_CLIENT_SECRET_NAME=assisted-chat-ssl-ci -f test/prow/template.yaml --local | oc apply -n "$NAMESPACE" -f -

sleep 5
oc get pods -n "$NAMESPACE"
POD_NAME=$(oc get pods -n "$NAMESPACE" | tr -s ' ' | cut -d ' ' -f1 | grep assisted-chat-eval-test)

TIMEOUT=600
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Check if the pod's status is "Running"
    CURRENT_STATUS=$(oc get pod "$POD_NAME" -n "$NAMESPACE" -o=jsonpath='{.status.phase}')
    CURRENT_RESTARTS=$(oc get pod "$POD_NAME" -n "$NAMESPACE" -o=jsonpath='{.status.containerStatuses[0].restartCount}')
    if [[ $CURRENT_RESTARTS -gt 0 ]]; then
        echo "Pod ${POD_NAME} was restarted, so the tests should run at least once, exiting"
        echo "########################## Start of logs ##########################"
        oc logs -p -n "$NAMESPACE" "$POD_NAME"
        echo "########################## End of logs ##########################"
        exit "$(oc get pod "$POD_NAME" -n "$NAMESPACE" -o=jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}')"
    fi
    if [[ "$CURRENT_STATUS" == "Succeeded" ]]; then
        echo "Pod ${POD_NAME} is successfully completed, exiting"
        oc logs -n "$NAMESPACE" "$POD_NAME"
        exit 0
    fi
    if [[ "$CURRENT_STATUS" == "Completed" ]]; then
        echo "Pod ${POD_NAME} is successfully completed, exiting"
        oc logs -n "$NAMESPACE" "$POD_NAME"
        exit 0
    fi

    if [[ "$CURRENT_STATUS" == "Failed" ]]; then
        echo "Pod ${POD_NAME} is Failed, exiting"
        oc logs -n "$NAMESPACE" "$POD_NAME"
        exit "$(oc get pod "$POD_NAME" -n "$NAMESPACE" -o=jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}')"
    fi

    echo "Waiting for pod $POD_NAME to be ready..."
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

oc logs -n "$NAMESPACE" "$POD_NAME"

echo "Timeout reached. Pod $POD_NAME did not become ready in time."
exit 1
