# Assisted Chat

This repo builds the images for and runs in a podman pod the following services:
- [x] assisted-service-mcp
- [x] lightspeed-core + llama-stack (Same container, built separately)
- [x] assisted UI
- [x] inspector
- [x] postgres

# Pre-requisites

- the `ocm` command (get it [here](https://console.redhat.com/openshift/token))

- Either Vertex AI service account credentials or a Gemini API key. If using a Gemini API key, run `make generate` for instructions on how to get one.

- An OpenShift pull-secret (https://cloud.redhat.com/openshift/install/pull-secret)
    - Apply it to podman by copying it to ~/.config/containers/auth.json

- Some report needing a **Red Hat Developer Subscription** (required for building container images)
  - You might not need one
  - Sign up for free at https://developers.redhat.com/register
    1. Login to container registry: `podman login registry.access.redhat.com`
    2. Register your system: `sudo subscription-manager register --username <your-username>`
  - Verify registration: `subscription-manager status`

## Dependencies

`dnf install jq fzf`

`pip install yq uv`

## Submodules

```bash
git submodule init
git submodule update
```

# Overview

## Basics

This repo uses a podman pod to run all the required services for the Assisted
chat bot. The pod is defined in `assisted-chat-pod.yaml`. The pod images are
built from the git submodules in this repo. We use a Makefile for running
commands.

You are expected to first run `make generate` to generate the `.env` and
configuration files. `make generate` is interactive and will ask you whether
you want to use a Gemini API key or Vertex AI service account credentials. 

Before running the pod, you should run `make build-images` to build all the
required images. You can also build individual images using `make build-*`
commands (see `make help`).

Once you've generated the configuration files and built the images, you can run
the pod with `make run`. This will start the pod and follow its logs. You can
safely ctrl+c out of it and the pod will continue running in the background. To
stop the pod, run `make stop` and optionally `make rm` to remove it completely.
If you wish to see the logs again while it's running, use `make logs`.

To interact with assisted-chat, use `make query`. 

## Extra

You can also use `make query-int` and `make query-stage` to interact with the
SaaS deployed integration and staging environments, respectively. This does not
require the pod to be running.

You can interact with the model directly with `mcphost` through `make mcphost`
- it's a bit weird, you have to first Ctrl+C out of it, then quickly run `make
mcphost` again for it to actually work. Please fix it if you figure out why
it's happening.

To see the contents of the postgres database, use `make psql`. This will put
you in a `psql` shell. The database is used by both llama-stack and
lightspeed-stack. llama-stack uses the `default` schema while lightspeed-stack
uses the `lightspeed-stack` schema. The `psql` shell is pre-configured to see
both schemas. If you're running `lightspeed-stack` without a database
configuration you can use `make sqlite` to browse the contents of the temporary
SQLite database.


## Override

- You can set `LIGHTSPEED_STACK_IMAGE_OVERRIDE` in `.env` to your own lightspeed-stack image (e.g. `quay.io/lightspeed-core/lightspeed-stack:latest`) to replace the locally built one used in the pod

## Kubernetes-based local workflow (experimental)

You can alternatively run the stack on any Kubernetes/OpenShift cluster you provide (minikube, kind, real OCP). We recommend using `oc` as the CLI. You are responsible for creating and logging into the cluster.

Prerequisites:
- A logged-in cluster: `oc whoami` should succeed
- Vertex credentials file path exported as `VERTEX_SERVICE_ACCOUNT_PATH=/absolute/path/to/service_account.json`
- Optional: override lightspeed-stack image for the main app via `ASSISTED_CHAT_IMG=quay.io/...:tag` (defaults to latest public image)
- For local UI/MCP/inspector components, build images first: `make build-images` (or `make build-ui`, `make build-assisted-mcp`, `make build-inspector`)
- OCM token for UI authentication:
  - Local: `ocm login --use-auth-code` (the scripts will pick up tokens via the `ocm` CLI)
  - CI-compatible: set environment variables `OCM_TOKEN` (required) and optionally `OCM_REFRESH_TOKEN` before running
  - Or provide SSO client credentials in environment/secret and the scripts will mint an access token

Quick start:
```bash
# 1) (Optional) Build local images for UI/MCP/inspector
make build-images

# Load images (only when using minikube)
# make load-images

# 2) Ensure OCM auth (for UI):
# Local: this opens a browser flow to authenticate
ocm login --use-auth-code

# 3) Deploy base app + local components to the current cluster namespace `assisted-chat`
export VERTEX_SERVICE_ACCOUNT_PATH=/abs/path/to/service_account.json \
export ASSISTED_CHAT_IMG=localhost/local-ai-chat-lightspeed-stack-plus-llama-stack:latest \
make run-k8s

# Non-interactive checks
# - Stream logs: make logs-k8s
# - One-shot query via curl with retries/port-forward: make query-k8s-curl
# - Evaluation suite (port-forward handled): make test-eval-k8s

# 4) Interactive query
make query-k8s

# 4) Tear down
make stop-k8s
make rm-k8s
```
Notes:
- We deploy into the `assisted-chat` namespace and create secrets/config automatically. You can change namespace by setting `NAMESPACE=my-namespace` in the environment.
- On clusters without Routes (e.g., minikube), Route objects are filtered automatically.
- Local components use images tagged as `localhost/local-ai-chat-...:latest`. You can override via env vars: `UI_IMAGE`, `ASSISTED_MCP_IMAGE`, `INSPECTOR_IMAGE`.
