#!/usr/bin/env bash
# Build local bf-app-uat image from apps JSON + Frappe branch.
# Uso spike ERPNext 16:
#   FRAPPE_BRANCH=version-16 APPS_JSON=apps-uat-erp16-spike.json ./scripts/build-uat-image.sh 0.0.7-erp16-spike
# Uso release UAT v16 (default apps-uat.json):
#   ./scripts/build-uat-image.sh 0.0.8-uat
# Uso legacy v15:
#   FRAPPE_BRANCH=version-15 APPS_JSON=apps-uat-v15.json ./scripts/build-uat-image.sh 0.0.7-uat
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINERFILE="${ROOT_DIR}/images/barriofarma/dev/Containerfile"

IMAGE_NAME="${IMAGE_NAME:-bf-app-uat}"
IMAGE_TAG="${1:?Falta tag, ej. 0.0.8-uat o 0.0.7-uat}"
APPS_JSON="${APPS_JSON:-${ROOT_DIR}/apps-uat.json}"
LOCAL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
NO_CACHE="${NO_CACHE:-false}"

if [ -z "${FRAPPE_BRANCH:-}" ]; then
  if grep -q '"branch"[[:space:]]*:[[:space:]]*"version-16"' "$APPS_JSON" 2>/dev/null; then
    FRAPPE_BRANCH="version-16"
  else
    FRAPPE_BRANCH="version-15"
  fi
fi

# Frappe v16: requires-python >=3.14,<3.15; CI usa Node 24 (pyproject.toml / setup action).
if [[ "${FRAPPE_BRANCH}" == version-16* ]]; then
  PYTHON_VERSION="${PYTHON_VERSION:-3.14.0}"
  NODE_VERSION="${NODE_VERSION:-24.12.0}"
else
  PYTHON_VERSION="${PYTHON_VERSION:-3.11.6}"
  NODE_VERSION="${NODE_VERSION:-20.19.2}"
fi

if [[ ! -f "$CONTAINERFILE" ]]; then
  echo "ERROR: No se encontro Containerfile: $CONTAINERFILE" >&2
  exit 1
fi

if [[ ! -f "$APPS_JSON" ]]; then
  echo "ERROR: No se encontro apps JSON: $APPS_JSON" >&2
  exit 1
fi

cd "$ROOT_DIR"

echo "================================================================"
echo "  Build imagen UAT (local)"
echo "================================================================"
echo "Tag:           $LOCAL_IMAGE_NAME"
echo "FRAPPE_BRANCH: $FRAPPE_BRANCH"
echo "PYTHON:        $PYTHON_VERSION"
echo "NODE:          $NODE_VERSION"
echo "Apps JSON:     $APPS_JSON"
echo ""

APPS_JSON_BASE64=$(base64 -w 0 "$APPS_JSON" 2>/dev/null || base64 "$APPS_JSON" | tr -d '\n')

BUILD_ARGS=(
  --pull
  --build-arg="PYTHON_VERSION=${PYTHON_VERSION}"
  --build-arg="NODE_VERSION=${NODE_VERSION}"
  --build-arg="FRAPPE_PATH=https://github.com/frappe/frappe"
  --build-arg="FRAPPE_BRANCH=${FRAPPE_BRANCH}"
  --build-arg="APPS_JSON_BASE64=${APPS_JSON_BASE64}"
  --tag="${LOCAL_IMAGE_NAME}"
  --file="${CONTAINERFILE}"
)

if [[ "$NO_CACHE" == "true" ]]; then
  BUILD_ARGS=(--no-cache "${BUILD_ARGS[@]}")
fi

docker build "${BUILD_ARGS[@]}" .

echo ""
echo "OK: ${LOCAL_IMAGE_NAME}"
echo ""
echo "Probar en WSL (ejemplo):"
echo "  docker tag ${LOCAL_IMAGE_NAME} bf-app-uat:${IMAGE_TAG}"
echo "  APP_IMAGE=gcr.io/barriofarma-uat-cl/bf-app-uat:${IMAGE_TAG} \\"
echo "    sed -i 's|^APP_IMAGE=.*|APP_IMAGE=gcr.io/barriofarma-uat-cl/bf-app-uat:${IMAGE_TAG}|' .env.uat-local"
echo "  ./scripts/up-uat-local.sh up -d --force-recreate"
echo ""
echo "Sitio limpio recomendado para spike de major version:"
echo "  ./scripts/up-uat-local.sh down -v && ./scripts/up-uat-local.sh up -d"
