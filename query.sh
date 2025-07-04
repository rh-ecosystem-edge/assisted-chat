#!/bin/bash

set -euo pipefail

# Get the script directory to locate utils
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Source the OCM token utility
source "$SCRIPT_DIR/utils/ocm-token.sh"

# Validate and get OCM token
if ! get_ocm_token; then
    exit 1
fi

INTERACTIVE_MODE=false
if [[ "${1:-}" == "--interactive" ]]; then
    INTERACTIVE_MODE=true
    echo "Interactive mode enabled."
fi

DEFAULT_QUERY="What is the OpenShift Assisted Installer? Can you list my clusters?"
MODELS=$(curl --silent --show-error -X 'GET' 'http://0.0.0.0:8090/v1/models' -H 'accept: application/json')
MODEL_IDENTIFIER=$(jq '.models[] | select(.model_type == "llm").identifier' -r <<<"$MODELS" | fzf)
PROVIDER=$(jq '.models[] | select(.identifier == "'"$MODEL_IDENTIFIER"'") | .provider_id' -r <<<"$MODELS")

send_curl_query(){
    local query="$1"
    curl --silent \
        -H "Authorization: Bearer ${OCM_TOKEN}" \
        --show-error \
        'http://localhost:8090/v1/query' \
        --json '{
      "conversation_id": "123e4567-e89b-12d3-a456-426614174000",
      "model": "'"$MODEL_IDENTIFIER"'",
      "provider": "'"$PROVIDER"'",
      "query": "'"${query}"'",
      "system_prompt": "You are a helpful assistant"
    }' | python3 -m yq '.' -y
}

if "$INTERACTIVE_MODE"; then
    echo "Example: What is the OpenShift Assisted Installer? Can you list my clusters?"
    while true; do
        # Prompt the user for input
        read -p "Enter your query (or type 'exit' to quit): " user_query

        # Check if the user wants to exit
        if [[ "$user_query" == "exit" ]]; then
            echo "Exiting script."
            break
        elif [[ "$user_query" == "" ]]; then
            continue
        fi
        send_curl_query "$user_query"
    done
else
    echo "Using default query: \"$DEFAULT_QUERY\""
    send_curl_query "$DEFAULT_QUERY"
fi
