#!/bin/bash

set -euo pipefail

MODE="${1:-}"
if [[ -z "$MODE" ]]; then
	echo "Usage: $0 <minikube|kind>" >&2
	exit 1
fi

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
	case "$MODE" in
		minikube)
			echo "Loading $img into minikube"
			minikube image load "$TAR" || minikube image load "$img" || true
			;;
		kind)
			echo "Loading $img into kind"
			kind load image-archive "$TAR" || kind load docker-image "$img" || true
			;;
		*)
			echo "Unknown mode: $MODE" >&2; exit 1;
			;;
	esac
done

echo "Done loading images into $MODE" 