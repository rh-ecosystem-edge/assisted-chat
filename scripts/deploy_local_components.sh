#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
NAMESPACE="${NAMESPACE:-assisted-chat}"

if ! command -v oc >/dev/null 2>&1; then
	echo "Error: oc CLI is required. Please install and login to a cluster (e.g., minikube, kind, OpenShift)." >&2
	exit 1
fi

# Obtain OCM tokens for UI auth:
# - If OCM_REFRESH_TOKEN (and optionally OCM_TOKEN) is already set (e.g., CI), use it directly.
# - Otherwise, try to retrieve via ocm CLI.
: "${OCM_REFRESH_TOKEN:=}"
: "${OCM_TOKEN:=}"
if [[ -z "$OCM_REFRESH_TOKEN" ]]; then
	# Only attempt CLI retrieval if token not pre-provided
	if command -v ocm >/dev/null 2>&1; then
		source "$PROJECT_ROOT/utils/ocm-token.sh"
		if ! export_ocm_token; then
			echo "Failed to get OCM tokens. The UI container will not be able to authenticate with OCM."
			echo "Hint: run 'ocm login --use-auth-code' locally, or set OCM_REFRESH_TOKEN in the environment."
			exit 1
		fi
	else
		echo "OCM CLI not found and OCM_REFRESH_TOKEN not set."
		echo "Install ocm and run 'ocm login --use-auth-code', or export OCM_REFRESH_TOKEN before running."
		exit 1
	fi
fi

# Create or update a secret with OCM tokens for the UI
cat <<'EOF' | OCM_REFRESH_TOKEN="$OCM_REFRESH_TOKEN" OCM_TOKEN="${OCM_TOKEN:-}" envsubst | oc -n "$NAMESPACE" apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: assisted-chat-ocm-tokens
type: Opaque
stringData:
  OCM_REFRESH_TOKEN: "${OCM_REFRESH_TOKEN}"
  # OCM_TOKEN is optional
  OCM_TOKEN: "${OCM_TOKEN}"
EOF

# Default local images to match podman tags used in assisted-chat-pod.yaml
UI_IMAGE="${UI_IMAGE:-localhost/local-ai-chat-ui:latest}"
INSPECTOR_IMAGE="${INSPECTOR_IMAGE:-localhost/local-ai-chat-inspector:latest}"
ASSISTED_MCP_IMAGE="${ASSISTED_MCP_IMAGE:-localhost/local-ai-chat-assisted-service-mcp:latest}"
SERVICE_PORT="${SERVICE_PORT:-8090}"

# Helper to determine pull policy
pullPolicyFor() {
	local image="$1"
	if [[ "$image" == localhost/* || "$image" == 127.0.0.1/* ]]; then
		echo IfNotPresent
	else
		echo Always
	fi
}

UI_PULL_POLICY=$(pullPolicyFor "$UI_IMAGE")
MCP_PULL_POLICY=$(pullPolicyFor "$ASSISTED_MCP_IMAGE")
INSPECTOR_PULL_POLICY=$(pullPolicyFor "$INSPECTOR_IMAGE")

# Apply external manifest with substitutions
env -i \
  NAMESPACE="$NAMESPACE" \
  UI_IMAGE="$UI_IMAGE" \
  UI_PULL_POLICY="$UI_PULL_POLICY" \
  SERVICE_PORT="$SERVICE_PORT" \
  ASSISTED_MCP_IMAGE="$ASSISTED_MCP_IMAGE" \
  MCP_PULL_POLICY="$MCP_PULL_POLICY" \
  INSPECTOR_IMAGE="$INSPECTOR_IMAGE" \
  INSPECTOR_PULL_POLICY="$INSPECTOR_PULL_POLICY" \
  bash -c 'envsubst < "'$PROJECT_ROOT'/resources/local-dev-components.yaml" | oc apply -n "'$NAMESPACE'" -f -'

echo "Local components (UI, assisted-service-mcp, inspector) deployed to namespace $NAMESPACE"

# Wait briefly and show status
sleep 3
oc get pods -n "$NAMESPACE" -l app=assisted-chat 