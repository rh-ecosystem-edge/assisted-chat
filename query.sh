#!/bin/bash

set -euxo pipefail

MODELS=$(curl --silent --show-error -X 'GET' 'http://0.0.0.0:8090/v1/models' -H 'accept: application/json')
MODEL_IDENTIFIER=$(jq '.models[] | select(.model_type == "llm").identifier' -r <<<"$MODELS" | fzf)
PROVIDER=$(jq '.models[] | select(.identifier == "'"$MODEL_IDENTIFIER"'") | .provider_id' -r <<<"$MODELS")

curl --silent \
    --show-error \
    'http://localhost:8090/v1/query' \
    --json '{
  "conversation_id": "123e4567-e89b-12d3-a456-426614174000",
  "model": "'"$MODEL_IDENTIFIER"'",
  "provider": "'"$PROVIDER"'",
  "query": "What is the OpenShift Assisted Installer? Can you list my clusters?",
  "system_prompt": "You are a helpful assistant"
}' | python3 -m yq '.' -y
