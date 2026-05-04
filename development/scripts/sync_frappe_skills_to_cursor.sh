#!/usr/bin/env bash
# Sincroniza skills Frappe del repo a ~/.cursor/skills/ (BarrioFarma + Gentle AI).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/.cursor/.agents/skills"
DEST="${HOME}/.cursor/skills"
mkdir -p "${DEST}"
for d in "${SRC}"/*/; do
  name="$(basename "$d")"
  echo "Sync ${name}"
  rm -rf "${DEST}/${name}"
  cp -a "${d}" "${DEST}/${name}"
done
echo "Done. ${DEST}"
