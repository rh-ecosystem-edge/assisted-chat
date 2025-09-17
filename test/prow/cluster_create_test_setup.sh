#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

ASSISTED_SERVICE_URL="https://api.stage.openshift.com/api/assisted-install/v2"

PULL_SECRET=$(curl -sSf -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${OCM_TOKEN}" \
              https://api.stage.openshift.com/api/accounts_mgmt/v1/access_token | sed 's/"/\\"/g')

CLUSTER_ID=$(curlcurl -sSf -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${OCM_TOKEN}" \
    -d "{\"name\":\"eval-testcluster-${UNIQUE_ID}\",\"control_plane_count\":1,\"openshift_version\":\"4.18.22\",\"pull_secret\":\"${PULL_SECRET}\",\"base_dns_domain\":\"test.local\"}" \
    "${ASSISTED_SERVICE_URL}/clusters" | jq '.id')

#CLUSTER_ID is already quoted
curl curl -sSf  -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${OCM_TOKEN}" \
    -d "{\"name\":\"eval-testcluster-${UNIQUE_ID}_infra-env\",\"pull_secret\":\"${PULL_SECRET}\",\"cluster_id\":${CLUSTER_ID},\"openshift_version\":\"4.18.22\"}" \
    "${ASSISTED_SERVICE_URL}/infra-envs"

COUNTER=0
while ! curl -sSf -H "Authorization: Bearer ${OCM_TOKEN}" "${ASSISTED_SERVICE_URL}/clusters" | grep "eval-testcluster-${UNIQUE_ID}"; do
    if [[ $COUNTER -gt 3 ]]; then
        echo "Cluster creation timed out"
        exit 1
    fi
    ((COUNTER++))
    sleep 10
done