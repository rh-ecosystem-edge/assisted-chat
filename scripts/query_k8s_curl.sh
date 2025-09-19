#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
NAMESPACE="${NAMESPACE:-assisted-chat}"
ASSISTED_CHAT_PORT="${ASSISTED_CHAT_PORT:-8090}"
QUERY_TEXT="${QUERY_TEXT:-Show me all my clusters}"

if ! command -v oc >/dev/null 2>&1; then
	echo "Error: oc CLI is required." >&2
	exit 1
fi

# Obtain OCM bearer token
: "${OCM_TOKEN:=}"
if [[ -z "${OCM_TOKEN}" ]]; then
	. "$PROJECT_ROOT/utils/ocm-token.sh"
	if ! get_ocm_token; then
		echo "Error: unable to obtain OCM token. Run 'ocm login --use-auth-code' or set OCM_TOKEN/OCM_REFRESH_TOKEN." >&2
		exit 1
	fi
fi

# Ensure port-forward is established
bash "$PROJECT_ROOT/utils/port_forward.sh"

# Compose request payload without explicit model to use server default
read -r -d '' JSON_PAYLOAD <<EOF || true
{
  "conversation_id": "",
  "query": "${QUERY_TEXT}"
}
EOF

# Use portable JSON post
HTTP_CODE=$(curl --silent --show-error --output /tmp/assisted_chat_query_out.json --write-out "%{http_code}" \
  -H "Authorization: Bearer ${OCM_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d "${JSON_PAYLOAD}" \
  "http://localhost:${ASSISTED_CHAT_PORT}/v1/query")

cat /tmp/assisted_chat_query_out.json

if [[ "${HTTP_CODE}" -lt 200 || "${HTTP_CODE}" -ge 300 ]]; then
	echo "\nError: HTTP ${HTTP_CODE}" >&2
	exit 1
fi 