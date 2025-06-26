#!/bin/bash

set -euo pipefail

podman pod logs assisted-chat-pod -f
