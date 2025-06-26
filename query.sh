#!/bin/bash

set -euo pipefail

MODELS=$(curl --silent --show-error -X 'GET' 'http://localhost:8080/v1/models' -H 'accept: application/json')
MODEL_IDENTIFIER=$(jq '.models[] | select(.model_type == "llm").identifier' -r <<<"$MODELS" | fzf)
PROVIDER=$(jq '.models[] | select(.identifier == "'"$MODEL_IDENTIFIER"'") | .provider_id' -r <<<"$MODELS")

curl -X 'POST' \
    --silent \
    --show-error \
    'http://localhost:8080/v1/query' \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
  "conversation_id": "123e4567-e89b-12d3-a456-426614174000",
  "model": "'"$MODEL_IDENTIFIER"'",
  "provider": "'"$PROVIDER"'",
  "query": "What is the OpenShift Assisted Installer?",
  "system_prompt": "You are a helpful assistant"
}'
