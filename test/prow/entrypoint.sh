#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail


OCM_TOKEN=$(curl -X POST https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" | jq '.access_token' | sed "s/^['\"]*//; s/['\"]*$//")

echo "$OCM_TOKEN" > test/evals/ocm_token.txt
echo "GEMINI_API_KEY=${GEMINI_API_KEY}" > .env

mkdir -p ~/.config/containers
curl -H "Authorization: Bearer ${OCM_TOKEN}" -X POST https://api.stage.openshift.com/api/accounts_mgmt/v1/access_token > ~/.config/containers/auth.json
sleep 3600

cd test/evals

python eval.py --agent_endpoint "${AGENT_URL}:${AGENT_PORT}"
