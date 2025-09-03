#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

SECRETS_BASE_PATH="${SECRETS_BASE_PATH:-/var/run/secrets}"
JOB_NAME="assisted-chat-eval-test"

if [[ -n $ASSISTED_CHAT_TEST ]]; then
    echo "The variable ASSISTED_CHAT_TEST was proided with the value ${ASSISTED_CHAT_TEST}, using it to create the IMAGE and TAG variables for the template"
else
    IMAGE="quay.io/redhat-user-workloads/assisted-installer-tenant/assisted-chat-test-image-saas-main/assisted-chat-test-image-saas-main"
    echo "The variable ASSISTED_CHAT_TEST was not provieded, downloading the latest image from ${IMAGE}"
    ASSISTED_CHAT_TEST="${IMAGE}:latest"
fi

if ! oc get secret -n "$NAMESPACE" assisted-chat-ssl-ci &>/dev/null; then
    echo "Creating assisted-chat-ssl-ci secret in namespace $NAMESPACE"
    oc create secret generic -n "$NAMESPACE" assisted-chat-ssl-ci --from-file=client_id="${SECRETS_BASE_PATH}/sso-ci/client_id" \
                                                                  --from-file=client_secret="${SECRETS_BASE_PATH}/sso-ci/client_secret"
fi

if ! oc get secret -n "$NAMESPACE" gemini &>/dev/null; then
    echo "Creating gemini secret in namespace $NAMESPACE"
    oc create secret generic -n $NAMESPACE gemini --from-file=api_key="${SECRETS_BASE_PATH}/gemini/api_key"
fi

oc process -p IMAGE_NAME="$ASSISTED_CHAT_TEST" -p SSL_CLIENT_SECRET_NAME=assisted-chat-ssl-ci -f test/prow/template.yaml --local | oc apply -n "$NAMESPACE" -f -

sleep 5
oc get pods -n "$NAMESPACE"

POD_NAME=$(oc get pods -n "$NAMESPACE" -l job-name="$JOB_NAME" -o jsonpath='{.items[0].metadata.name}')
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
        echo "The evaluation test were successful. The logs of the tests are stored in the directory artifacts/eval-test/gather-extra/artifacts/pods/ in the logs of the pod ${POD_NAME}."
        exit 0
    fi

    if [[  "$JOB_FAILED" -gt 0  ]]; then
        echo "Pod ${POD_NAME} is Failed, exiting"
        echo "The evaluation tests failed, you can see the logs of the pods under the directory artifacts/eval-test/gather-extra/artifacts/pods/."
        echo "oc events"
        oc events -n "$NAMESPACE"
        exit 1
    fi

    echo "Waiting for pod $POD_NAME to be ready..."
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done


echo "Timeout reached. Pod $POD_NAME did not become ready in time. PLease check the logs of the pods under the directory artifacts/eval-test/gather-extra/artifacts/pods/."
exit 1
