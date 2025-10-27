#!/bin/bash

set -euo pipefail

python3.12 migrate.py
if [[ ! -f /app-root/llama_stack_vector_db/vector_db_id.txt ]]; then
    echo "Vector database ID not found. Exiting."
    exit 1
fi

export PROVIDER_VECTOR_DB_ID=$(cat /app-root/llama_stack_vector_db/vector_db_id.txt)

python3.12 src/lightspeed_stack.py