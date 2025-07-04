#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Source the OCM token utility
source "$SCRIPT_DIR/utils/ocm-token.sh"

if [[ ! -f "$SCRIPT_DIR/config/lightspeed-stack.yaml" ]]; then
    echo "Configuration file not found: $SCRIPT_DIR/config/lightspeed-stack.yaml"
    echo "Did you run ./generate.sh first?"
    exit 1
fi

podman pod kill assisted-chat-pod >/dev/null || true
podman pod rm assisted-chat-pod >/dev/null || true

set -a && source .env && set +a
export LIGHTSPEED_STACK_IMAGE_OVERRIDE="${LIGHTSPEED_STACK_IMAGE_OVERRIDE:-localhost/local-ai-chat-lightspeed-stack-plus-llama-stack}"

# Validate and export OCM token for use in pod configuration
if ! export_ocm_token; then
    echo "Failed to get OCM token. The UI container will not be able to authenticate with OCM."
    exit 1
fi
podman play kube --build=false <(envsubst < "$SCRIPT_DIR"/assisted-chat-pod.yaml)

"$SCRIPT_DIR/logs.sh"
