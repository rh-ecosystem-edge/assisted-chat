#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
    echo "Missing the .env file that should contain your configuration."
    echo "Would you like help creating the .env file interactively? (y/n)"
    read -r answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        echo 'Visit https://console.cloud.google.com/apis/credentials?authuser=1&inv=1&invt=Ab1Pvg&project=assisted-installer and log-in if needed. Then press "use API tokens to authenticate" and paste your token here'
        read -r GEMINI_API_KEY
        echo "GEMINI_API_KEY=$GEMINI_API_KEY" >"$SCRIPT_DIR/.env"
    else
        echo "Exiting. You can copy .env.template to .env and fill it in manually."
        exit 1
    fi
fi

source "$SCRIPT_DIR/.env"

mkdir -p "$SCRIPT_DIR/config"
cp "$SCRIPT_DIR/lightspeed-stack.template.yaml" "$SCRIPT_DIR/config/lightspeed-stack.yaml"



