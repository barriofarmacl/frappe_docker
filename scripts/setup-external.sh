#!/bin/bash
set -e

echo "================================================"
echo "🚀 BarrioFarma - Setup Componentes Externos"
echo "================================================"

# Verificar conexión a cluster
if ! kubectl cluster-info &>/dev/null; then
  echo "❌ Error: No hay conexión al cluster"
  exit 1
fi

echo ""
echo "📦 [1/4] Instalando NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

echo ""
echo "⏳ [2/4] Esperando NGINX Ingress Controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo ""
echo "🔧 [3/4] Habilitando snippet annotations..."
kubectl patch configmap ingress-nginx-controller \
  -n ingress-nginx \
  --type merge \
  -p '{"data":{"allow-snippet-annotations":"true"}}'

echo ""
echo "♻️  Reiniciando NGINX controller..."
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=300s

echo ""
echo "📜 [4/4] Instalando cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

echo ""
echo "⏳ Esperando cert-manager..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=300s

echo ""
echo "🔐 [5/5] Configurando Let's Encrypt ClusterIssuer..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
kubectl apply -f "$ROOT_DIR/k8s/letsencrypt-prod.yaml"

echo ""
echo "✅ Componentes externos listos"
echo "   - NGINX Ingress Controller: ✓"
echo "   - cert-manager: ✓"
echo "   - Let's Encrypt ClusterIssuer: ✓"

