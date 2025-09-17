#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
NAMESPACE="${NAMESPACE:-assisted-chat}"
ASSISTED_CHAT_PORT="${ASSISTED_CHAT_PORT:-8090}"
export NAMESPACE ASSISTED_CHAT_PORT

if ! command -v oc >/dev/null 2>&1; then
	echo "Error: oc CLI is required to port-forward to the cluster." >&2
	exit 1
fi

# Ensure port-forward is established
bash "$PROJECT_ROOT/utils/port_forward.sh"

# Run evaluation
UNIQUE_ID=$(head /dev/urandom | tr -dc 0-9a-z | head -c 8)
export UNIQUE_ID
export TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
cp test/evals/eval_data.yaml "${TEMP_DIR}/eval_data.yaml"
sed -i "s/uniq-cluster-name/${UNIQUE_ID}/g" "${TEMP_DIR}/eval_data.yaml"
cd "${PROJECT_ROOT}/test/evals"
python eval.py --agent_endpoint "http://localhost:${ASSISTED_CHAT_PORT}" --eval_data_yaml "${TEMP_DIR}/eval_data.yaml"