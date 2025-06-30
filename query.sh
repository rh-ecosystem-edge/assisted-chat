#!/bin/bash

set -euo pipefail

if ! command -v ocm &>/dev/null; then
    echo "The 'ocm' command is not installed. Please install the ocm CLI from https://console.redhat.com/openshift/token first"
    exit 1
fi

if ! ocm whoami &>/dev/null; then
    echo "You are not logged in to OCM. Please run 'ocm login --use-auth-code' and follow the instructions."
    exit 1
fi

OCM_TOKEN=$(ocm token)

if [ -z "${OCM_TOKEN}" ]; then
    echo "Received an empty token from the 'ocm token' command."
    echo "You may need to refresh your OCM login first. Please run 'ocm login --use-auth-code' and follow the instructions."
    exit 1
fi

MODELS=$(curl --silent --show-error -X 'GET' 'http://0.0.0.0:8090/v1/models' -H 'accept: application/json')
MODEL_IDENTIFIER=$(jq '.models[] | select(.model_type == "llm").identifier' -r <<<"$MODELS" | fzf)
PROVIDER=$(jq '.models[] | select(.identifier == "'"$MODEL_IDENTIFIER"'") | .provider_id' -r <<<"$MODELS")

curl --silent \
    -H "Authorization: Bearer $(ocm token)" \
    --show-error \
    'http://localhost:8090/v1/query' \
    --json '{
  "conversation_id": "123e4567-e89b-12d3-a456-426614174000",
  "model": "'"$MODEL_IDENTIFIER"'",
  "provider": "'"$PROVIDER"'",
  "query": "What is the OpenShift Assisted Installer? Can you list my clusters?",
  "system_prompt": "You are a helpful assistant"
}' | python3 -m yq '.' -y
