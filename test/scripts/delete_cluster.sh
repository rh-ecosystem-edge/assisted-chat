#!/bin/bash

# Source the common helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

setup_shell_options
validate_environment

ASSISTED_SERVICE_URL=$(get_assisted_service_url)

curl -fsS -H "Authorization: Bearer ${OCM_TOKEN}" "${ASSISTED_SERVICE_URL}/clusters" | jq '[.[] |{id, name}]' | jq -c '.[]' | while read item; do
  id=$(echo "$item" | jq -r '.id')
  name=$(echo "$item" | jq -r '.name')
  if [[ "$name" == *"-${UNIQUE_ID}" ]]; then
    echo "The cluster '${name}', ${id} is going to be deleted"
    curl -fsS -X DELETE -H "Authorization: Bearer ${OCM_TOKEN}" "${ASSISTED_SERVICE_URL}/clusters/${id}"
  fi
done
