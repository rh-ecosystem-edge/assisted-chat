#!/bin/bash

# Source the common helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

setup_shell_options
validate_environment

# Expected values for static network SNO cluster
EXPECTED_VERSION="4.19.7"
EXPECTED_DOMAIN="example.com"
EXPECTED_SINGLE_NODE="true"
EXPECTED_CPU_ARCH="x86_64"

wait_and_validate_cluster \
    "eval-test-static-net-cluster" \
    "${EXPECTED_VERSION}" \
    "${EXPECTED_DOMAIN}" \
    "${EXPECTED_SINGLE_NODE}" \
    "${EXPECTED_CPU_ARCH}" \
    "static network SNO"
