#!/bin/bash

# Source the common helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

setup_shell_options
validate_environment

# Expected values for multi-node cluster
EXPECTED_VERSION="4.19.7"
EXPECTED_DOMAIN="example.com"
EXPECTED_SINGLE_NODE="false"
EXPECTED_CPU_ARCH="x86_64"
EXPECTED_PLATFORM="oci"
EXPECTED_SSH_KEY=

wait_and_validate_cluster \
    "eval-test-oci" \
    "${EXPECTED_VERSION}" \
    "${EXPECTED_DOMAIN}" \
    "${EXPECTED_SINGLE_NODE}" \
    "${EXPECTED_CPU_ARCH}" \
    "multi-node" \
    "${EXPECTED_SSH_KEY}" \
    "${EXPECTED_PLATFORM}"
