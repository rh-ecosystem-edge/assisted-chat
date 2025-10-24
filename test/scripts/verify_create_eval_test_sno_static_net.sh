#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

: "${OCM_TOKEN:?OCM_TOKEN is required}"
: "${UNIQUE_ID:?UNIQUE_ID is required}"
ASSISTED_SERVICE_URL="${OCM_BASE_URL:-https://api.stage.openshift.com}/api/assisted-install/v2"

# Expected values for static network SNO cluster
EXPECTED_VERSION="4.19.7"
EXPECTED_DOMAIN="example.com"
EXPECTED_SINGLE_NODE="true"
EXPECTED_CPU_ARCH="x86_64"

COUNTER=0
while true; do
    CLUSTER_DATA=$(curl -sSf -H "Authorization: Bearer ${OCM_TOKEN}" "${ASSISTED_SERVICE_URL}/clusters" | jq -r ".[] | select(.name == \"eval-test-static-net-cluster-${UNIQUE_ID}\")")

    if [[ -n "$CLUSTER_DATA" && "$CLUSTER_DATA" != "null" ]]; then
        # Validate cluster properties
        ACTUAL_VERSION=$(echo "$CLUSTER_DATA" | jq -r '.openshift_version')
        ACTUAL_DOMAIN=$(echo "$CLUSTER_DATA" | jq -r '.base_dns_domain')
        ACTUAL_SINGLE_NODE=$(echo "$CLUSTER_DATA" | jq -r '.high_availability_mode == "None"')
        ACTUAL_CPU_ARCH=$(echo "$CLUSTER_DATA" | jq -r '.cpu_architecture')

        if [[ "$ACTUAL_VERSION" == "$EXPECTED_VERSION" && "$ACTUAL_DOMAIN" == "$EXPECTED_DOMAIN" && "$ACTUAL_SINGLE_NODE" == "true" && "$ACTUAL_CPU_ARCH" == "$EXPECTED_CPU_ARCH" ]]; then
            echo "The static network SNO cluster was successfully created with correct configuration:"
            echo "  Name: eval-test-static-net-cluster-${UNIQUE_ID}"
            echo "  Version: ${ACTUAL_VERSION}"
            echo "  Domain: ${ACTUAL_DOMAIN}"
            echo "  Single Node: ${ACTUAL_SINGLE_NODE}"
            echo "  CPU Architecture: ${ACTUAL_CPU_ARCH}"
            exit 0
        else
            echo "Cluster found but configuration mismatch:"
            echo "  Expected version: ${EXPECTED_VERSION}, got: ${ACTUAL_VERSION}"
            echo "  Expected domain: ${EXPECTED_DOMAIN}, got: ${ACTUAL_DOMAIN}"
            echo "  Expected single node: ${EXPECTED_SINGLE_NODE}, got: ${ACTUAL_SINGLE_NODE}"
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
