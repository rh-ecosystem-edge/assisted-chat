#!/bin/bash

# Source the common helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

setup_shell_options
validate_environment

INFRA_ENV_NAME="eval-test-static-net-cluster-${UNIQUE_ID}"

COUNTER=0
while true; do
    INFRA_ENV_DATA=$(fetch_infra_env_data "$INFRA_ENV_NAME")

    if [[ -n "$INFRA_ENV_DATA" && "$INFRA_ENV_DATA" != "null" ]]; then
      STATIC_NETWORK_CONFIG=$(echo "$INFRA_ENV_DATA" | jq -r '.static_network_config')
      if [[ "$STATIC_NETWORK_CONFIG" == "null" ]]; then
        echo_err "Static network config is not set"
        exit 1
      fi

      EXPECTED_DNS_SERVER="8.8.8.8"
      EXPECTED_MAC_ADDRESS="c5:d6:bc:f0:05:20"
      EXPECTED_VLAN_ADDRESS="10.0.0.5"
      EXPECTED_VLAN_ID="400"

      # Handle array structure - get the first element's network_yaml
      NETWORK_YAML=$(echo "$STATIC_NETWORK_CONFIG" | jq -r '.[0].network_yaml')
      if [[ "$NETWORK_YAML" == "null" || -z "$NETWORK_YAML" ]]; then
        echo_err "ERROR: Network YAML configuration is missing"
        exit 1
      fi

      # Parse the network YAML for validation
      DNS_SERVER=$(echo "$NETWORK_YAML" | yq -r '."dns-resolver".config.server[0]')
      if [[ "$DNS_SERVER" == "null" || -z "$DNS_SERVER" ]]; then
        echo_err "ERROR: DNS server configuration is missing"
        echo_err "Network YAML content:"
        echo_err "$NETWORK_YAML"
        exit 1
      fi
      if [[ "$DNS_SERVER" != "$EXPECTED_DNS_SERVER" ]]; then
        echo_err "ERROR: DNS server mismatch. Expected: $EXPECTED_DNS_SERVER, Found: $DNS_SERVER"
        echo_err "Network YAML content:"
        echo_err "$NETWORK_YAML"
        exit 1
      fi

      MAC_ADDRESS=$(echo "$NETWORK_YAML" | yq -r '.interfaces[] | select(.type == "ethernet") | .mac-address')
      if [[ "$MAC_ADDRESS" == "null" || -z "$MAC_ADDRESS" ]]; then
        echo_err "ERROR: MAC address not found in ethernet interface"
        echo_err "Network YAML content:"
        echo_err "$NETWORK_YAML"
        exit 1
      fi
      if [[ "$MAC_ADDRESS" != "$EXPECTED_MAC_ADDRESS" ]]; then
        echo_err "ERROR: MAC address mismatch. Expected: $EXPECTED_MAC_ADDRESS, Found: $MAC_ADDRESS"
        echo_err "Network YAML content:"
        echo_err "$NETWORK_YAML"
        exit 1
      fi

      VLAN_ADDRESS=$(echo "$NETWORK_YAML" | yq -r '.interfaces[] | select(.type == "vlan") | .ipv4.address[0].ip')
      if [[ "$VLAN_ADDRESS" == "null" || -z "$VLAN_ADDRESS" ]]; then
        echo_err "ERROR: VLAN interface address not found"
        echo_err "Network YAML content:"
        echo_err "$NETWORK_YAML"
        exit 1
      fi
      if [[ "$VLAN_ADDRESS" != "$EXPECTED_VLAN_ADDRESS" ]]; then
        echo_err "ERROR: VLAN interface address mismatch. Expected: $EXPECTED_VLAN_ADDRESS, Found: $VLAN_ADDRESS"
        echo_err "Network YAML content:"
        echo_err "$NETWORK_YAML"
        exit 1
      fi

      VLAN_ID=$(echo "$NETWORK_YAML" | yq -r '.interfaces[] | select(.type == "vlan") | .vlan.id')
      if [[ "$VLAN_ID" == "null" || -z "$VLAN_ID" ]]; then
        echo_err "ERROR: VLAN ID not found"
        echo_err "Network YAML content:"
        echo_err "$NETWORK_YAML"
        exit 1
      fi
      if [[ "$VLAN_ID" != "$EXPECTED_VLAN_ID" ]]; then
        echo_err "ERROR: VLAN ID mismatch. Expected: $EXPECTED_VLAN_ID, Found: $VLAN_ID"
        echo_err "Network YAML content:"
        echo_err "$NETWORK_YAML"
        exit 1
      fi

      exit 0
    fi

    if [[ $COUNTER -gt 3 ]]; then
        echo_err "Static network configuration check timed out"
        exit 1
    fi
    ((COUNTER++))
    sleep 10
done
