#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

# Source the OCM token utility
source "$PROJECT_ROOT/utils/ocm-token.sh"

# Resolve image overrides (CI may set these); defaults for local dev
: "${LIGHTSPEED_STACK_IMAGE_OVERRIDE:=localhost/local-ai-chat-lightspeed-stack-plus-llama-stack:latest}"
: "${ASSISTED_MCP_IMAGE_OVERRIDE:=localhost/local-ai-chat-assisted-service-mcp:latest}"
: "${UI_IMAGE_OVERRIDE:=localhost/local-ai-chat-ui:latest}"
: "${INSPECTOR_IMAGE_OVERRIDE:=localhost/local-ai-chat-inspector:latest}"

# Nested Podman mode helper (kept harmless for local usage)
if [[ "${NESTED_PODMAN:-}" == "1" ]]; then
    mkdir -p /tmp/run || true
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/run}"
    export BUILDAH_ISOLATION="${BUILDAH_ISOLATION:-chroot}"
    uid="${UID:-$(id -u)}"
    export HOME="/tmp/home-${uid}"; mkdir -p "${HOME}" || true
    export CONTAINERS_STORAGE_CONF="${CONTAINERS_STORAGE_CONF:-/tmp/containers-storage-vfs-${uid}.conf}"
    if [[ ! -f "$CONTAINERS_STORAGE_CONF" ]]; then
        cat >"$CONTAINERS_STORAGE_CONF" <<EOF
[storage]
driver="vfs"
graphroot="/tmp/containers-${uid}/storage"
runroot="/tmp/containers-${uid}/run"
EOF
    fi
    export PODMAN_FLAGS="${PODMAN_FLAGS:---events-backend=file --cgroup-manager=cgroupfs --storage-driver=vfs --root=/tmp/containers-${uid}/storage --runroot=/tmp/containers-${uid}/run}"
fi

podman_cmd() {
    podman ${PODMAN_FLAGS:-} "$@"
}

if [[ ! -f "$PROJECT_ROOT/config/lightspeed-stack.yaml" ]]; then
    echo "Configuration file not found: $PROJECT_ROOT/config/lightspeed-stack.yaml"
    echo "Did you run 'make generate' first?"
    exit 1
fi

if podman_cmd pod exists assisted-chat-pod &>/dev/null; then
    # If the pod exists, attempt to kill and remove it.
    echo "Found existing assisted-chat-pod. Killing and removing..."
    podman_cmd pod kill assisted-chat-pod
    podman_cmd pod rm assisted-chat-pod
else
    echo "assisted-chat-pod not found. Skipping kill/remove."
fi

set -a && source "$PROJECT_ROOT/.env" && set +a
export LIGHTSPEED_STACK_IMAGE_OVERRIDE
export ASSISTED_MCP_IMAGE_OVERRIDE
export UI_IMAGE_OVERRIDE
export INSPECTOR_IMAGE_OVERRIDE

# Validate and export OCM tokens for use in pod configuration
if ! export_ocm_token; then
    echo "Failed to get OCM tokens. The UI container will not be able to authenticate with OCM."
    exit 1
fi

# Play kube with envsubst
if [[ "${NESTED_PODMAN:-}" == "1" ]]; then
    envsubst < "$PROJECT_ROOT"/assisted-chat-pod.yaml | podman_cmd play kube --build=false -
else
    envsubst < "$PROJECT_ROOT"/assisted-chat-pod.yaml | podman play kube --build=false -
fi

"$SCRIPT_DIR/logs.sh"
