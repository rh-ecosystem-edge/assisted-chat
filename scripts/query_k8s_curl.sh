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

# Wait for deployments to successfully roll out before querying
echo "[query_k8s_curl] Waiting for deployments to roll out in namespace ${NAMESPACE}"
oc rollout status -n "${NAMESPACE}" deployment/assisted-chat --timeout=300s || true
oc rollout status -n "${NAMESPACE}" deployment/assisted-ui --timeout=300s || true
oc rollout status -n "${NAMESPACE}" deployment/assisted-service-mcp --timeout=300s || true
oc rollout status -n "${NAMESPACE}" deployment/mcp-inspector --timeout=300s || true

# Ensure port-forward is established
bash "$PROJECT_ROOT/utils/port_forward.sh"

BASE_URL="http://localhost:${ASSISTED_CHAT_PORT}"

# Compose request payload safely
JSON_PAYLOAD="$(jq -n --arg q "$QUERY_TEXT" '{conversation_id:"", query:$q}')"

# Retry the POST up to 5 times if we get transport errors or non-2xx responses
ATTEMPTS=5
SLEEP_SECS=5
for attempt in $(seq 1 ${ATTEMPTS}); do
  echo "[query_k8s_curl] Attempt ${attempt}/${ATTEMPTS}: POST ${BASE_URL}/v1/query"
  HTTP_CODE=$(curl --silent --show-error --output /tmp/assisted_chat_query_out.json --write-out "%{http_code}" \
    -H "Authorization: Bearer ${OCM_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d "${JSON_PAYLOAD}" \
    "${BASE_URL}/v1/query") || HTTP_CODE="000"

  # Show response body for debugging on failure
  if [[ "${HTTP_CODE}" -lt 200 || "${HTTP_CODE}" -ge 300 ]]; then
    echo "[query_k8s_curl] HTTP ${HTTP_CODE}"
    cat /tmp/assisted_chat_query_out.json || true
    if [[ ${attempt} -lt ${ATTEMPTS} ]]; then
      echo "[query_k8s_curl] will retry in ${SLEEP_SECS}s"
      sleep ${SLEEP_SECS}
      continue
    fi
    echo "[query_k8s_curl] giving up after ${ATTEMPTS} attempts"
    exit 1
  fi

  # Success
  cat /tmp/assisted_chat_query_out.json
  exit 0
done

# Should not reach here
exit 1 