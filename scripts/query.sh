#!/bin/bash

set -euo pipefail

# Color definitions
CYAN='\033[0;36m'
RESET='\033[0m'

# Get the script directory to locate utils
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Source the OCM token utility
source "$PROJECT_ROOT/utils/ocm-token.sh"

INTERACTIVE_MODE=false
if [[ "${1:-}" == "--interactive" ]]; then
    INTERACTIVE_MODE=true
    echo "Interactive mode enabled."
fi

DEFAULT_QUERY="What is the OpenShift Assisted Installer? Can you list my clusters?"
MODELS=$(curl --silent --show-error -X 'GET' 'http://0.0.0.0:8090/v1/models' -H 'accept: application/json')
< <(jq -r '
    # Get all models
    .models[] 

    # Ignore models that are not LLMs, like embeddings
    | select(.model_type == "llm") 

    # Extract relevant fields
    | . as $model
    | $model.identifier as $model_name
    | $model.provider_id as $provider

    # Determine type label based on model identifier
    | (if ($model_name | startswith("gemini/gemini/")) then "Vertex AI"
       elif ($model_name | contains("gemini")) then "True Gemini"
       else ""
       end) as $type_label

    # Format with proper spacing for alignment
    | "\($model_name | . + (" " * (40 - length)))\($type_label)\t\($model_name)\t\($provider)"
    ' <<<"$MODELS" | fzf --delimiter='\t' --with-nth=1 --accept-nth=2,3 --header="Model Name                               Type") \
    IFS=$'\t' read -r MODEL_NAME MODEL_PROVIDER

# Generate a random UUID for the initial conversation_id
# Try different methods to generate UUID based on what's available
if command -v uuidgen >/dev/null 2>&1; then
    CONVERSATION_ID=$(uuidgen)
elif [[ -r /proc/sys/kernel/random/uuid ]]; then
    CONVERSATION_ID=$(cat /proc/sys/kernel/random/uuid)
else
    echo "No UUID generator found. Please install uuidgen or ensure /proc/sys/kernel/random/uuid exists."
    exit 1
fi

echo "Generated conversation ID: $CONVERSATION_ID"

good_http_response() {
    local status_code="$1"
    [[ "$status_code" -ge 200 && "$status_code" -lt 300 ]]
}

send_curl_query() {
    local query="$1"

    # Get fresh OCM token for this query
    if ! get_ocm_token; then
        echo "Failed to get OCM token for query"
        return 1
    fi

    # Make the curl request and capture the response
    tmpfile=$(mktemp)
    status=$(curl --silent --show-error --output "$tmpfile" --write-out "%{http_code}" \
        -H "Authorization: Bearer ${OCM_TOKEN}" \
        'http://localhost:8090/v1/query' \
        --json '{
    "conversation_id": "'"$CONVERSATION_ID"'",
    "model": "'"$MODEL_NAME"'",
    "provider": "'"$MODEL_PROVIDER"'",
    "query": "'"${query}"'"
  }')
    body=$(cat "$tmpfile")
    rm "$tmpfile"

    if ! good_http_response "$status"; then
        echo "Error: HTTP status $status"
        echo "Response body:"
        echo "$body"
        return 1
    fi

    # Extract and update conversation_id for next call
    new_conversation_id=$(echo "$body" | jq -r '.conversation_id // empty')
    if [[ -n "$new_conversation_id" ]]; then
        echo "Updated conversation ID: $new_conversation_id"
        CONVERSATION_ID="$new_conversation_id"
    fi

    # Display the response in YAML format with cyan color
    echo -e "${CYAN}$(echo "$body" | python3 -m yq '.' -y)${RESET}"
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
