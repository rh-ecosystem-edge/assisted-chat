#!/bin/bash

# Source the common helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

setup_shell_options
validate_environment

# Expected values for SNO cluster
EXPECTED_VERSION="4.19.7"
EXPECTED_DOMAIN="example.com"
EXPECTED_SINGLE_NODE="true"
EXPECTED_CPU_ARCH="x86_64"
EXPECTED_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQCmeaBFhSJ/MLECmqUaKweRgo10ABpwdvJ7v76qLYfP0pzfzYsF3hGP/fH5OQfHi9pTbWynjaEcPHVfaTaFWHvyMtv8PEMUIDgQPWlBSYzb+3AgQ5AsChhzTJCYnRdmCdzENlV+azgtb3mVfXiyCfjxhyy3QAV4hRrMaVtJGuUQfQ== example@example.com"

wait_and_validate_cluster \
    "eval-test-singlenode" \
    "${EXPECTED_VERSION}" \
    "${EXPECTED_DOMAIN}" \
    "${EXPECTED_SINGLE_NODE}" \
    "${EXPECTED_CPU_ARCH}" \
    "SNO" \
    "${EXPECTED_SSH_KEY}"
