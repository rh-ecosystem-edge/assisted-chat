# Assisted Chat

This repo builds the images for and runs in a podman pod the following services:
- [x] assisted-service-mcp
- [x] lightspeed-core + llama-stack (Same container, built separately)
- [x] assisted UI
- [x] inspector

# Pre-requisites

- **Red Hat Developer Subscription** (required for building container images)
  - Sign up for free at https://developers.redhat.com/register
  - **Both steps are required:**
    1. Login to container registry: `podman login registry.access.redhat.com`
    2. Register your system: `sudo subscription-manager register --username <your-username>`
  - Verify registration: `subscription-manager status`
- the `ocm` command (get it [here](https://console.redhat.com/openshift/token))
- Gemini API key (you will be prompted with instructions)
- An OpenShift pull-secret (https://cloud.redhat.com/openshift/install/pull-secret)
    - Apply it to podman by copying it to ~/.config/containers/auth.json

## Dependencies

`dnf install jq fzf uv`

`pip install yq`

## Submodules

```bash
git submodule init
git submodule update
```


# Usage

`./build-images.sh` - Builds all the images for the various services

`./generate.sh` - Generates the configuration files for the services (for now only lightspeed-stack config). If you didn't populate .env, it will prompt you for the required variables

`./run.sh` - Stops the previous podman pod and starts a fresh one

`./query.sh` - Example chat bot query

`./logs.sh` - Follow the logs of the podman pod

`./stop.sh` - Stops the podman pod 

`./rm.sh` - Removes the podman pod

## Override

- You can set `LIGHTSPEED_STACK_IMAGE_OVERRIDE` in `.env` to your own lightspeed-stack image (e.g. `quay.io/lightspeed-core/lightspeed-stack:latest`) to replace the locally built one used in the pod
