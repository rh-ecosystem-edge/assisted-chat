# Assisted Chat

This repo builds the images for and runs in a podman pod the following services:
- [ ] llama-stack (Unsupported for now, set `LLAMA_STACK_URL` in .env to use external)
- [x] assisted-service-mcp
- [x] lightspeed-core
- [x] inspector

# Pre-requisites

## Dependencies

`dnf install jq fzf`

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

`./logs.sh` - Follow the logs of the podman pod

`./stop.sh` - Stops the podman pod 

# TODO

- [ ] Add llama-stack support
- [ ] Automatically connect Inspector to the MCP

