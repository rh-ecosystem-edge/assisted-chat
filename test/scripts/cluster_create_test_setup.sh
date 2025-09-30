#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

: "${OCM_TOKEN:?OCM_TOKEN is required}"
: "${UNIQUE_ID:?UNIQUE_ID is required}"
OCM_BASE_URL=${OCM_BASE_URL:-https://api.stage.openshift.com}
ASSISTED_SERVICE_URL="${OCM_BASE_URL}/api/assisted-install/v2"

PULL_SECRET_RAW="$(
  curl -sSf -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OCM_TOKEN}" \
    "${OCM_BASE_URL}/api/accounts_mgmt/v1/access_token"
)"

CLUSTER_PAYLOAD="$(
  jq -n \
    --arg name "eval-testcluster-${UNIQUE_ID}" \
    --arg version "4.18.22" \
    --arg pull_secret "$PULL_SECRET_RAW" \
    --arg base_dns_domain "test.local" \
    --argjson control_plane_count 1 \
    '{name:$name, control_plane_count:$control_plane_count, openshift_version:$version, pull_secret:$pull_secret, base_dns_domain:$base_dns_domain}'
)"

CLUSTER_ID="$(
  curl -sSf -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OCM_TOKEN}" \
    -d "${CLUSTER_PAYLOAD}" \
    "${ASSISTED_SERVICE_URL}/clusters" | jq -r '.id'
)"

INFRA_PAYLOAD="$(
  jq -n \
    --arg name "eval-testcluster-${UNIQUE_ID}_infra-env" \
    --arg pull_secret "$PULL_SECRET_RAW" \
    --arg cluster_id "$CLUSTER_ID" \
    --arg openshift_version "4.18.22" \
    '{name:$name, pull_secret:$pull_secret, cluster_id:$cluster_id, openshift_version:$openshift_version}'
)"

curl -sSf -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OCM_TOKEN}" \
  -d "${INFRA_PAYLOAD}" \
  "${ASSISTED_SERVICE_URL}/infra-envs"




COUNTER=0
while ! curl -sSf -H "Authorization: Bearer ${OCM_TOKEN}" "${ASSISTED_SERVICE_URL}/clusters/${CLUSTER_ID}"; do
    if [[ $COUNTER -gt 3 ]]; then
        echo "Cluster creation timed out"
        exit 1
    fi
    ((COUNTER++))
    sleep 10
done