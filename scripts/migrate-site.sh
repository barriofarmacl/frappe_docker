#!/bin/bash
set -e

# Configuración
NAMESPACE="barriofarma"
SITE_NAME="${1:-frontend}"  # Nombre del sitio por defecto o pasado como argumento

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Ejecutando Migración de Bench"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Namespace: $NAMESPACE"
echo "Sitio:     $SITE_NAME"
echo ""

# Obtener el pod del backend
echo "🔍 Buscando pod del backend..."
BACKEND_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=backend \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$BACKEND_POD" ]; then
  echo "❌ Error: No se encontró ningún pod del backend en el namespace $NAMESPACE"
  exit 1
fi

echo "✅ Pod encontrado: $BACKEND_POD"
echo ""

# Ejecutar migrate
echo "🚀 Ejecutando bench migrate para el sitio '$SITE_NAME'..."
echo "   Esto puede tomar varios minutos..."
echo ""

kubectl exec -n $NAMESPACE $BACKEND_POD -- bench --site $SITE_NAME migrate

echo ""
echo "✅ Migración completada exitosamente"
echo ""
echo "💡 Los DocTypes de barriofarma_app ahora deberían estar disponibles en el sitio '$SITE_NAME'"
echo ""
echo "📋 Para verificar, puedes:"
echo "   1. Acceder a https://uat.barriofarma.cl"
echo "   2. Ir a Lista de DocTypes y buscar tus DocTypes custom"
echo "   3. O ejecutar: kubectl exec -n $NAMESPACE $BACKEND_POD -- bench --site $SITE_NAME list-doctypes"

