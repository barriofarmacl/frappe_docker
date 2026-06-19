#!/usr/bin/env bash
# Compara hora local (UTC) con referencia pública (America/Santiago).
# Salida 0 si |skew| <= limite; 1 si excede o falla la consulta.
# Uso: ./scripts/check_time_skew_sii.sh [limite_segundos]

set -euo pipefail

LIMIT="${1:-120}"
LOCAL=$(date -u +%s)

if ! command -v curl >/dev/null 2>&1; then
	echo "check_time_skew_sii: instale curl" >&2
	exit 2
fi

JSON=$(curl -sfS --max-time 15 \
	-H "Accept: application/json" \
	"https://worldtimeapi.org/api/timezone/America/Santiago" || true)

if [[ -z "${JSON}" ]]; then
	echo "check_time_skew_sii: no se pudo obtener hora de referencia (red o API)" >&2
	exit 2
fi

REMOTE=$(echo "${JSON}" | python3 -c "import json,sys; print(int(json.load(sys.stdin)[\"unixtime\"]))")
SKEW=$((REMOTE - LOCAL))
ABS=${SKEW#-}

echo "Local UTC unix:   ${LOCAL}"
echo "Santiago (API):   ${REMOTE}"
echo "Skew (ref-local): ${SKEW}s (limite abs ${LIMIT}s)"

if (( ABS > LIMIT )); then
	echo "check_time_skew_sii: desfase alto; sincronice NTP o reinicie WSL/Docker y reintente." >&2
	exit 1
fi

echo "OK: desfase dentro del limite."
exit 0
