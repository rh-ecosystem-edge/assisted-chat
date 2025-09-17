#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

if [ -d /var/run/secrets/vertex ]; then
  export VERTEX_SERVICE_ACCOUNT_PATH=/var/run/secrets/vertex/service_account
fi

ocm login --client-id="${CLIENT_ID}" --client-secret="${CLIENT_SECRET}" --url=https://api.openshift.com
export OCM_TOKEN=$(ocm token)
export OCM_REFRESH_TOKEN=$(ocm token --refresh)

echo "GEMINI_API_KEY=${GEMINI_API_KEY}" > .env

