#!/usr/bin/env bash
# Escribe metricas de frescura de backup GCS para node_exporter textfile collector.
# Ejecutar via cron cada hora en la VM (Ansible role observability).

set -euo pipefail

GCS_BUCKET="${BACKUP_GCS_BUCKET:-}"
TEXTFILE_DIR="${TEXTFILE_DIR:-/opt/barriofarma-uat/observability/node-exporter/textfile}"
METRIC_FILE="${TEXTFILE_DIR}/backup_freshness.prom"

if [[ -z "${GCS_BUCKET}" ]]; then
  echo "BACKUP_GCS_BUCKET no definido" >&2
  exit 1
fi

mkdir -p "${TEXTFILE_DIR}"

LATEST_EPOCH=0
while IFS= read -r line; do
  # gsutil ls -l devuelve: SIZE  TIMESTAMP  gs://bucket/path
  ts=$(echo "${line}" | awk '{print $2}')
  if [[ -n "${ts}" && "${ts}" != "TOTAL:" ]]; then
    epoch=$(date -d "${ts}" +%s 2>/dev/null || echo 0)
    if [[ "${epoch}" -gt "${LATEST_EPOCH}" ]]; then
      LATEST_EPOCH="${epoch}"
    fi
  fi
done < <(gsutil ls -l "gs://${GCS_BUCKET}/mariadb/prod/**" 2>/dev/null | tail -n +2 || true)

NOW=$(date +%s)
if [[ "${LATEST_EPOCH}" -eq 0 ]]; then
  AGE=$((NOW))
else
  AGE=$((NOW - LATEST_EPOCH))
fi

TMP="${METRIC_FILE}.$$"
cat > "${TMP}" <<EOF
# HELP backup_last_success_epoch Unix epoch del ultimo objeto de backup en GCS
# TYPE backup_last_success_epoch gauge
backup_last_success_epoch ${LATEST_EPOCH}
# HELP backup_last_success_age_seconds Segundos desde el ultimo backup detectado
# TYPE backup_last_success_age_seconds gauge
backup_last_success_age_seconds ${AGE}
EOF
mv "${TMP}" "${METRIC_FILE}"
chmod 644 "${METRIC_FILE}"
