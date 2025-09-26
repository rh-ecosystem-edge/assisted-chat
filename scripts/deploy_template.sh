#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

SECRETS_BASE_PATH="${SECRETS_BASE_PATH:-/var/run/secrets}"

#All the secret are expected to be mounted under /var/run/secrets by the ci-operator

#$ASSISTED_CHAT_IMG is not in repo/image:tag format but rather in repo/<image name>@sha256:<digest>
#The template needs the tag, and it references the image by <image name>:<tag> so splitting the variable by ":" works for now

if [[ -n $ASSISTED_CHAT_IMG ]]; then
    echo "The variable ASSISTED_CHAT_IMG was provided with the value ${ASSISTED_CHAT_IMG}, using it to create the IMAGE and TAG variables for the template"
    IMAGE=$(echo "$ASSISTED_CHAT_IMG" | cut -d ":" -f1)
    TAG=$(echo "$ASSISTED_CHAT_IMG" | cut -d ":" -f2)
else
    IMAGE="quay.io/redhat-services-prod/assisted-installer-tenant/saas/assisted-chat"
    echo "The variable ASSISTED_CHAT_IMG was not provided, downloading the latest image from ${IMAGE}"
    TAG="latest"
fi

# What secrets have we got?
ls -laR "$SECRETS_BASE_PATH"

if ! oc get secret -n "$NAMESPACE" vertex-service-account &>/dev/null; then
    echo "Creating vertex-service-account secret in namespace $NAMESPACE"
    oc create secret generic -n "$NAMESPACE" vertex-service-account --from-file=service_account="$SECRETS_BASE_PATH/vertex/service_account"
fi

# Optionally create Gemini API key secret if provided
if ! oc get secret -n "$NAMESPACE" gemini &>/dev/null; then
    if [[ -n "${GEMINI_API_KEY:-}" ]]; then
        echo "Creating gemini secret from GEMINI_API_KEY env in namespace $NAMESPACE"
        oc create secret generic -n "$NAMESPACE" gemini --from-literal=api_key="$GEMINI_API_KEY"
    elif [[ -f "$SECRETS_BASE_PATH/gemini/api_key" ]]; then
        echo "Creating gemini secret from file in namespace $NAMESPACE"
        oc create secret generic -n "$NAMESPACE" gemini --from-file=api_key="$SECRETS_BASE_PATH/gemini/api_key"
    fi
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

# For localhost images, set imagePullPolicy to IfNotPresent at apply time
if [[ -n "${ASSISTED_CHAT_IMG:-}" ]] && [[ "$ASSISTED_CHAT_IMG" == localhost/* || "$ASSISTED_CHAT_IMG" == 127.0.0.1/* ]]; then
    JQ_SET_POLICY='.items |= map(if .kind=="Deployment" and .metadata.name=="assisted-chat" then (.spec.template.spec.containers |= map(.imagePullPolicy="IfNotPresent")) else . end)'
else
    JQ_SET_POLICY='.'
fi

# Choose auth claims: default (CI) vs local-dev overrides
CLAIM_USER_ID="client_id"
CLAIM_USERNAME="clientHost"
if [[ "${LOCAL_DEV_AUTH_CLAIMS:-false}" == "true" ]] || \
   ([[ -n "${ASSISTED_CHAT_IMG:-}" ]] && ([[ "$ASSISTED_CHAT_IMG" == localhost/* ]] || [[ "$ASSISTED_CHAT_IMG" == 127.0.0.1/* ]])); then
    CLAIM_USER_ID="sub"
    CLAIM_USERNAME="preferred_username"
fi

# Inject GEMINI_API_KEY env (optional) into assisted-chat container
JQ_ADD_GEMINI_ENV='.items |= map(
  if .kind=="Deployment" and .metadata.name=="assisted-chat" then
    (.spec.template.spec.containers |= map(
      .env = ((.env // []) + [{"name":"GEMINI_API_KEY","valueFrom":{"secretKeyRef":{"name":"gemini","key":"api_key","optional":true}}}])
    ))
  else . end)'

echo "Processing template for validation..."
PROCESSED_TEMPLATE=$(oc process \
    -p IMAGE="$IMAGE" \
    -p IMAGE_TAG="$TAG" \
    -p VERTEX_API_SECRET_NAME=vertex-service-account \
    -p ASSISTED_CHAT_DB_SECRET_NAME=llama-stack-db \
    -p USER_ID_CLAIM="$CLAIM_USER_ID" \
    -p USERNAME_CLAIM="$CLAIM_USERNAME" \
    -p LIGHTSPEED_STACK_POSTGRES_SSL_MODE=disable \
    -p LLAMA_STACK_POSTGRES_SSL_MODE=disable \
    -p LIGHTSPEED_EXPORTER_AUTH_MODE=manual \
    -f template.yaml --local)
    
 # Validate that oc process resolved all template variables (${VAR} syntax)
# This catches:
# 1. Missing parameters: ${NEW_VAR} used but not defined in template parameters section
# 2. Malformed syntax: ${\{VAR}} instead of ${VAR} (causes pydantic validation errors)
# 3. Any other template variables that oc process failed to resolve
# Note: Excludes legitimate runtime environment variables like ${env.POSTGRES_HOST}
UNRESOLVED_VARS=$(echo "$PROCESSED_TEMPLATE" | grep '\${[^}]*}' | grep -v '\${env\.' || true)
if [[ -n "$UNRESOLVED_VARS" ]]; then
    echo "ERROR: Unresolved template variables found:"
    echo "$UNRESOLVED_VARS"
    exit 1
fi

echo "Applying processed template..."
echo "$PROCESSED_TEMPLATE" |
    jq '. as $root | $root.items = [$root.items[] | '"$FILTER"']' |
    jq "$JQ_SET_POLICY" |
    jq "$JQ_ADD_GEMINI_ENV" |
    oc apply -n "$NAMESPACE" -f -

sleep 5
if  ! oc rollout status  -n $NAMESPACE deployment/assisted-chat --timeout=300s; then
    echo "Deploying assisted-chat failed, the logs of the pods are in artifacts/eval-test/gather-extra/artifacts/pods/ directory."
    exit 1
fi
