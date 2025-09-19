#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-assisted-chat}"

if ! command -v oc >/dev/null 2>&1; then
	echo "Error: oc CLI is required. Please install and login to a cluster (e.g., minikube, kind, OpenShift)." >&2
	exit 1
fi

echo "Deleting namespace $NAMESPACE and all its resources..."
if oc delete namespace "$NAMESPACE" --ignore-not-found; then
	echo "Namespace $NAMESPACE and all its resources have been deleted."
else
	echo "Warning: Failed to delete namespace $NAMESPACE or it didn't exist." >&2
fi 