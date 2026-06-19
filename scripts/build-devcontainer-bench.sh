#!/usr/bin/env bash
# Build imagen bench del devcontainer (Python 3.11 default + 3.14 v16, Node 20 + 24).
# whiteboard #62 / openspec erpnext-v16-platform-upgrade
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="${ROOT}/images/bench/Dockerfile"
IMAGE="${IMAGE:-barriofarma-bench:dev-py314-node24}"

cd "${ROOT}"

echo "Build devcontainer bench: ${IMAGE}"
echo "Dockerfile: ${DOCKERFILE}"
echo ""

docker build \
  --pull \
  --target bench-test \
  --tag "${IMAGE}" \
  --file "${DOCKERFILE}" \
  .

echo ""
echo "OK: ${IMAGE}"
echo ""
echo "Rebuild devcontainer en VS Code/Cursor:"
echo "  Dev Containers: Rebuild Container"
echo ""
echo "Verificar dentro del contenedor (defaults v15):"
echo "  python --version    # 3.11.x"
echo "  node --version      # v20.x"
echo "  PYENV_VERSION=3.14.0 python --version"
echo "  bash -lc 'nvm use 24 && node --version'"
