#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

SECRETS_BASE_PATH="${SECRETS_BASE_PATH:-/var/run/secrets}"

#All the secret are expected to be mounted under /var/run/secrets by the ci-operator

#$ASSISTED_CHAT_IMG is not in repo/image:tag format but rather in repo/<image name>@sha256:<digest>
#The template needs the tag, and it references the image by <image name>:<tag> so splitting the variable by ":" works for now

if [[ -n $ASSISTED_CHAT_IMG ]]; then
    echo "The variable ASSISTED_CHAT_IMG was proided with the value ${ASSISTED_CHAT_IMG}, using it to create the IMAGE and TAG variables for the template"
    IMAGE=$(echo "$ASSISTED_CHAT_IMG" | cut -d ":" -f1)
    TAG=$(echo "$ASSISTED_CHAT_IMG" | cut -d ":" -f2)
else
    IMAGE="quay.io/redhat-services-prod/assisted-installer-tenant/saas/assisted-chat"
    echo "The variable ASSISTED_CHAT_IMG was not provieded, downloading the latest image from ${IMAGE}"
    TAG="latest"
fi

# What secrets have we got?
ls -laR "$SECRETS_BASE_PATH"

if ! oc get secret -n "$NAMESPACE" vertex-service-account &>/dev/null; then
    echo "Creating vertex-service-account secret in namespace $NAMESPACE"
    oc create secret generic -n "$NAMESPACE" vertex-service-account --from-file=service_account="$SECRETS_BASE_PATH/vertex/service_account"
fi

if ! oc get secret -n "$NAMESPACE" insights-ingress &>/dev/null; then
    echo "Creating insights-ingress secret in namespace $NAMESPACE"
    oc create secret generic -n "$NAMESPACE" insights-ingress --from-literal=auth_token="dummy-token"
fi

if ! oc get secret -n "$NAMESPACE" llama-stack-db &>/dev/null; then
    echo "Creating llama-stack-db secret with local postgres credentials in namespace $NAMESPACE"
    oc create secret generic -n "$NAMESPACE" llama-stack-db \
        --from-literal=db.host=postgres-service \
        --from-literal=db.port=5432 \
        --from-literal=db.name=assistedchat \
        --from-literal=db.user=assistedchat \
        --from-literal=db.password=assistedchat123 \
        --from-literal=db.ca_cert=""
fi

if ! oc get secret -n "$NAMESPACE" postgres-secret &>/dev/null; then
    echo "Creating postgres-secret in namespace $NAMESPACE"

    oc create secret generic -n "$NAMESPACE" postgres-secret \
        --from-literal=POSTGRESQL_DATABASE=assistedchat \
        --from-literal=POSTGRESQL_USER=assistedchat \
        --from-literal=POSTGRESQL_PASSWORD=assistedchat123
fi

if ! oc get deployment -n "$NAMESPACE" postgres &>/dev/null; then
    echo "Creating postgres deployment in namespace $NAMESPACE"
    oc create deployment -n "$NAMESPACE" postgres --image=quay.io/sclorg/postgresql-16-c9s:c9s
    oc set env -n "$NAMESPACE" deployment/postgres --from=secret/postgres-secret
fi

if ! oc get service -n "$NAMESPACE" postgres-service &>/dev/null; then
    echo "Creating postgres service in namespace $NAMESPACE"
    oc expose -n "$NAMESPACE" deployment/postgres --name=postgres-service --port=5432
fi

if ! oc get routes -n "$NAMESPACE" &>/dev/null; then
    # Don't apply routes on clusters that don't have routes (e.g. minikube)
    FILTER='select(.kind != "Route")'
else
    FILTER='.'
fi

oc process \
    -p IMAGE="$IMAGE" \
    -p IMAGE_TAG="$TAG" \
    -p VERTEX_API_SECRET_NAME=vertex-service-account \
    -p ASSISTED_CHAT_DB_SECRET_NAME=llama-stack-db \
    -p USER_ID_CLAIM=client_id \
    -p USERNAME_CLAIM=clientHost \
    -p LIGHTSSPEED_STACK_POSTGRES_SSL_MODE=disable \
    -p LLAMA_STACK_POSTGRES_SSL_MODE=disable \
    -p LIGHTSPEED_EXPORTER_AUTH_MODE=manual \
    -f template.yaml --local |
    jq '. as $root | $root.items = [$root.items[] | '"$FILTER"']' |
    oc apply -n "$NAMESPACE" -f -

sleep 5
if  ! oc rollout status  -n $NAMESPACE deployment/assisted-chat --timeout=300s; then
    echo "Deploying assisted-chat failed, the logs of the pods are in artifacts/eval-test/gather-extra/artifacts/pods/ directory."
    exit 1
fi
