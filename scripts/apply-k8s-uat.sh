#!/bin/bash
# Aplica el overlay Kustomize UAT al cluster actual (kubectl context).
# Requiere LoadRestrictionsNone porque el overlay referencia YAML bajo k8s/.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OVERLAY="${ROOT_DIR}/k8s/overlays/uat"

if [ ! -d "$OVERLAY" ]; then
  echo "ERROR: No existe overlay: $OVERLAY"
  exit 1
fi

CM_PATCH="${OVERLAY}/configmap-external.yaml"
if [ ! -f "$CM_PATCH" ]; then
  echo "ERROR: Falta ${CM_PATCH}"
  echo "Genera el ConfigMap (MariaDB fuera del cluster; Redis en cluster por defecto):"
  echo "  export UAT_DB_HOST=<ip_o_hostname_mariadb>"
  echo "  ./scripts/prepare-uat-external-config.sh"
  echo "Redis externo (opcional): export UAT_REDIS_CACHE_HOST=... y UAT_REDIS_QUEUE_HOST=... antes del script."
  echo "Alternativa: cp k8s/overlays/uat/configmap-external.example.yaml k8s/overlays/uat/configmap-external.yaml y editar."
  echo "Asegura barriofarma-secrets (DB_PASSWORD) alineado con MariaDB antes de aplicar."
  exit 1
fi

kubectl kustomize --load-restrictor=LoadRestrictionsNone "$OVERLAY" | kubectl apply -f -

echo "Esperando Redis (StatefulSets)..."
kubectl rollout status statefulset/redis-cache -n barriofarma-uat --timeout=180s
kubectl rollout status statefulset/redis-queue -n barriofarma-uat --timeout=180s

echo "Esperando rollout backend (namespace barriofarma-uat)..."
kubectl rollout status deployment/barriofarma-backend -n barriofarma-uat --timeout=300s

echo "Smoke interno (ping desde cluster):"
kubectl run "uat-smoke-ping-$(date +%s)" --image=curlimages/curl --rm -i --restart=Never -n barriofarma-uat -- \
  curl -sfS "http://barriofarma-backend-service:8000/api/method/ping"
