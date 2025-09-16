#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-assisted-chat}"

if ! command -v oc >/dev/null 2>&1; then
	echo "Error: oc CLI is required. Please install and login to a cluster (e.g., minikube, kind, OpenShift)." >&2
	exit 1
fi

# Best-effort cleanup of resources created by deploy_template.sh
oc delete deployment/assisted-chat -n "$NAMESPACE" --ignore-not-found
oc delete service/assisted-chat -n "$NAMESPACE" --ignore-not-found
oc delete route.route.openshift.io/assisted-chat -n "$NAMESPACE" --ignore-not-found || true

# Config and secrets
oc delete configmap/lightspeed-stack-config -n "$NAMESPACE" --ignore-not-found
oc delete configmap/llama-stack-client-config -n "$NAMESPACE" --ignore-not-found
oc delete configmap/lightspeed-exporter-config -n "$NAMESPACE" --ignore-not-found
oc delete secret/vertex-service-account -n "$NAMESPACE" --ignore-not-found
oc delete secret/insights-ingress -n "$NAMESPACE" --ignore-not-found
oc delete secret/llama-stack-db -n "$NAMESPACE" --ignore-not-found
oc delete secret/postgres-secret -n "$NAMESPACE" --ignore-not-found

# Postgres helpers
oc delete service/postgres-service -n "$NAMESPACE" --ignore-not-found
oc delete deployment/postgres -n "$NAMESPACE" --ignore-not-found

# ServiceAccount and pull secret reference
oc delete serviceaccount/assisted-chat -n "$NAMESPACE" --ignore-not-found

# Optionally delete namespace if it was only used for local dev
echo "If you created the namespace for testing, you can delete it with: oc delete namespace $NAMESPACE" 