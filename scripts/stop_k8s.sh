#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-assisted-chat}"

if ! command -v oc >/dev/null 2>&1; then
	echo "Error: oc CLI is required. Please install and login to a cluster (e.g., minikube, kind, OpenShift)." >&2
	exit 1
fi

oc scale deployment/assisted-chat -n "$NAMESPACE" --replicas=0 || true

echo "Scaled deployment/assisted-chat to 0 replicas in namespace $NAMESPACE" 