#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [[ ! -f "$SCRIPT_DIR/config/lightspeed-stack.yaml" ]]; then
    echo "Configuration file not found: $SCRIPT_DIR/config/lightspeed-stack.yaml"
    echo "Did you run ./generate.sh first?"
    exit 1
fi

podman pod kill assisted-chat-pod >/dev/null || true
podman pod rm assisted-chat-pod >/dev/null || true

set -a && source .env && set +a
podman play kube <(envsubst < "$SCRIPT_DIR"/assisted-chat-pod.yaml)

"$SCRIPT_DIR/logs.sh"
