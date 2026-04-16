#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

setup_shell_options
validate_environment

ASSISTED_SERVICE_URL=$(get_assisted_service_url)

# Fetch all available OpenShift versions from the API
fetch_versions() {
    curl -sSf -H "Authorization: Bearer ${OCM_TOKEN}" \
        "${ASSISTED_SERVICE_URL}/openshift-versions" | jq -r 'keys[]'
}

# Filter to get only stable (non-pre-release) versions
# Pre-release versions contain: -fc, -rc, -ec, -nightly, -ci
get_stable_versions() {
    local versions="$1"
    echo "$versions" | grep -vE '(-fc|-rc|-ec|-nightly|-ci)' || true
}

# Sort versions and get the latest one
get_latest_version() {
    local versions="$1"
    echo "$versions" | sort -V | tail -1
}

# Main execution
echo_out "Fetching available OpenShift versions..."

ALL_VERSIONS=$(fetch_versions)
if [[ -z "$ALL_VERSIONS" ]]; then
    echo_err "Failed to fetch versions from API"
    exit 1
fi

STABLE_VERSIONS=$(get_stable_versions "$ALL_VERSIONS")
if [[ -z "$STABLE_VERSIONS" ]]; then
    echo_err "No stable versions found"
    exit 1
fi

LATEST_STABLE=$(get_latest_version "$STABLE_VERSIONS")
if [[ -z "$LATEST_STABLE" ]]; then
    echo_err "Could not determine latest stable version"
    exit 1
fi

echo_out "Latest stable OCP version: ${LATEST_STABLE}"

exit 0

