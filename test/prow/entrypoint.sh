#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail


OCM_TOKEN=$(curl -X POST https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" | jq '.access_token')

echo $OCM_TOKEN > test/evals/ocm_token.txt

cd test/evals

python eval.py --agent_endpoint "${AGENT_URL}:${AGENT_PORT}"