#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-assisted-chat}"

if ! command -v oc >/dev/null 2>&1; then
	echo "Error: oc CLI is required. Please install and login to a cluster (e.g., minikube, kind, OpenShift)." >&2
	exit 1
fi

PODS=$(oc get pods -n "$NAMESPACE" -l app=assisted-chat -o name || true)
if [ -z "$PODS" ]; then
	echo "No assisted-chat pods found in namespace $NAMESPACE. Waiting for rollout..."
	oc rollout status -n "$NAMESPACE" deployment/assisted-chat --timeout=300s || true
	PODS=$(oc get pods -n "$NAMESPACE" -l app=assisted-chat -o name || true)
fi

if [ -z "$PODS" ]; then
	echo "Still no pods found. Exiting."
	exit 1
fi

echo "Streaming logs from assisted-chat pods in namespace $NAMESPACE"
# Follow logs for all matching pods
oc logs -n "$NAMESPACE" -f -l app=assisted-chat --all-containers=true 