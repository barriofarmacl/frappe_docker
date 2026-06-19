#!/usr/bin/env bash
# Genera k8s/overlays/uat/configmap-external.yaml a partir de variables de entorno.
# Sin este archivo el overlay UAT no compila (no aplica el parche de ConfigMap).
#
# Requeridas (salvo inferencia automatica):
#   UAT_DB_HOST              hostname o IP de MariaDB (VM en VPC / VPS)
#   Si UAT_DB_HOST no esta definida: se intenta `terraform output -raw mariadb_vm_private_ip`
#   en frappe_docker/terraform (state inicializado, modulo MariaDB VM activo).
#
# Redis (por defecto en el mismo namespace que el overlay, StatefulSets redis-cache / redis-queue):
#   Si NO defines UAT_REDIS_CACHE_HOST ni UAT_REDIS_QUEUE_HOST, se usan
#   redis://redis-cache:<puerto> y redis://redis-queue:<puerto> (servicios en cluster).
#   Para Memorystore u otro Redis externo, define ambas variables.
#
# Opcionales:
#   UAT_DB_PORT (default 3306)
#   UAT_DB_NAME (default barriofarma)
#   UAT_REDIS_PORT (default 6379)
#   UAT_REDIS_CACHE_HOST / UAT_REDIS_QUEUE_HOST (solo hosts, sin redis://)
#   UAT_GCS_BUCKET
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUT_FILE="${ROOT_DIR}/k8s/overlays/uat/configmap-external.yaml"

if [[ -z "${UAT_DB_HOST:-}" ]]; then
  TF_DIR="${ROOT_DIR}/terraform"
  MARIA_IP="$(cd "${TF_DIR}" && terraform output -raw mariadb_vm_private_ip 2>/dev/null || true)"
  if [[ -n "${MARIA_IP}" && "${MARIA_IP}" != "null" ]]; then
    UAT_DB_HOST="${MARIA_IP}"
    echo "UAT_DB_HOST inferido desde Terraform (mariadb_vm_private_ip): ${UAT_DB_HOST}"
  fi
fi
: "${UAT_DB_HOST:?Definir UAT_DB_HOST o ejecutar Terraform UAT con enable_mariadb_vm y state accesible (cd frappe_docker/terraform; terraform init)}"

DB_PORT="${UAT_DB_PORT:-3306}"
DB_NAME="${UAT_DB_NAME:-barriofarma}"
REDIS_PORT="${UAT_REDIS_PORT:-6379}"
GCS_BUCKET="${UAT_GCS_BUCKET:-barriofarma-uat-cl-storage}"

if [[ -n "${UAT_REDIS_CACHE_HOST:-}" && -n "${UAT_REDIS_QUEUE_HOST:-}" ]]; then
  FRAPPE_REDIS_CACHE="redis://${UAT_REDIS_CACHE_HOST}:${REDIS_PORT}"
  FRAPPE_REDIS_QUEUE="redis://${UAT_REDIS_QUEUE_HOST}:${REDIS_PORT}"
  REDIS_MODE="externo (${UAT_REDIS_CACHE_HOST} / ${UAT_REDIS_QUEUE_HOST})"
else
  if [[ -n "${UAT_REDIS_CACHE_HOST:-}" || -n "${UAT_REDIS_QUEUE_HOST:-}" ]]; then
    echo "Error: defina ambas UAT_REDIS_CACHE_HOST y UAT_REDIS_QUEUE_HOST, o ninguna para Redis en cluster."
    exit 1
  fi
  FRAPPE_REDIS_CACHE="redis://redis-cache:${REDIS_PORT}"
  FRAPPE_REDIS_QUEUE="redis://redis-queue:${REDIS_PORT}"
  REDIS_MODE="en cluster (redis-cache / redis-queue)"
fi

mkdir -p "$(dirname "$OUT_FILE")"
cat >"$OUT_FILE" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: barriofarma-config
  namespace: barriofarma
data:
  DB_HOST: "${UAT_DB_HOST}"
  DB_PORT: "${DB_PORT}"
  DB_NAME: "${DB_NAME}"
  DB_TYPE: "mariadb"
  FRAPPE_REDIS_CACHE: "${FRAPPE_REDIS_CACHE}"
  FRAPPE_REDIS_QUEUE: "${FRAPPE_REDIS_QUEUE}"
  ENVIRONMENT: "uat"
  OTEL_SERVICE_VERSION: "0.0.2-uat"
  GCS_BUCKET_NAME: "${GCS_BUCKET}"
EOF

echo "OK: escrito ${OUT_FILE}"
echo "    Redis: ${REDIS_MODE}"
echo "Siguiente: revisar Secret (DB_PASSWORD acorde a MariaDB) y ejecutar scripts/apply-k8s-uat.sh"
