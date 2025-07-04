#!/bin/bash

# OCM Token Utility Functions
# This file contains shared logic for validating and retrieving OCM tokens

# Function to check if OCM is available and get a valid token
# Returns 0 on success, 1 on failure
# Sets OCM_TOKEN variable on success
get_ocm_token() {
    if ! command -v ocm &>/dev/null; then
        echo "Error: The 'ocm' command is not installed. Please install the ocm CLI from https://console.redhat.com/openshift/token first" >&2
        return 1
    fi

    if ! OCM_TOKEN=$(ocm token 2>/dev/null); then
        echo "Error: You are not logged in to OCM. Please run 'ocm login --use-auth-code' and follow the instructions." >&2
        return 1
    elif [ -z "${OCM_TOKEN}" ]; then
        echo "Error: Received an empty token from the 'ocm token' command." >&2
        echo "You may need to refresh your OCM login first. Please run 'ocm login --use-auth-code' and follow the instructions." >&2
        return 1
    fi

    return 0
}

# Function to validate and export OCM token as environment variable
# This is useful for scripts that need to use the token in environment substitution
export_ocm_token() {
    if get_ocm_token; then
        export OCM_TOKEN
        echo "OCM token successfully validated and exported." >&2
        return 0
    else
        return 1
    fi
} 