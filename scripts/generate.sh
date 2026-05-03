#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

OVERRIDE_FILE=$PROJECT_ROOT/.template-params.override.env

if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Missing the .env file that should contain your configuration."
    echo "Would you like help creating the .env file interactively? (y/n)"
    read -r answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        echo 'Please enter the path to your Vertex AI service account credentials file:'
        read -r VERTEX_AI_SERVICE_ACCOUNT_CREDENTIALS_PATH
        if [[ ! -f "$VERTEX_AI_SERVICE_ACCOUNT_CREDENTIALS_PATH" ]]; then
            echo "File not found: $VERTEX_AI_SERVICE_ACCOUNT_CREDENTIALS_PATH"
            exit 1
        fi

        if [[ -f "$PROJECT_ROOT/config/vertex-credentials.json" ]]; then
            echo "File $PROJECT_ROOT/config/vertex-credentials.json already exists. Do you want to overwrite it? (y/n)"
            read -r overwrite
            if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
                echo "Exiting without copying."
                exit 1
            fi
        fi

        echo "$VERTEX_AI_SERVICE_ACCOUNT_CREDENTIALS_PATH will be copied to $PROJECT_ROOT/config/vertex-credentials.json, do you want to continue? (y/n)"
        read -r should_copy
        if [[ "$should_copy" != "y" && "$should_copy" != "Y" ]]; then
            echo "Exiting."
            exit 1
        fi

        cp "$VERTEX_AI_SERVICE_ACCOUNT_CREDENTIALS_PATH" "$PROJECT_ROOT/config/vertex-credentials.json"
        chmod 600 "$PROJECT_ROOT/config/vertex-credentials.json"

        # Extract project_id from the credentials JSON
        VERTEX_PROJECT_ID=$(jq -r '.project_id // empty' "$PROJECT_ROOT/config/vertex-credentials.json")

        # Validate that we successfully extracted a project_id
        if [[ -z "$VERTEX_PROJECT_ID" ]]; then
            echo "ERROR: Failed to extract 'project_id' from credentials JSON"
            echo "Manually set VERTEX_AI_PROJECT in $PROJECT_ROOT/.env or fix the credentials file"
            exit 1
        fi

        # Create .env file with VERTEX_AI_PROJECT
        echo "VERTEX_AI_PROJECT=\"$VERTEX_PROJECT_ID\"" >"$PROJECT_ROOT/.env"
        chmod 600 "$PROJECT_ROOT/.env"

        echo "Vertex credentials successfully configured."
    else
        echo "Exiting. You can copy .env.template to .env and fill it in manually."
        exit 1
    fi
else
    echo "The .env file already exists. Skipping interactive configuration."
fi

source "$PROJECT_ROOT/.env"

mkdir -p "$PROJECT_ROOT/config"

if [[ -f $OVERRIDE_FILE ]]; then
    OVERRIDE_PARAMS="--param-file=$OVERRIDE_FILE"
fi

echo "Generating $PROJECT_ROOT/config/lightspeed-stack.yaml"
oc process --local \
    -f "$PROJECT_ROOT/template.yaml" \
    "${OVERRIDE_PARAMS-}" \
    --param-file="$PROJECT_ROOT/template-params.dev.env" |
    yq '.items[] | select(.kind == "ConfigMap" and .metadata.name == "lightspeed-stack-config").data."lightspeed-stack.yaml"' -r \
        >"$PROJECT_ROOT/config/lightspeed-stack.yaml"

echo "Generating $PROJECT_ROOT/config/systemprompt.txt"
yq -r '.objects[] | select(.metadata.name == "lightspeed-stack-config") | .data.system_prompt' "$PROJECT_ROOT/template.yaml" >"$PROJECT_ROOT/config/systemprompt.txt"
