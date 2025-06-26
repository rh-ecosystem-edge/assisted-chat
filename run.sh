#!/bin/bash

set -euxo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [[ ! -f "$SCRIPT_DIR/config/lightspeed-stack.yaml" ]]; then
    echo "Configuration file not found: $SCRIPT_DIR/config/lightspeed-stack.yaml"
    echo "Did you run ./generate.sh first?"
    exit 1
fi

podman pod kill assisted-chat-pod || true
podman pod rm assisted-chat-pod || true
podman play kube "$SCRIPT_DIR"/assisted-chat-pod.yaml
