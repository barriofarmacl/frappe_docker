#!/usr/bin/env bash
# Engram CLI for the devcontainer. SQLite lives on the named volume engram-data.
# Cloud replication is opt-in via ENGRAM_CLOUD_* (see devcontainer-example/engram-cloud.env.example).
# JSON backup import is manual (scripts/restore-engram-backup.sh); default ENGRAM_RESTORE=never.
set -euo pipefail

ENGRAM_DATA_DIR="${ENGRAM_DATA_DIR:-/home/frappe/.engram}"
ENGRAM_PROJECT="${ENGRAM_PROJECT:-barriofarma}"
ENGRAM_VERSION="${ENGRAM_VERSION:-1.20.0}"
# auto: import backup only when DB missing or empty; never: skip; always: force import
# Shared host mount (devcontainer): default never — set ENGRAM_RESTORE=auto|always only for empty/local DBs.
ENGRAM_RESTORE="${ENGRAM_RESTORE:-never}"
ENGRAM_BACKUP="${ENGRAM_BACKUP:-/workspace/development/barriofarma-engram-backup.json}"
ENGRAM_BIN_DIR="${HOME}/.local/bin"
ENGRAM_MCP_CWD="${ENGRAM_MCP_CWD:-/workspace/development}"
CURSOR_MCP_JSON="${CURSOR_MCP_JSON:-${HOME}/.cursor/mcp.json}"

log() {
  printf '[setup-engram] %s\n' "$*"
}

install_engram_binary() {
  if command -v engram >/dev/null 2>&1; then
    log "engram already installed: $(command -v engram)"
    return 0
  fi

  log "installing engram v${ENGRAM_VERSION} to ${ENGRAM_BIN_DIR}"
  mkdir -p "${ENGRAM_BIN_DIR}"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  curl -fsSL \
    "https://github.com/Gentleman-Programming/engram/releases/download/v${ENGRAM_VERSION}/engram_${ENGRAM_VERSION}_linux_amd64.tar.gz" \
    | tar xz -C "${tmp_dir}" engram

  install -m 0755 "${tmp_dir}/engram" "${ENGRAM_BIN_DIR}/engram"
  log "installed $(engram --version 2>/dev/null || "${ENGRAM_BIN_DIR}/engram" --version 2>/dev/null || echo engram)"
}

ensure_path() {
  export PATH="${ENGRAM_BIN_DIR}:${PATH}"
  if [ -f "${HOME}/.bashrc" ] && ! grep -qF '$HOME/.local/bin' "${HOME}/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
  fi
}

observation_count() {
  engram stats 2>/dev/null | awk '/Observations:/ {print $2; exit}' || echo 0
}

should_import_backup() {
  case "${ENGRAM_RESTORE}" in
    never)
      return 1
      ;;
    always)
      return 0
      ;;
    auto)
      if [ ! -f "${ENGRAM_DATA_DIR}/engram.db" ]; then
        return 0
      fi
      local count
      count="$(observation_count)"
      if [ "${count:-0}" -eq 0 ] 2>/dev/null; then
        return 0
      fi
      return 1
      ;;
    *)
      log "unknown ENGRAM_RESTORE=${ENGRAM_RESTORE}; expected auto|never|always"
      return 1
      ;;
  esac
}

import_backup_if_needed() {
  if ! should_import_backup; then
    log "skip import (ENGRAM_RESTORE=${ENGRAM_RESTORE}, db=${ENGRAM_DATA_DIR}/engram.db)"
    engram stats 2>/dev/null || true
    return 0
  fi

  if [ ! -f "${ENGRAM_BACKUP}" ]; then
    log "backup not found: ${ENGRAM_BACKUP} (skip import)"
    return 0
  fi

  log "importing Engram backup from ${ENGRAM_BACKUP}"
  engram import "${ENGRAM_BACKUP}"
  log "import complete; active project for MCP: ${ENGRAM_PROJECT}"
  engram stats 2>/dev/null || true
}

write_cursor_mcp_config() {
  local engram_bin="${ENGRAM_BIN_DIR}/engram"
  if [ ! -x "${engram_bin}" ] && command -v engram >/dev/null 2>&1; then
    engram_bin="$(command -v engram)"
  fi

  mkdir -p "$(dirname "${CURSOR_MCP_JSON}")"

  local cloud_env=""
  if [ -n "${ENGRAM_CLOUD_SERVER:-}" ]; then
    cloud_env="${cloud_env}
        \"ENGRAM_CLOUD_SERVER\": \"${ENGRAM_CLOUD_SERVER}\","
  fi
  if [ -n "${ENGRAM_CLOUD_TOKEN:-}" ]; then
    cloud_env="${cloud_env}
        \"ENGRAM_CLOUD_TOKEN\": \"${ENGRAM_CLOUD_TOKEN}\","
  fi
  if [ "${ENGRAM_CLOUD_AUTOSYNC:-}" = "1" ]; then
    cloud_env="${cloud_env}
        \"ENGRAM_CLOUD_AUTOSYNC\": \"1\","
  fi

  log "writing Cursor MCP config: ${CURSOR_MCP_JSON}"
  cat > "${CURSOR_MCP_JSON}" <<EOF
{
  "mcpServers": {
    "engram": {
      "command": "${engram_bin}",
      "args": ["mcp", "--tools=agent"],
      "cwd": "${ENGRAM_MCP_CWD}",
      "env": {${cloud_env}
        "ENGRAM_DATA_DIR": "${ENGRAM_DATA_DIR}",
        "ENGRAM_PROJECT": "${ENGRAM_PROJECT}"
      }
    }
  }
}
EOF
  chmod 600 "${CURSOR_MCP_JSON}" 2>/dev/null || true
  log "Cursor MCP engram -> ${engram_bin} (reload MCP in IDE after rebuild)"
}

main() {
  mkdir -p "${ENGRAM_DATA_DIR}"
  export ENGRAM_DATA_DIR ENGRAM_PROJECT

  install_engram_binary
  ensure_path

  log "ENGRAM_DATA_DIR=${ENGRAM_DATA_DIR}"
  log "ENGRAM_PROJECT=${ENGRAM_PROJECT}"
  log "Container SQLite is independent from the host. Share memory with Engram Cloud, not a bind mount."

  write_cursor_mcp_config
  import_backup_if_needed
}

main "$@"
