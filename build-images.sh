#!/bin/bash

set -euxo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

if [[ ! -d "${SCRIPT_DIR}/inspector" ||
    ! -d "${SCRIPT_DIR}/assisted-service-mcp" ||
    ! -d "${SCRIPT_DIR}/lightspeed-stack" ]]; then
    echo "Dependency directories do not exist. Load git submodules first."
    exit 1
fi

function check_redhat_subscription() {
    echo "Checking Red Hat subscription requirements... You msut be registered to complete the build successfully."

    # Check if subscription-manager is available
    if ! command -v subscription-manager &> /dev/null; then
        echo "ERROR: subscription-manager is not available. This machine is unlikely to be registered so the build will fail."
        exit 1
    fi

    # Check subscription status (ask for sudo password upfront)
    if [[ ! -f /etc/pki/consumer/cert.pem ]]; then
        echo "ERROR: Could not find /etc/pki/consumer/cert.pem so the system is unlikely to be registered with Red Hat subscription manager."
        echo "Please register your system:"
        echo "  sudo subscription-manager register --username <your-username>"
        echo "  sudo subscription-manager attach --auto"
        echo ""
        echo "Or get a free Red Hat Developer subscription at: https://developers.redhat.com/register"
        exit 1
    fi

    echo "✓ Red Hat subscription and registry access verified"
}

# Verify Red Hat subscription before building
check_redhat_subscription

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

function build_lightspeed_stack_plus_llama_stack() {
    podman build -f Containerfile.add_llama_to_lightspeed . --tag localhost/local-ai-chat-lightspeed-stack-plus-llama-stack:latest
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
build_lightspeed_stack_plus_llama_stack
build_ui
