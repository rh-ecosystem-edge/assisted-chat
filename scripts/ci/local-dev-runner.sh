#!/usr/bin/env bash
set -euxo pipefail

echo "[RUNNER] starting local-dev-runner; pwd=$(pwd)"
# Keep pod alive for debug; remove /tmp/semaphor to continue
#SEMAPHOR_FILE="/tmp/semaphor"
#touch "$SEMAPHOR_FILE"
#echo "Waiting for semaphor file to be removed: $SEMAPHOR_FILE"
#while [ -f "$SEMAPHOR_FILE" ]; do sleep 5; done

export PROJECT_ROOT="/workspace"

echo "[ENV] PROJECT_ROOT=$PROJECT_ROOT"
# Writable scratch/bin locations
export TMP_ROOT="/tmp/assisted-chat"
export TMP_BIN="${TMP_ROOT}/bin"
export VENV_DIR="${TMP_ROOT}/venv"
mkdir -p "${TMP_BIN}" "${VENV_DIR}" || true
export PATH="${TMP_BIN}:/usr/local/bin:${PATH}"
echo "[ENV] TMP_ROOT=$TMP_ROOT VENV_DIR=$VENV_DIR PATH=$PATH"

# In-cluster privileged pod: we can use podman rootful, but keep flags harmless locally
export NESTED_PODMAN="${NESTED_PODMAN:-}"
if [[ "${NESTED_PODMAN}" == "1" ]]; then
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/run}"; mkdir -p "${XDG_RUNTIME_DIR}" || true
  export BUILDAH_ISOLATION="${BUILDAH_ISOLATION:-chroot}"
fi
echo "[ENV] NESTED_PODMAN=${NESTED_PODMAN:-0} XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-} BUILDAH_ISOLATION=${BUILDAH_ISOLATION:-}"

# Python venv
PY_BIN="python3.11"
command -v "$PY_BIN" >/dev/null 2>&1 || PY_BIN="python3"
echo "[PY] creating venv with interpreter: $PY_BIN"
"$PY_BIN" -m venv "${VENV_DIR}" || true
. "${VENV_DIR}/bin/activate" || true
python -V || true
echo "[PY] upgrading pip and installing eval deps"
pip install --no-cache-dir --upgrade pip || true
pip install --no-cache-dir git+https://github.com/lightspeed-core/lightspeed-evaluation.git#subdirectory=lsc_agent_eval || true

echo "[OCM] attempting client-credentials login; listing /var/run/secrets/sso-ci"
ls -l /var/run/secrets/sso-ci || true
# OCM client-credentials login (token mount supported via secrets)
LOGIN_OK=0
CID_FILE=$(ls -1 /var/run/secrets/sso-ci/*id* 2>/dev/null | head -n1 || true)
CSEC_FILE=$(ls -1 /var/run/secrets/sso-ci/*secret* 2>/dev/null | head -n1 || true)
[ -z "$CID_FILE" ] && CID_FILE=$(ls -1 /var/run/secrets/sso-ci/*client*id* 2>/dev/null | head -n1 || true)
[ -z "$CSEC_FILE" ] && CSEC_FILE=$(ls -1 /var/run/secrets/sso-ci/*client*secret* 2>/dev/null | head -n1 || true)
if [ -n "$CID_FILE" ] && [ -n "$CSEC_FILE" ]; then
  CLIENT_ID=$(cat "$CID_FILE" 2>/dev/null || true)
  CLIENT_SECRET=$(cat "$CSEC_FILE" 2>/dev/null || true)
  ocm login --client-id "$CLIENT_ID" --client-secret "$CLIENT_SECRET" --url https://api.openshift.com && LOGIN_OK=1 || \
  ocm login --client-id "$CLIENT_ID" --client-secret "$CLIENT_SECRET" --url https://api.stage.openshift.com && LOGIN_OK=1 || true
else
  echo "[OCM] client-credentials files not found; skipping login"
fi
[ "$LOGIN_OK" -eq 1 ] && { echo "[OCM] login OK"; ocm whoami || true; } || echo "[OCM] login not established"
OCM_TOKEN_VAL="$(ocm token 2>/dev/null || true)" || true
[ -n "$OCM_TOKEN_VAL" ] && { export OCM_TOKEN="$OCM_TOKEN_VAL"; echo "[OCM] access token acquired (len=${#OCM_TOKEN_VAL})"; } || echo "[OCM] no access token"

echo "[ENV] uid=$(id -u) gid=$(id -g) cwd=$(pwd) PROJECT_ROOT=${PROJECT_ROOT} PATH=${PATH}"

# Ensure writable workspace
WORK_DIR="${PROJECT_ROOT}"
echo "[SRC] checking writability of $WORK_DIR"
if ! ( [ -w "$WORK_DIR" ] && touch "$WORK_DIR/.writable_check" >/dev/null 2>&1 ); then
  rm -f "$WORK_DIR/.writable_check" 2>/dev/null || true
  echo "[SRC] Current dir not writable; preparing /tmp/work"
  rm -rf /tmp/work && mkdir -p /tmp/work
  if [ -d "$PROJECT_ROOT/.git" ]; then
    ( cd "$PROJECT_ROOT" && tar cf - . ) | ( cd /tmp/work && tar xf - )
  fi
  WORK_DIR="/tmp/work"
fi
echo "[SRC] using WORK_DIR=$WORK_DIR"
cd "$WORK_DIR" || exit 1

# Submodules via HTTPS
echo "[SUBMODULE] syncing and updating submodules"
git config --global url."https://github.com/".insteadOf git@github.com:
git submodule sync --recursive || true
git submodule update --init --recursive || true

# .env and credentials
echo "[ENV] preparing .env and vertex credentials"
if [ -f .env.template ] && [ ! -f .env ]; then cp .env.template .env 2>/dev/null || printf '' > .env; fi
if [ -d /var/run/secrets/gemini ]; then 
  GEMINI_VAL="$(cat "/var/run/secrets/gemini/api_key")"
  if grep -q '^GEMINI_API_KEY=' .env 2>/dev/null; then sed -i "s/^GEMINI_API_KEY=.*/GEMINI_API_KEY=${GEMINI_VAL//\//\\/}/" .env; else echo "GEMINI_API_KEY=${GEMINI_VAL}" >> .env; fi;
fi
mkdir -p config
if [ -f /var/run/secrets/vertex/service_account ]; then
  cp -f /var/run/secrets/vertex/service_account config/vertex-credentials.json 2>/dev/null || printf '{}' > config/vertex-credentials.json;
else
  printf '{}' > config/vertex-credentials.json;
fi

# Generate and build
echo "[BUILD] make generate"
make generate
echo "[BUILD] make build-images (best-effort)"
make build-images || true

# Run services and eval
echo "[RUN] starting services"
make run &
sleep 15
BASE_URL="http://localhost:8090"
echo "[HEALTH] GET ${BASE_URL}/v1/models (with auth if available)"
if [ -n "${OCM_TOKEN:-}" ]; then curl -v --max-time 10 -H "Authorization: Bearer ${OCM_TOKEN}" "${BASE_URL}/v1/models" >/dev/null || true; fi
echo "[EVAL] running test-eval"
make test-eval || true
echo "[RUN] stopping services"
make stop || true 