#!/usr/bin/env bash
# Aplica NoSchedule en el nodo donde solo debe correr Redis (pool UAT de 2+ nodos).
# Los StatefulSets redis-cache / redis-queue del overlay UAT toleran este taint.
# Los Deployments con PVC RWO (sites/logs) no lo toleran y quedan en el otro nodo.
#
# Uso (tras kubectl get nodes y ver donde estan redis-cache-0 / redis-queue-0):
#   ./scripts/uat-taint-redis-node.sh gke-PROJECT-ZONE-NODENAME
#
set -euo pipefail
NODE="${1:?Indique el nombre del nodo GKE (ej. gke-barriofarma-uat-default-pool-XXXX-0801)}"
kubectl taint node "${NODE}" "barriofarma.uat/redis-only=true:NoSchedule" --overwrite
echo "OK: nodo ${NODE} con taint barriofarma.uat/redis-only=true:NoSchedule"
echo "Aplicar overlay UAT (toleracion en Redis STS) y borrar pods mal ubicados si aplica."
