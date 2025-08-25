#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

SECRETS_BASE_PATH="${SECRETS_BASE_PATH:-/var/run/secrets}"
JOB_NAME="assisted-chat-eval-test"

oc create secret generic -n "$NAMESPACE" assisted-chat-ssl-ci --from-file=client_id=/var/run/secrets/sso-ci/client_id \
    --from-file=client_secret=/var/run/secrets/sso-ci/client_secret

oc process -p IMAGE_NAME="$ASSISTED_CHAT_TEST" -p SSL_CLIENT_SECRET_NAME=assisted-chat-ssl-ci -f test/prow/template.yaml --local | oc apply -n "$NAMESPACE" -f -

sleep 5
oc get pods -n "$NAMESPACE"

ASSISTED_CHAT_POD=$(oc get pods -n "$NAMESPACE" | tr -s ' ' | cut -d ' ' -f1 | grep -v assisted-chat-eval-test | grep assisted-chat)
oc logs -n "$NAMESPACE" "$ASSISTED_CHAT_POD"
oc events -n "$NAMESPACE"
oc describe pod -n "$NAMESPACE" "$ASSISTED_CHAT_POD"

POD_NAME=$(oc get pods -n "$NAMESPACE" | tr -s ' ' | cut -d ' ' -f1 | grep assisted-chat-eval-test)
if [[ -z "${POD_NAME}" ]]; then
    echo "No pod found with label app=assisted-chat-eval-test in namespace ${NAMESPACE}"
    oc get pods -n "$NAMESPACE"
    exit 1
fi

TIMEOUT=600
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Check if the pod's status is "Running"
    JOB_SUCCEEDED=$(oc get job "$JOB_NAME" -n "$NAMESPACE" -o=jsonpath='{.status.succeeded}' 2>/dev/null)
    JOB_FAILED=$(oc get job "$JOB_NAME" -n "$NAMESPACE" -o=jsonpath='{.status.failed}' 2>/dev/null)

    if [[  "$JOB_SUCCEEDED" -gt 0  ]]; then
        echo "Pod ${POD_NAME} is successfully completed, exiting"
        oc logs -n "$NAMESPACE" "$POD_NAME"
        exit 0
    fi

    if [[  "$JOB_FAILED" -gt 0  ]]; then
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
