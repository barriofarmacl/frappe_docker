#!/usr/bin/env bash
# Manual re-seed from the versioned JSON backup. Not used by post-create (ENGRAM_RESTORE=never).
set -euo pipefail

export ENGRAM_RESTORE=always
export ENGRAM_DATA_DIR="${ENGRAM_DATA_DIR:-/home/frappe/.engram}"
export ENGRAM_PROJECT="${ENGRAM_PROJECT:-barriofarma}"
export ENGRAM_BACKUP="${ENGRAM_BACKUP:-/workspace/development/barriofarma-engram-backup.json}"

exec bash /workspace/scripts/setup-engram-devcontainer.sh
