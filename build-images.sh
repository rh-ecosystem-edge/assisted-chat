#!/bin/bash

set -euxo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [[ ! -d "${SCRIPT_DIR}/inspector" ||
    ! -d "${SCRIPT_DIR}/assisted-service-mcp" ||
    ! -d "${SCRIPT_DIR}/lightspeed-stack" ]]; then
    echo "Dependency directories do not exist. Load git submodules first."
    exit 1
fi

function build_inspector() {
    pushd "${SCRIPT_DIR}/inspector"
    podman build -f Dockerfile . --tag localhost/local-ai-chat-inspector:latest
    popd
}

function build_assisted_mcp() {
    pushd "${SCRIPT_DIR}/assisted-service-mcp"
    make build IMAGE_NAME=localhost/local-ai-chat-assisted-service-mcp TAG=latest
    popd
}

function build_lightspeed_stack() {
    pushd "${SCRIPT_DIR}/lightspeed-stack"
    podman build -f Containerfile . --tag localhost/local-ai-chat-lightspeed-stack:latest
    popd
}

function build_ui() {
    pushd "${SCRIPT_DIR}/assisted-installer-ui/"
    git apply ../ui-patch.diff
    podman build -f apps/assisted-ui/Containerfile -t localhost/local-ai-chat-ui . --build-arg AIUI_APP_GIT_SHA="$(git rev-parse HEAD)" --build-arg AIUI_APP_VERSION=latest
    git apply -R ../ui-patch.diff
    popd
}

build_inspector
build_assisted_mcp
build_lightspeed_stack
build_ui
