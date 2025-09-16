#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
NAMESPACE="${NAMESPACE:-assisted-chat}"
PORT="${ASSISTED_CHAT_PORT:-8090}"
QUERY_TEXT="${QUERY_TEXT:-Show me all my clusters}"

if ! command -v oc >/dev/null 2>&1; then
	echo "Error: oc CLI is required." >&2
	exit 1
fi

# Obtain OCM bearer token
. "$PROJECT_ROOT/utils/ocm-token.sh"
if ! get_ocm_token; then
	echo "Error: unable to obtain OCM token. Run 'ocm login --use-auth-code' or set OCM_REFRESH_TOKEN/OCM_TOKEN." >&2
	exit 1
fi

# Establish port-forward if not already serving
if ! curl -sf "http://localhost:${PORT}/readiness" >/dev/null 2>&1 \
   && ! curl -sf "http://localhost:${PORT}/liveness" >/dev/null 2>&1 \
   && ! curl -sf "http://localhost:${PORT}/" >/dev/null 2>&1; then
	oc port-forward -n "${NAMESPACE}" svc/assisted-chat "${PORT}:${PORT}" >/dev/null 2>&1 &
	PF_PID=$!
	trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
	for i in $(seq 1 30); do
		if curl -sf "http://localhost:${PORT}/readiness" >/dev/null 2>&1 \
			|| curl -sf "http://localhost:${PORT}/liveness" >/dev/null 2>&1 \
			|| curl -sf "http://localhost:${PORT}/" >/dev/null 2>&1; then
			break
		fi
		sleep 1
	done
fi

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
  "http://localhost:${PORT}/v1/query")

cat /tmp/assisted_chat_query_out.json

if [[ "${HTTP_CODE}" -lt 200 || "${HTTP_CODE}" -ge 300 ]]; then
	echo "\nError: HTTP ${HTTP_CODE}" >&2
	exit 1
fi 