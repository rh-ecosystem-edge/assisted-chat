#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
NAMESPACE="${NAMESPACE:-assisted-chat}"

if ! command -v oc >/dev/null 2>&1; then
	echo "Error: oc CLI is required. Please install and login to a cluster (e.g., minikube, kind, OpenShift)." >&2
	exit 1
fi

# Ensure OCM tokens are available for UI (mirrors podman flow)
source "$PROJECT_ROOT/utils/ocm-token.sh"
if ! export_ocm_token; then
	echo "Failed to get OCM tokens. The UI container will not be able to authenticate with OCM."
	exit 1
fi

# Create or update a secret with OCM tokens for the UI
oc -n "$NAMESPACE" delete secret assisted-chat-ocm-tokens --ignore-not-found
oc -n "$NAMESPACE" create secret generic assisted-chat-ocm-tokens \
	--from-literal=OCM_TOKEN="$OCM_TOKEN" \
	--from-literal=OCM_REFRESH_TOKEN="$OCM_REFRESH_TOKEN"

# Default local images to match podman tags used in assisted-chat-pod.yaml
UI_IMAGE="${UI_IMAGE:-localhost/local-ai-chat-ui:latest}"
INSPECTOR_IMAGE="${INSPECTOR_IMAGE:-localhost/local-ai-chat-inspector:latest}"
ASSISTED_MCP_IMAGE="${ASSISTED_MCP_IMAGE:-localhost/local-ai-chat-assisted-service-mcp:latest}"

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

# Create/update Deployments and Services for local-only components
cat <<EOF | oc apply -n "$NAMESPACE" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: assisted-ui
  labels:
    app: assisted-chat
    component: ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: assisted-chat
      component: ui
  template:
    metadata:
      labels:
        app: assisted-chat
        component: ui
    spec:
      containers:
      - name: ui
        image: ${UI_IMAGE}
        imagePullPolicy: ${UI_PULL_POLICY}
        env:
        - name: AIUI_CHAT_API_URL
          value: http://assisted-chat:${SERVICE_PORT:-8090}/
        - name: AIUI_SSO_API_URL
          value: https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
        - name: AIUI_OCM_REFRESH_TOKEN
          valueFrom:
            secretKeyRef:
              name: assisted-chat-ocm-tokens
              key: OCM_REFRESH_TOKEN
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: assisted-ui
  labels:
    app: assisted-chat
    component: ui
spec:
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  selector:
    app: assisted-chat
    component: ui
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: assisted-service-mcp
  labels:
    app: assisted-chat
    component: assisted-service-mcp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: assisted-chat
      component: assisted-service-mcp
  template:
    metadata:
      labels:
        app: assisted-chat
        component: assisted-service-mcp
    spec:
      containers:
      - name: assisted-service-mcp
        image: ${ASSISTED_MCP_IMAGE}
        imagePullPolicy: ${MCP_PULL_POLICY}
        env:
        - name: TRANSPORT
          value: streamable-http
        ports:
        - containerPort: 8000
---
apiVersion: v1
kind: Service
metadata:
  name: assisted-service-mcp
  labels:
    app: assisted-chat
    component: assisted-service-mcp
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 8000
  selector:
    app: assisted-chat
    component: assisted-service-mcp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-inspector
  labels:
    app: assisted-chat
    component: inspector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: assisted-chat
      component: inspector
  template:
    metadata:
      labels:
        app: assisted-chat
        component: inspector
    spec:
      containers:
      - name: mcp-inspector
        image: ${INSPECTOR_IMAGE}
        imagePullPolicy: ${INSPECTOR_PULL_POLICY}
        env:
        - name: HOST
          value: 0.0.0.0
        ports:
        - containerPort: 6274
        - containerPort: 6277
---
apiVersion: v1
kind: Service
metadata:
  name: mcp-inspector
  labels:
    app: assisted-chat
    component: inspector
spec:
  ports:
  - name: ui
    port: 6274
    targetPort: 6274
  - name: agent
    port: 6277
    targetPort: 6277
  selector:
    app: assisted-chat
    component: inspector
EOF

echo "Local components (UI, assisted-service-mcp, inspector) deployed to namespace $NAMESPACE"

# Wait briefly and show status
sleep 3
oc get pods -n "$NAMESPACE" -l app=assisted-chat 