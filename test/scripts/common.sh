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
    ACTUAL_PLATFORM=$(echo "$cluster_data" | jq -r 'if .platform.type == "external" then .platform.external.platform_name else .platform.type end')
}

validate_expected_ssh_key() {
    local expected_ssh_key="${1:-}"
    if [[ -n "$expected_ssh_key" ]]; then
        if [[ "$ACTUAL_SSH_KEY" == "$expected_ssh_key" ]]; then
            return 0
        else
            return 1
        fi
    else
        return 0
    fi
}

validate_expected_platform() {
    local expected_platform="${1:-}"
    if [[ -n "$expected_platform" ]]; then
        if [[ "$ACTUAL_PLATFORM" == "$expected_platform" ]]; then
            return 0
        else
            return 1
        fi
    else
        return 0
    fi
}
# Validate cluster properties (version, domain, single_node, cpu_arch, ssh_key)
# Usage: validate_cluster_properties <expected_version> <expected_domain> <expected_single_node> <expected_cpu_arch> [expected_ssh_key] [expected_platform]
validate_cluster_properties() {
    local expected_version="$1"
    local expected_domain="$2"
    local expected_single_node="$3"
    local expected_cpu_arch="$4"
    local expected_ssh_key="${5:-}"
    local expected_platform="${6:-}"

    if [[ "$ACTUAL_VERSION" == "$expected_version" && \
          "$ACTUAL_DOMAIN" == "$expected_domain" && \
          "$ACTUAL_SINGLE_NODE" == "$expected_single_node" && \
          "$ACTUAL_CPU_ARCH" == "$expected_cpu_arch" ]]; then
        # If SSH key or platform is provided, validate them too
        if validate_expected_ssh_key "$expected_ssh_key" && validate_expected_platform "$expected_platform"; then
            return 0
        else
            return 1
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
    local expected_platform="${8:-}"
    local cluster_name="${cluster_name_prefix}-${UNIQUE_ID}"

    local counter=0
    while true; do
        local cluster_data=$(fetch_cluster_data "$cluster_name")
        if [[ -n "$cluster_data" && "$cluster_data" != "null" ]]; then
            extract_cluster_properties "$cluster_data"
            if validate_cluster_properties "$expected_version" "$expected_domain" "$expected_single_node" "$expected_cpu_arch" "$expected_ssh_key" "$expected_platform"; then
                echo_out "The ${cluster_type} cluster was successfully created with correct configuration:"
                echo_out "  Name: ${cluster_name}"
                echo_out "  Version: ${ACTUAL_VERSION}"
                echo_out "  Domain: ${ACTUAL_DOMAIN}"
                echo_out "  Single Node: ${ACTUAL_SINGLE_NODE}"
                echo_out "  CPU Architecture: ${ACTUAL_CPU_ARCH}"
                if [[ -n "$expected_ssh_key" ]]; then
                    echo_out "  SSH Key: ${ACTUAL_SSH_KEY}"
                fi
                if [[ -n "$expected_platform" ]]; then
                    echo_out "  Platform: ${ACTUAL_PLATFORM}"
                fi
                exit 0
            else
                echo_err "Cluster found but configuration mismatch:"
                echo_err "  Cluster ID: $(echo "$cluster_data" | jq -r '.id')"
                echo_err "  Status: $(echo "$cluster_data" | jq -r '.status')"
                echo_err "  high_availability_mode: $(echo "$cluster_data" | jq -r '.high_availability_mode')"
                echo_err "  platform.type: $(echo "$cluster_data" | jq -r '.platform.type')"
                echo_err "  Expected version: ${expected_version}, got: ${ACTUAL_VERSION}"
                echo_err "  Expected domain: ${expected_domain}, got: ${ACTUAL_DOMAIN}"
                echo_err "  Expected single node: ${expected_single_node}, got: ${ACTUAL_SINGLE_NODE}"
                echo_err "  Expected CPU architecture: ${expected_cpu_arch}, got: ${ACTUAL_CPU_ARCH}"
                if [[ -n "$expected_ssh_key" ]]; then
                    echo_err "  Expected SSH key: ${expected_ssh_key}, got: ${ACTUAL_SSH_KEY}"
                fi
                if [[ -n "$expected_platform" ]]; then
                    echo_err "  Expected platform: ${expected_platform}, got: ${ACTUAL_PLATFORM}"
                fi
                exit 1
            fi
        fi

        if [[ $counter -ge 3 ]]; then
            echo_err "Cluster creation timed out (cluster '${cluster_name}' not found)"
            echo_err "Debug: listing clusters matching prefix '${cluster_name_prefix}-' for UNIQUE_ID='${UNIQUE_ID}'"
            local service_url
            service_url=$(get_assisted_service_url)
            curl -fsS -H "Authorization: Bearer ${OCM_TOKEN}" "${service_url}/clusters" | \
                jq -r --arg pfx "${cluster_name_prefix}-" --arg uid "${UNIQUE_ID}" \
                    '.[] | select(.name | startswith($pfx)) | select(.name | contains($uid)) | "\(.name) \(.id)"' | \
                head -n 20 || true
            exit 1
        fi
        ((counter++))
        sleep 10
    done
}

