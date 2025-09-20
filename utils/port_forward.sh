#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-assisted-chat}"
SERVICE_NAME="${SERVICE_NAME:-assisted-chat}"
LOCAL_PORT="${ASSISTED_CHAT_PORT:-8090}"
PORT_FORWARD_PID_FILE="${PORT_FORWARD_PID_FILE:-/tmp/pf-${SERVICE_NAME}.pid}"

if ! command -v oc >/dev/null 2>&1; then
  echo "Error: oc CLI is required to port-forward to the cluster." >&2
  exit 1
fi

# If already reachable, nothing to do
if curl -sf "http://localhost:${LOCAL_PORT}/readiness" >/dev/null 2>&1 || \
   curl -sf "http://localhost:${LOCAL_PORT}/liveness" >/dev/null 2>&1 || \
   curl -sf "http://localhost:${LOCAL_PORT}/" >/dev/null 2>&1; then
  exit 0
fi

# Start a background port-forward and keep it running after this script exits
# Use nohup to survive SIGHUP when this script exits. Prefer starting in a new session.
if command -v setsid >/dev/null 2>&1; then
nohup setsid oc port-forward -n "${NAMESPACE}" svc/"${SERVICE_NAME}" "${LOCAL_PORT}:${LOCAL_PORT}" >/dev/null 2>&1 &
else
nohup oc port-forward -n "${NAMESPACE}" svc/"${SERVICE_NAME}" "${LOCAL_PORT}:${LOCAL_PORT}" >/dev/null 2>&1 &
fi
PF_PID=$!
# Record PID for caller cleanup
echo "${PF_PID}" > "${PORT_FORWARD_PID_FILE}"

# Ensure we clean up the PF on failure/interrupt, but keep it alive on success.
success=0
trap 'if [[ ${success} -eq 0 ]]; then kill "${PF_PID}" >/dev/null 2>&1 || true; rm -f "${PORT_FORWARD_PID_FILE}"; fi' INT TERM EXIT

# Wait up to 30s for the port to respond
for _ in {1..30}; do
  # Bail out early if the port-forward process died
  if ! kill -0 "${PF_PID}" 2>/dev/null; then
    echo "Port-forward process exited early (PID ${PF_PID})." >&2
    exit 1
  fi
  if curl -sf "http://localhost:${LOCAL_PORT}/readiness" >/dev/null 2>&1 || \
     curl -sf "http://localhost:${LOCAL_PORT}/liveness" >/dev/null 2>&1 || \
     curl -sf "http://localhost:${LOCAL_PORT}/" >/dev/null 2>&1; then
    success=1
    trap - INT TERM EXIT
    exit 0
  fi
  sleep 1
done

echo "Port-forward did not become ready in time on localhost:${LOCAL_PORT}" >&2
exit 1 