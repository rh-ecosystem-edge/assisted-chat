#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Source the OCM token utility
source "$PROJECT_ROOT/utils/ocm-token.sh"

if [[ ! -f "$PROJECT_ROOT/config/lightspeed-stack.yaml" ]]; then
    echo "Configuration file not found: $PROJECT_ROOT/config/lightspeed-stack.yaml"
    echo "Did you run 'make generate' first?"
    exit 1
fi

if podman pod exists assisted-chat-pod &>/dev/null; then
    # If the pod exists, attempt to kill and remove it.
    echo "Found existing assisted-chat-pod. Killing and removing..."
    podman pod kill assisted-chat-pod
    podman pod rm assisted-chat-pod
else
    echo "assisted-chat-pod not found. Skipping kill/remove."
fi

set -a && source "$PROJECT_ROOT/.env" && set +a
export LIGHTSPEED_STACK_IMAGE_OVERRIDE="${LIGHTSPEED_STACK_IMAGE_OVERRIDE:-localhost/local-ai-chat-lightspeed-stack-plus-llama-stack}"

# Validate and export OCM tokens for use in pod configuration
if ! export_ocm_token; then
    echo "Failed to get OCM tokens. The UI container will not be able to authenticate with OCM."
    exit 1
fi
podman play kube --build=false <(envsubst < "$PROJECT_ROOT"/assisted-chat-pod.yaml)

"$SCRIPT_DIR/logs.sh"
