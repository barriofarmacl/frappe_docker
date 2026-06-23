#!/bin/bash
# Build y push imagen PROD v16 (BarrioFarma Platform 1.0.0 train).
# Gate: barriofarma_app __version__ == tag == apps-prod-v16.json == sufijo imagen.
#
# Uso:
#   cd frappe_docker
#   ./scripts/rebuild-and-push-prod-v16.sh 0.0.15-prod-v16
#
# Override manifest:
#   APPS_JSON=./apps-prod-v16.json ./scripts/rebuild-and-push-prod-v16.sh 0.0.15-prod-v16

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TAG="${1:-0.0.15-prod-v16}"
APPS_JSON="${APPS_JSON:-${ROOT_DIR}/apps-prod-v16.json}"

export APPS_JSON
export IMAGE_NAME_OVERRIDE="bf-app-prod"

# Reutiliza build UAT con imagen y manifest prod.
exec "${SCRIPT_DIR}/rebuild-and-push-uat.sh" "$TAG"
