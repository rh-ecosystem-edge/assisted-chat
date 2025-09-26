#!/bin/bash

set -euo pipefail

# Setup secrets directory for assisted-chat deployment
# This script handles setting up the secrets directory, either using a local
# VERTEX_SERVICE_ACCOUNT_PATH or the default /var/run/secrets path

echo "Setting up secrets directory" >&2

# Set default secrets base path
SECRETS_BASE_PATH="${SECRETS_BASE_PATH:-/var/run/secrets}"
TEMP_SECRETS_DIR=""

# Cleanup function to remove temporary directories
cleanup() {
    if [ -n "$TEMP_SECRETS_DIR" ] && [ -d "$TEMP_SECRETS_DIR" ]; then
        echo "Cleaning up temporary secrets directory..." >&2
        rm -rf "$TEMP_SECRETS_DIR"
    fi
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# Handle local vertex service account path if provided
if [ -n "${VERTEX_SERVICE_ACCOUNT_PATH:-}" ]; then
    if [ ! -f "$VERTEX_SERVICE_ACCOUNT_PATH" ]; then
        echo "Error: VERTEX_SERVICE_ACCOUNT_PATH file does not exist: $VERTEX_SERVICE_ACCOUNT_PATH" >&2
        exit 1
    fi
    
    # Create temporary directory with secure permissions
    TEMP_SECRETS_DIR=$(mktemp -d)
    chmod 700 "$TEMP_SECRETS_DIR"
    
    # Create vertex subdirectory
    mkdir -p "$TEMP_SECRETS_DIR/vertex"
    chmod 700 "$TEMP_SECRETS_DIR/vertex"
    
    # Copy service account file with secure permissions
    cp "$VERTEX_SERVICE_ACCOUNT_PATH" "$TEMP_SECRETS_DIR/vertex/service_account"
    chmod 600 "$TEMP_SECRETS_DIR/vertex/service_account"
    
    # Update secrets base path to use temporary directory
    SECRETS_BASE_PATH="$TEMP_SECRETS_DIR"
fi

echo "Using SECRETS_BASE_PATH=$SECRETS_BASE_PATH" >&2

# Output the secrets base path for use by calling script
echo "$SECRETS_BASE_PATH" 