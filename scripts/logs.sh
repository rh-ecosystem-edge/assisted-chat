#!/bin/bash

set -euo pipefail

podman pod logs --follow --names --since 0 --color assisted-chat-pod
