#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

: "${OCM_TOKEN:?OCM_TOKEN is required}"
: "${UNIQUE_ID:?UNIQUE_ID is required}"
ASSISTED_SERVICE_URL="${OCM_BASE_URL:-https://api.stage.openshift.com}/api/assisted-install/v2"

# Expected values for multi-node cluster
EXPECTED_VERSION="4.18.22"
EXPECTED_DOMAIN="test.local"
EXPECTED_SINGLE_NODE="false"
EXPECTED_CPU_ARCH="x86_64"

COUNTER=0
while true; do
    CLUSTER_DATA=$(curl -sSf -H "Authorization: Bearer ${OCM_TOKEN}" "${ASSISTED_SERVICE_URL}/clusters" | jq -r ".[] | select(.name == \"eval-test-multinode-${UNIQUE_ID}\")")

    if [[ -n "$CLUSTER_DATA" && "$CLUSTER_DATA" != "null" ]]; then
        # Validate cluster properties
        ACTUAL_VERSION=$(echo "$CLUSTER_DATA" | jq -r '.openshift_version')
        ACTUAL_DOMAIN=$(echo "$CLUSTER_DATA" | jq -r '.base_dns_domain')
        ACTUAL_SINGLE_NODE=$(echo "$CLUSTER_DATA" | jq -r '.high_availability_mode == "None"')
        ACTUAL_CPU_ARCH=$(echo "$CLUSTER_DATA" | jq -r '.cpu_architecture')

        if [[ "$ACTUAL_VERSION" == "$EXPECTED_VERSION" && "$ACTUAL_DOMAIN" == "$EXPECTED_DOMAIN" && "$ACTUAL_SINGLE_NODE" == "$EXPECTED_SINGLE_NODE" && "$ACTUAL_CPU_ARCH" == "$EXPECTED_CPU_ARCH" ]]; then
            echo "The multi-node cluster was successfully created with correct configuration:"
            echo "  Name: eval-test-multinode-${UNIQUE_ID}"
            echo "  Version: ${ACTUAL_VERSION}"
            echo "  Domain: ${ACTUAL_DOMAIN}"
            echo "  Single-node: ${ACTUAL_SINGLE_NODE}"
            echo "  CPU Architecture: ${ACTUAL_CPU_ARCH}"
            exit 0
        else
            echo "Cluster found but configuration mismatch:"
            echo "  Expected version: ${EXPECTED_VERSION}, got: ${ACTUAL_VERSION}"
            echo "  Expected domain: ${EXPECTED_DOMAIN}, got: ${ACTUAL_DOMAIN}"
            echo "  Expected single-node: false, got: ${ACTUAL_SINGLE_NODE}"
            echo "  Expected CPU architecture: ${EXPECTED_CPU_ARCH}, got: ${ACTUAL_CPU_ARCH}"
            exit 1
        fi
    fi

    if [[ $COUNTER -gt 3 ]]; then
        echo "Cluster creation timed out"
        exit 1
    fi
    ((COUNTER++))
    sleep 10
done
