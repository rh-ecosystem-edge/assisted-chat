#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-assisted-chat}"
SERVICE_NAME="${SERVICE_NAME:-assisted-chat}"
LOCAL_PORT="${ASSISTED_CHAT_PORT:-8090}"

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

# Start a background port-forward
oc port-forward -n "${NAMESPACE}" svc/"${SERVICE_NAME}" "${LOCAL_PORT}:${LOCAL_PORT}" >/dev/null 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT

# Wait up to 30s for the port to respond
for i in $(seq 1 30); do
  if curl -sf "http://localhost:${LOCAL_PORT}/readiness" >/dev/null 2>&1 || \
     curl -sf "http://localhost:${LOCAL_PORT}/liveness" >/dev/null 2>&1 || \
     curl -sf "http://localhost:${LOCAL_PORT}/" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 1
done

echo "Port-forward did not become ready in time on localhost:${LOCAL_PORT}" >&2
exit 1 