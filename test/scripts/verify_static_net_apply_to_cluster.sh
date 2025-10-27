#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

: "${OCM_TOKEN:?OCM_TOKEN is required}"
: "${UNIQUE_ID:?UNIQUE_ID is required}"
ASSISTED_SERVICE_URL="${OCM_BASE_URL:-https://api.stage.openshift.com}/api/assisted-install/v2"

COUNTER=0
while true; do
    INFRA_ENV_DATA=$(curl -sSf -H "Authorization: Bearer ${OCM_TOKEN}" "${ASSISTED_SERVICE_URL}/infra-envs" | jq -r ".[] | select(.name == \"eval-test-static-net-cluster-${UNIQUE_ID}\")")

    if [[ -n "$INFRA_ENV_DATA" && "$INFRA_ENV_DATA" != "null" ]]; then
      STATIC_NETWORK_CONFIG=$(echo "$INFRA_ENV_DATA" | jq -r '.static_network_config')
      if [[ "$STATIC_NETWORK_CONFIG" == "null" ]]; then
        echo "Static network config is not set"
        exit 1
      fi

      EXPECTED_DNS_SERVER="8.8.8.8"
      EXPECTED_MAC_ADDRESS="c5:d6:bc:f0:05:20"
      EXPECTED_VLAN_ADDRESS="10.0.0.5"
      EXPECTED_VLAN_ID="400"

      # Handle array structure - get the first element's network_yaml
      NETWORK_YAML=$(echo "$STATIC_NETWORK_CONFIG" | jq -r '.[0].network_yaml')
      if [[ "$NETWORK_YAML" == "null" || -z "$NETWORK_YAML" ]]; then
        echo "ERROR: Network YAML configuration is missing"
        exit 1
      fi

      # Parse the network YAML for validation
      DNS_SERVER=$(echo "$NETWORK_YAML" | yq '.dns-resolver.config.server[0]')
      if [[ "$DNS_SERVER" == "null" || -z "$DNS_SERVER" ]]; then
        echo "ERROR: DNS server configuration is missing"
        exit 1
      fi
      if [[ "$DNS_SERVER" != "$EXPECTED_DNS_SERVER" ]]; then
        echo "ERROR: DNS server mismatch. Expected: $EXPECTED_DNS_SERVER, Found: $DNS_SERVER"
        exit 1
      fi

      MAC_ADDRESS=$(echo "$NETWORK_YAML" | yq '.interfaces[] | select(.type == "ethernet") | .mac-address')
      if [[ "$MAC_ADDRESS" == "null" || -z "$MAC_ADDRESS" ]]; then
        echo "ERROR: MAC address not found in ethernet interface"
        exit 1
      fi
      if [[ "$MAC_ADDRESS" != "$EXPECTED_MAC_ADDRESS" ]]; then
        echo "ERROR: MAC address mismatch. Expected: $EXPECTED_MAC_ADDRESS, Found: $MAC_ADDRESS"
        exit 1
      fi

      VLAN_ADDRESS=$(echo "$NETWORK_YAML" | yq '.interfaces[] | select(.type == "vlan") | .ipv4.address[0].ip')
      if [[ "$VLAN_ADDRESS" == "null" || -z "$VLAN_ADDRESS" ]]; then
        echo "ERROR: VLAN interface address not found"
        exit 1
      fi
      if [[ "$VLAN_ADDRESS" != "$EXPECTED_VLAN_ADDRESS" ]]; then
        echo "ERROR: VLAN interface address mismatch. Expected: $EXPECTED_VLAN_ADDRESS, Found: $VLAN_ADDRESS"
        exit 1
      fi

      VLAN_ID=$(echo "$NETWORK_YAML" | yq '.interfaces[] | select(.type == "vlan") | .vlan.id')
      if [[ "$VLAN_ID" == "null" || -z "$VLAN_ID" ]]; then
        echo "ERROR: VLAN ID not found"
        exit 1
      fi
      if [[ "$VLAN_ID" != "$EXPECTED_VLAN_ID" ]]; then
        echo "ERROR: VLAN ID mismatch. Expected: $EXPECTED_VLAN_ID, Found: $VLAN_ID"
        exit 1
      fi

      exit 0
    fi

    if [[ $COUNTER -gt 3 ]]; then
        echo "Static network configuration check timed out"
        exit 1
    fi
    ((COUNTER++))
    sleep 10
done
