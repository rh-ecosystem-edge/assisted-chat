#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail


OCM_TOKEN=$(curl -X POST https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" | jq '.access_token' | sed "s/^['\"]*//; s/['\"]*$//")

WORK_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)

cd $TEMP_DIR

echo "$OCM_TOKEN" > ocm_token.txt
echo "GEMINI_API_KEY=${GEMINI_API_KEY}" > .env

TEST_DIR="${WORK_DIR}/test/evals"

python $TEST_DIR/eval.py --agent_endpoint "${AGENT_URL}:${AGENT_PORT}" --agent_auth_token_file $TEST_DIR/ocm_token.txt --eval_data_yaml $TEST_DIR/eval_data.yaml
