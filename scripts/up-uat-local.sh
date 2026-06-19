#!/usr/bin/env bash
# POC UAT 0.0.7-uat en WSL (local). No usar "docker --env-file" (invalido).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

COMPOSE=(docker compose)
if ! docker compose version &>/dev/null; then
  COMPOSE=(docker-compose)
fi

ENV_FILE="${ENV_FILE:-.env.uat-local}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Falta ${ENV_FILE} en ${ROOT}" >&2
  exit 1
fi

# Sin dev-ports.yml: devcontainer usa 8080/3307; .env.uat-local usa 18080/13307 (uat-vps.yml).
"${COMPOSE[@]}" --env-file "${ENV_FILE}" \
  -f docker-compose.barriofarma.yml \
  -f docker-compose.uat-vps.yml \
  -f docker-compose.uat-local.yml \
  "$@"
