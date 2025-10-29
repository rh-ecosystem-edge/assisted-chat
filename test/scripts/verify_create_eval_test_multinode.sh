#!/bin/bash

# Source the common helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

setup_shell_options
validate_environment

# Expected values for multi-node cluster
EXPECTED_VERSION="4.18.22"
EXPECTED_DOMAIN="test.local"
EXPECTED_SINGLE_NODE="false"
EXPECTED_CPU_ARCH="x86_64"

wait_and_validate_cluster \
    "eval-test-multinode" \
    "${EXPECTED_VERSION}" \
    "${EXPECTED_DOMAIN}" \
    "${EXPECTED_SINGLE_NODE}" \
    "${EXPECTED_CPU_ARCH}" \
    "multi-node"
