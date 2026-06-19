#!/usr/bin/env bash
# Re-seed Engram SQLite from the versioned JSON backup (idempotent via sync_id).
set -euo pipefail

export ENGRAM_RESTORE=always
export ENGRAM_DATA_DIR="${ENGRAM_DATA_DIR:-/home/frappe/.engram}"
export ENGRAM_PROJECT="${ENGRAM_PROJECT:-barriofarmacl}"
export ENGRAM_BACKUP="${ENGRAM_BACKUP:-/workspace/development/barriofarma-engram-backup.json}"

exec bash /workspace/scripts/setup-engram-devcontainer.sh
