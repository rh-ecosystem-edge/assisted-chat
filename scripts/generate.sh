#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "Missing the .env file that should contain your configuration."
    echo "Would you like help creating the .env file interactively? (y/n)"
    read -r answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        echo 'Visit https://console.cloud.google.com/apis/credentials?authuser=1&inv=1&invt=Ab1Pvg&project=assisted-installer and log-in if needed. Then press "use API tokens to authenticate" and paste your token here'
        read -r GEMINI_API_KEY
        echo "GEMINI_API_KEY=$GEMINI_API_KEY" >"$PROJECT_ROOT/.env"
    else
        echo "Exiting. You can copy .env.template to .env and fill it in manually."
        exit 1
    fi
fi

source "$PROJECT_ROOT/.env"

mkdir -p "$PROJECT_ROOT/config"
cp "$PROJECT_ROOT/lightspeed-stack.template.yaml" "$PROJECT_ROOT/config/lightspeed-stack.yaml"



