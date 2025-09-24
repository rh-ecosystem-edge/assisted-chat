#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-assisted-chat}"

if ! command -v oc >/dev/null 2>&1; then
	echo "Error: oc CLI is required. Please install and login to a cluster (e.g., minikube, kind, OpenShift)." >&2
	exit 1
fi

# Wait for any pods with the app label to exist
for i in $(seq 1 60); do
	if oc get pods -n "$NAMESPACE" -l app=assisted-chat -o name | grep -q .; then
		break
	fi
	sleep 2
done

# Wait until pods are Ready (up to 5 minutes)
oc wait --for=condition=Ready pod -l app=assisted-chat -n "$NAMESPACE" --timeout=300s || true

# Show current pod status before streaming logs
oc get pods -n "$NAMESPACE" -l app=assisted-chat -o wide || true

echo "Streaming logs from assisted-chat pods in namespace $NAMESPACE"
# Follow logs for all matching pods (some containers might still be starting; retry on transient errors)
set +e
oc logs -n "$NAMESPACE" -f -l app=assisted-chat --all-containers=true
EXIT_CODE=$?
set -e

exit $EXIT_CODE 