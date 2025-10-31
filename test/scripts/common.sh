#!/bin/bash

# Helper function to print to stderr
echo_err() {
    echo "$@" >&2
}

# Helper function to print to stdout (for clarity, though echo does this by default)
echo_out() {
    echo "$@"
}

# Setup common bash settings
setup_shell_options() {
    set -o nounset
    set -o errexit
    set -o pipefail
}

# Validate required environment variables
validate_environment() {
    : "${OCM_TOKEN:?OCM_TOKEN is required}"
    : "${UNIQUE_ID:?UNIQUE_ID is required}"
}

# Get the assisted service URL
get_assisted_service_url() {
    echo "${OCM_BASE_URL:-https://api.stage.openshift.com}/api/assisted-install/v2"
}

# Fetch cluster data by name
# Usage: fetch_cluster_data <cluster_name>
fetch_cluster_data() {
    local cluster_name="$1"
    local service_url=$(get_assisted_service_url)
    curl -sSf -H "Authorization: Bearer ${OCM_TOKEN}" "${service_url}/clusters" | \
        jq -r ".[] | select(.name == \"${cluster_name}\")"
}

# Fetch infra env data by name
# Usage: fetch_infra_env_data <infra_env_name>
fetch_infra_env_data() {
    local infra_env_name="$1"
    local service_url=$(get_assisted_service_url)
    curl -sSf -H "Authorization: Bearer ${OCM_TOKEN}" "${service_url}/infra-envs" | \
        jq -r ".[] | select(.name == \"${infra_env_name}\")"
}

# Extract cluster properties from cluster data
# Usage: extract_cluster_properties <cluster_data>
# Outputs: ACTUAL_VERSION, ACTUAL_DOMAIN, ACTUAL_SINGLE_NODE, ACTUAL_CPU_ARCH, ACTUAL_SSH_KEY
extract_cluster_properties() {
    local cluster_data="$1"
    ACTUAL_VERSION=$(echo "$cluster_data" | jq -r '.openshift_version')
    ACTUAL_DOMAIN=$(echo "$cluster_data" | jq -r '.base_dns_domain')
    ACTUAL_SINGLE_NODE=$(echo "$cluster_data" | jq -r '.high_availability_mode == "None"')
    ACTUAL_CPU_ARCH=$(echo "$cluster_data" | jq -r '.cpu_architecture')
    ACTUAL_SSH_KEY=$(echo "$cluster_data" | jq -r '.ssh_public_key')
}

# Validate cluster properties (version, domain, single_node, cpu_arch, ssh_key)
# Usage: validate_cluster_properties <expected_version> <expected_domain> <expected_single_node> <expected_cpu_arch> [expected_ssh_key]
validate_cluster_properties() {
    local expected_version="$1"
    local expected_domain="$2"
    local expected_single_node="$3"
    local expected_cpu_arch="$4"
    local expected_ssh_key="${5:-}"

    if [[ "$ACTUAL_VERSION" == "$expected_version" && \
          "$ACTUAL_DOMAIN" == "$expected_domain" && \
          "$ACTUAL_SINGLE_NODE" == "$expected_single_node" && \
          "$ACTUAL_CPU_ARCH" == "$expected_cpu_arch" ]]; then
        # If SSH key is provided, validate it too
        if [[ -n "$expected_ssh_key" ]]; then
            if [[ "$ACTUAL_SSH_KEY" == "$expected_ssh_key" ]]; then
                return 0
            else
                return 1
            fi
        else
            return 0
        fi
    else
        return 1
    fi
}


# Wait for cluster to exist and validate
# Usage: wait_and_validate_cluster <cluster_name_prefix> <expected_version> <expected_domain> <expected_single_node> <expected_cpu_arch> <cluster_type> [expected_ssh_key]
wait_and_validate_cluster() {
    local cluster_name_prefix="$1"
    local expected_version="$2"
    local expected_domain="$3"
    local expected_single_node="$4"
    local expected_cpu_arch="$5"
    local cluster_type="$6"
    local expected_ssh_key="${7:-}"

    local cluster_name="${cluster_name_prefix}-${UNIQUE_ID}"

    local counter=0
    while true; do
        local cluster_data=$(fetch_cluster_data "$cluster_name")

        if [[ -n "$cluster_data" && "$cluster_data" != "null" ]]; then
            extract_cluster_properties "$cluster_data"
            if validate_cluster_properties "$expected_version" "$expected_domain" "$expected_single_node" "$expected_cpu_arch" "$expected_ssh_key"; then
                echo_out "The ${cluster_type} cluster was successfully created with correct configuration:"
                echo_out "  Name: ${cluster_name}"
                echo_out "  Version: ${ACTUAL_VERSION}"
                echo_out "  Domain: ${ACTUAL_DOMAIN}"
                echo_out "  Single Node: ${ACTUAL_SINGLE_NODE}"
                echo_out "  CPU Architecture: ${ACTUAL_CPU_ARCH}"
                if [[ -n "$expected_ssh_key" ]]; then
                    echo_out "  SSH Key: ${ACTUAL_SSH_KEY}"
                fi
                exit 0
            else
                echo_err "Cluster found but configuration mismatch:"
                echo_err "  Expected version: ${expected_version}, got: ${ACTUAL_VERSION}"
                echo_err "  Expected domain: ${expected_domain}, got: ${ACTUAL_DOMAIN}"
                echo_err "  Expected single node: ${expected_single_node}, got: ${ACTUAL_SINGLE_NODE}"
                echo_err "  Expected CPU architecture: ${expected_cpu_arch}, got: ${ACTUAL_CPU_ARCH}"
                if [[ -n "$expected_ssh_key" ]]; then
                    echo_err "  Expected SSH key: ${expected_ssh_key}, got: ${ACTUAL_SSH_KEY}"
                fi
                exit 1
            fi
        fi

        if [[ $counter -ge 3 ]]; then
            echo_err "Cluster creation timed out"
            exit 1
        fi
        ((counter++))
        sleep 10
    done
}

