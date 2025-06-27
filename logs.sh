#!/bin/bash

set -euo pipefail

podman pod logs assisted-chat-pod --follow --names --since 0
