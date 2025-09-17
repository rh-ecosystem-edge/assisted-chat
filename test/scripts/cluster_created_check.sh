#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

: "${OCM_TOKEN:?OCM_TOKEN is required}"
: "${UNIQUE_ID:?UNIQUE_ID is required}"
ASSISTED_SERVICE_URL="${OCM_BASE_URL:-https://api.stage.openshift.com}/api/assisted-install/v2"

COUNTER=0
while ! curl -sSf -H "Authorization: Bearer ${OCM_TOKEN}" "${ASSISTED_SERVICE_URL}/clusters" | grep "${UNIQUE_ID}"; do
    if [[ $COUNTER -gt 3 ]]; then
        echo "Cluster creation timed out"
        exit 1
    fi
    ((COUNTER++))
    sleep 10
done

echo "The cluster was successfully created by the eval test using the mcp tool call."