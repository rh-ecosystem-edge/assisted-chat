#!/bin/bash

set -euo pipefail

IMAGES=(
	"localhost/local-ai-chat-lightspeed-stack-plus-llama-stack:latest"
	"localhost/local-ai-chat-ui:latest"
	"localhost/local-ai-chat-assisted-service-mcp:latest"
	"localhost/local-ai-chat-inspector:latest"
)

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

for img in "${IMAGES[@]}"; do
	TAR="$TMPDIR/$(echo "$img" | tr '/:' '_').tar"
	if ! podman image exists "$img"; then
		echo "Skipping $img: not found in podman"
		continue
	fi
	echo "Saving $img to $TAR"
	podman save -o "$TAR" "$img"
	echo "Loading $img into minikube"
	minikube image load "$TAR" || minikube image load "$img" || true
done

echo "Done loading images into minikube" 