#!/usr/bin/env bash
# Build UAT Frappe/ERPNext version-16 (manifest apps-uat-erp16-spike.json o apps-uat.json).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG="${1:-0.0.9-uat-v16}"

export FRAPPE_BRANCH=version-16
export APPS_JSON="${APPS_JSON:-${SCRIPT_DIR}/../apps-uat-v16.json}"
export NO_CACHE="${NO_CACHE:-false}"

exec "${SCRIPT_DIR}/build-uat-image.sh" "$TAG"
