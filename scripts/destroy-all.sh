#!/bin/bash
set -e

PROJECT_ID="barriofarma-dev"
CLUSTER_NAME="barriofarma-dev"
ZONE="us-central1-a"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================================"
echo "💥 BarrioFarma - Destrucción Completa"
echo "================================================"
echo "⚠️  ADVERTENCIA: Esto eliminará TODA la infraestructura"
echo "   - GKE Cluster"
echo "   - Todos los datos (MariaDB, Redis, Sites)"
echo "   - Load Balancers"
echo "   - Discos persistentes"
echo "   - Recursos de Kubernetes (Deployments, PVCs, etc.)"
echo ""
echo "✅ SE PRESERVA: Bucket GCS de backups"
echo ""

read -p "¿Estás SEGURO? Escribe 'DESTROY' para confirmar: " -r
echo
if [[ ! $REPLY == "DESTROY" ]]; then
  echo "❌ Destrucción cancelada"
  exit 1
fi

echo ""
echo "🔥 Iniciando destrucción..."
echo ""

# Configurar credenciales de kubectl si el cluster existe
if gcloud container clusters describe "$CLUSTER_NAME" --zone="$ZONE" --project="$PROJECT_ID" &>/dev/null; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔑 Configurando credenciales de kubectl..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE" --project="$PROJECT_ID"
  echo ""
fi

# 1. Limpiar recursos de Kubernetes primero
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Limpiando recursos de Kubernetes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if kubectl get namespace barriofarma &>/dev/null; then
  echo "📦 Eliminando recursos en namespace barriofarma..."
  
  # Eliminar Deployments, StatefulSets y Jobs
  kubectl delete deployment --all -n barriofarma --timeout=60s 2>/dev/null || true
  kubectl delete statefulset --all -n barriofarma --timeout=60s 2>/dev/null || true
  kubectl delete job --all -n barriofarma --timeout=30s 2>/dev/null || true
  kubectl delete cronjob --all -n barriofarma --timeout=30s 2>/dev/null || true
  
  # Esperar a que los pods terminen
  echo "⏳ Esperando a que los pods terminen..."
  kubectl wait --for=delete pod --all -n barriofarma --timeout=120s 2>/dev/null || true
  
  # Eliminar PVCs (esto liberará los discos en GCP)
  echo "🗑️  Eliminando PVCs..."
  kubectl delete pvc --all -n barriofarma --timeout=60s 2>/dev/null || true
  
  # Eliminar PVs huérfanos
  echo "🗑️  Eliminando PVs huérfanos..."
  kubectl delete pv --all --timeout=60s 2>/dev/null || true
  
  # Eliminar namespace completo
  echo "🗑️  Eliminando namespace barriofarma..."
  kubectl delete namespace barriofarma --timeout=120s 2>/dev/null || true
  
  echo "✅ Recursos de Kubernetes eliminados"
else
  echo "⚠️  Namespace barriofarma no existe o cluster no accesible"
fi

echo ""

# 2. Verificar y limpiar discos huérfanos en GCP
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  Verificando discos huérfanos en GCP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Listar discos sin usar (sin users) que empiezan con pvc-
ORPHAN_DISKS=$(gcloud compute disks list \
  --project="$PROJECT_ID" \
  --filter="zone:$ZONE AND -users:*" \
  --format="value(name)" 2>/dev/null | grep "^pvc-" || true)

if [ -n "$ORPHAN_DISKS" ]; then
  DISK_COUNT=$(echo "$ORPHAN_DISKS" | wc -l)
  echo "🗑️  Encontrados $DISK_COUNT discos huérfanos"
  
  echo "$ORPHAN_DISKS" | while read disk; do
    echo "   Eliminando: $disk"
    gcloud compute disks delete "$disk" \
      --zone="$ZONE" \
      --project="$PROJECT_ID" \
      --quiet 2>/dev/null || echo "   ⚠️  Error eliminando $disk"
  done
  
  echo "✅ Discos huérfanos eliminados"
else
  echo "✅ No hay discos huérfanos"
fi

echo ""

# 3. Mostrar cuota actual de SSD
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  Cuota de SSD Actual"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TOTAL_SSD=$(gcloud compute disks list \
  --project="$PROJECT_ID" \
  --filter="zone:$ZONE" \
  --format="value(sizeGb)" 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")

echo "Total SSD en uso: ${TOTAL_SSD}GB / 500GB"
echo ""

# 4. Destruir infraestructura con Terraform
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  Destruyendo infraestructura con Terraform"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$ROOT_DIR/terraform"

echo "📋 Terraform plan (destroy)..."
terraform plan -destroy -var-file=terraform.tfvars

echo ""
echo "💥 Terraform destroy..."
terraform destroy -var-file=terraform.tfvars -auto-approve

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Destrucción Completa"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💾 Backups preservados en GCS"
echo "🚀 Para re-desplegar: ./scripts/deploy-all.sh"
echo ""

