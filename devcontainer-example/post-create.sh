#!/usr/bin/env bash
# Devcontainer bootstrap: Engram local (named volume) + optional Engram Cloud + gentle-ai.
# Idempotent. Does not run the gentle-ai TUI (needs a TTY).
set -euo pipefail

log() { echo "[devcontainer post-create] $*"; }

export ENGRAM_DATA_DIR="${ENGRAM_DATA_DIR:-/home/frappe/.engram}"
export ENGRAM_PROJECT="${ENGRAM_PROJECT:-barriofarma}"
export ENGRAM_RESTORE="${ENGRAM_RESTORE:-never}"
export PATH="${HOME}/.local/bin:${PATH}"

mkdir -p "${HOME}/.local/bin" "${HOME}/.cursor"

# Named volume is created as root; the image user must own the SQLite directory.
if [ ! -w "${ENGRAM_DATA_DIR}" ] 2>/dev/null; then
  log "chown ${ENGRAM_DATA_DIR} to $(id -un)"
  sudo chown -R "$(id -u):$(id -g)" "${ENGRAM_DATA_DIR}"
fi
mkdir -p "${ENGRAM_DATA_DIR}"

SCRIPTS="/workspace/scripts"
if [[ ! -d "${SCRIPTS}" ]]; then
  log "error: ${SCRIPTS} not found (expected monorepo mounted at /workspace)"
  exit 1
fi

log "setup Engram CLI + Cursor MCP (project=${ENGRAM_PROJECT})"
bash "${SCRIPTS}/setup-engram-devcontainer.sh"

if [ -n "${ENGRAM_CLOUD_SERVER:-}" ]; then
  log "cloud server configured; enroll ${ENGRAM_PROJECT} (token not logged)"
  engram cloud config --server "${ENGRAM_CLOUD_SERVER}"
  engram cloud enroll "${ENGRAM_PROJECT}" || log "enroll returned non-zero; continuing"
  if [ -n "${ENGRAM_CLOUD_TOKEN:-}" ]; then
    engram sync --cloud --import --project "${ENGRAM_PROJECT}" || log "cloud import failed; local Engram still usable"
  else
    log "ENGRAM_CLOUD_TOKEN empty; skip cloud import"
  fi
else
  log "ENGRAM_CLOUD_SERVER unset; Engram stays local to this container"
fi

log "setup gentle-ai CLI (+ Go if needed)..."
bash "${SCRIPTS}/setup-gentle-ai-devcontainer.sh"

log "versions:"
command -v engram >/dev/null && engram --version 2>/dev/null || log "engram: missing"
command -v gentle-ai >/dev/null && gentle-ai version 2>/dev/null || log "gentle-ai: missing"

log "listo."
log "1) Cursor: Settings -> MCP -> Reload (/home/frappe/.cursor/mcp.json)."
log "2) Engram de este contenedor es una SQLite propia (volumen engram-data), no la del host."
log "3) TTY: gentle-ai  # provision agents/rules if missing."
