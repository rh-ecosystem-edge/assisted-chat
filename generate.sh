#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# If .env doesn't exist, we want to prompt the user to fill it
# and exit if they don't want to
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
    echo "Missing the .env file that should contain your configuration."
    echo "Would you like help creating the .env file interactively? (y/n)"
    read -r answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        echo "Visit https://cloud.redhat.com/openshift/token and log-in if needed. Then press "use API tokens to authenticate" and paste your token here"
        read -r OCM_TOKEN
        echo "OCM_TOKEN=$OCM_TOKEN" >"$SCRIPT_DIR/.env"

        echo "Please enter your llama-stack URL:"
        read -r LLAMA_STACK_URL
        echo "LLAMA_STACK_URL=$LLAMA_STACK_URL" >>"$SCRIPT_DIR/.env"
    else
        echo "Exiting. You can copy .env.template to .env and fill it in manually."
        exit 1
    fi
fi

# Load environment variables from .env file
source "$SCRIPT_DIR/.env"

# Check if required environment variables are set
if [[ -z "$OCM_TOKEN" ]]; then
    echo "OCM_TOKEN is not set in .env file."
    exit 1
fi

if [[ -z "$LLAMA_STACK_URL" ]]; then
    echo "LLAMA_STACK_URL is not set in .env file."
    exit 1
fi

mkdir -p "$SCRIPT_DIR/config"
# shellcheck disable=SC2016 # we want jq to interpret the string, not bash)
<"lightspeed-stack.template.yaml" python3 -m yq --arg llama_stack_url "$LLAMA_STACK_URL" '.llama_stack.url = $llama_stack_url' |
    python3 -m yq --yaml-output-grammar-version 1.1 --yaml-roundtrip --yaml-output --indentless-lists >"$SCRIPT_DIR/config/lightspeed-stack.yaml"

