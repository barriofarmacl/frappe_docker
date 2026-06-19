#!/usr/bin/env bash
# gentle-ai CLI + Go 1.24+ for devcontainer (TUI manual post-rebuild).
# Provisioning Cursor agents/rules requires: gentle-ai  (interactive TTY).
set -euo pipefail

GENTLE_BIN_DIR="${HOME}/.local/bin"
GO_VERSION="${GO_VERSION:-1.26.1}"
GO_ROOT="${HOME}/sdk/go"
GENTLE_INSTALL_URL="${GENTLE_INSTALL_URL:-https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/scripts/install.sh}"

log() {
  printf '[setup-gentle-ai] %s\n' "$*"
}

go_major_minor() {
  go version 2>/dev/null | awk '{print $3}' | tr -d 'go' | cut -d. -f1,2
}

go_version_ok() {
  local ver major minor
  ver="$(go_major_minor)"
  [ -n "$ver" ] || return 1
  major="${ver%%.*}"
  minor="${ver#*.}"
  [ "${major:-0}" -gt 1 ] && return 0
  [ "${major:-0}" -eq 1 ] && [ "${minor:-0}" -ge 24 ]
}

install_go() {
  if go_version_ok; then
    log "go already OK: $(go version)"
    return 0
  fi

  log "installing Go ${GO_VERSION} to ${GO_ROOT}"
  mkdir -p "${HOME}/sdk"
  tmp_tgz="$(mktemp)"
  trap 'rm -f "${tmp_tgz}"' RETURN

  curl -fsSL -o "${tmp_tgz}" "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
  rm -rf "${GO_ROOT}"
  tar -C "${HOME}/sdk" -xzf "${tmp_tgz}"

  if ! grep -qF 'sdk/go/bin' "${HOME}/.bashrc" 2>/dev/null; then
    cat >> "${HOME}/.bashrc" <<'EOF'

# Go SDK (gentle-ai / engram go install)
export GOROOT="$HOME/sdk/go"
export PATH="$HOME/sdk/go/bin:$PATH"
EOF
  fi

  export GOROOT="${GO_ROOT}"
  export PATH="${GO_ROOT}/bin:${PATH}"
  log "installed $(go version)"
}

ensure_path() {
  export PATH="${GENTLE_BIN_DIR}:${PATH}"
  if [ -f "${HOME}/.bashrc" ] && ! grep -qF '$HOME/.local/bin' "${HOME}/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
  fi
}

install_gentle_ai_binary() {
  ensure_path

  if command -v gentle-ai >/dev/null 2>&1; then
    log "gentle-ai already installed: $(command -v gentle-ai)"
    gentle-ai version 2>/dev/null || true
    return 0
  fi

  if [ -x "${GENTLE_BIN_DIR}/gentle-ai" ]; then
    log "gentle-ai found at ${GENTLE_BIN_DIR}/gentle-ai"
    return 0
  fi

  log "installing gentle-ai binary to ${GENTLE_BIN_DIR}"
  mkdir -p "${GENTLE_BIN_DIR}"

  if ! curl -fsSL "${GENTLE_INSTALL_URL}" | bash -s -- --method binary --dir "${GENTLE_BIN_DIR}"; then
    if [ -x "${GENTLE_BIN_DIR}/gentle-ai" ]; then
      log "install script exited non-zero but binary is present (continuing)"
    else
      log "ERROR: gentle-ai binary install failed"
      return 1
    fi
  fi

  log "installed $(gentle-ai version 2>/dev/null || echo gentle-ai)"
}

main() {
  install_go
  install_gentle_ai_binary
  log "Run 'gentle-ai' in an interactive terminal to provision ~/.cursor agents/rules (requires TTY)."
  log "Engram CLI/MCP: use setup-engram-devcontainer.sh; do not run engram mcp here if MCP runs on WSL host."
}

main "$@"
