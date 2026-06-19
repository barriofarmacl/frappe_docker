#!/bin/bash
# ============================================================================
# Script para Reconstruir y Subir Imagen Docker a GCR
# ============================================================================
# Reconstruye la imagen bf-app-dev y la sube a Google Container Registry
# ============================================================================

set -e

# Configuración
PROJECT_ID="barriofarma-dev"
IMAGE_NAME="bf-app-dev"
IMAGE_TAG="${1:-0.0.2-dev}"  # Tag por defecto o pasado como argumento
REGISTRY="gcr.io"
FULL_IMAGE_NAME="${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"
LOCAL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINERFILE="${ROOT_DIR}/images/barriofarma/dev/Containerfile"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 Reconstruir y Subir Imagen Docker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Proyecto:    $PROJECT_ID"
echo "Imagen:      $IMAGE_NAME"
echo "Tag:         $IMAGE_TAG"
echo "Registry:    $REGISTRY"
echo "Imagen Full: $FULL_IMAGE_NAME"
echo ""

# Verificar que el Containerfile existe
if [ ! -f "$CONTAINERFILE" ]; then
  echo "❌ Error: No se encontró el Containerfile en: $CONTAINERFILE"
  exit 1
fi

# Verificar que apps.json existe
APPS_JSON="${ROOT_DIR}/apps.json"
if [ ! -f "$APPS_JSON" ]; then
  echo "⚠️  Advertencia: No se encontró apps.json en: $APPS_JSON"
  echo "💡 Creando apps.json desde ejemplo..."
  if [ -f "${ROOT_DIR}/development/apps-erp-barriofarma.json" ]; then
    cp "${ROOT_DIR}/development/apps-erp-barriofarma.json" "$APPS_JSON"
    echo "✅ apps.json creado desde ejemplo"
  else
    echo "❌ Error: No se encontró apps-erp-barriofarma.json para crear apps.json"
    exit 1
  fi
fi

# Verificar que estamos en el directorio correcto
cd "$ROOT_DIR"

# Preparar APPS_JSON_BASE64
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Preparando APPS_JSON_BASE64..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
APPS_JSON_BASE64=$(base64 -w 0 "$APPS_JSON" 2>/dev/null || base64 "$APPS_JSON" | tr -d '\n')
if [ -z "$APPS_JSON_BASE64" ]; then
  echo "❌ Error: No se pudo codificar apps-erp-barriofarma.json en base64"
  exit 1
fi
echo "✅ apps-erp-barriofarma.json codificado en base64"
echo ""

# Paso 1: Construir la imagen
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 Paso 1: Construyendo imagen Docker..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Containerfile: $CONTAINERFILE"
echo "Tag local:     $LOCAL_IMAGE_NAME"
echo "apps.json:     $APPS_JSON"
echo ""

docker build \
  --no-cache \
  --pull \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH=version-15 \
  --build-arg=APPS_JSON_BASE64="$APPS_JSON_BASE64" \
  --tag="$LOCAL_IMAGE_NAME" \
  --file="$CONTAINERFILE" \
  .

if [ $? -ne 0 ]; then
  echo "❌ Error: Falló la construcción de la imagen"
  exit 1
fi

echo ""
echo "✅ Imagen construida exitosamente: $LOCAL_IMAGE_NAME"
echo ""

# Paso 2: Autenticar con GCR
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Paso 2: Autenticando con Google Container Registry..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
gcloud auth configure-docker --quiet

if [ $? -ne 0 ]; then
  echo "❌ Error: Falló la autenticación con GCR"
  echo "💡 Asegúrate de tener gcloud configurado y autenticado"
  exit 1
fi

echo "✅ Autenticación exitosa"
echo ""

# Paso 3: Verificar si la imagen ya existe en GCR
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Paso 3: Verificando imagen existente en GCR..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
IMAGE_EXISTS=false
if gcloud container images describe "$FULL_IMAGE_NAME" &>/dev/null; then
  IMAGE_EXISTS=true
  echo "⚠️  La imagen $FULL_IMAGE_NAME ya existe en el registry"
  echo "🗑️  Eliminando imagen existente..."
  
  # Eliminar el tag específico
  gcloud container images delete "$FULL_IMAGE_NAME" --quiet --force-delete-tags || {
    echo "⚠️  No se pudo eliminar el tag específico, intentando eliminar por digest..."
    DIGEST=$(gcloud container images list-tags "${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}" \
      --filter="tags:$IMAGE_TAG" \
      --format="get(digest)" \
      --limit=1 2>/dev/null | head -n1)
    
    if [ -n "$DIGEST" ]; then
      echo "   Eliminando por digest: $DIGEST"
      gcloud container images delete "${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}@${DIGEST}" --quiet || true
    fi
  }
  
  echo "✅ Imagen anterior eliminada"
else
  echo "✅ La imagen no existe en el registry (primera vez)"
fi
echo ""

# Paso 4: Taggear la imagen para GCR
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏷️  Paso 4: Taggeando imagen para GCR..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker tag "$LOCAL_IMAGE_NAME" "$FULL_IMAGE_NAME"

if [ $? -ne 0 ]; then
  echo "❌ Error: Falló el tag de la imagen"
  exit 1
fi

echo "✅ Imagen taggeada: $FULL_IMAGE_NAME"
echo ""

# Paso 5: Subir la imagen
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 Paso 5: Subiendo imagen a GCR..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker push "$FULL_IMAGE_NAME"

if [ $? -ne 0 ]; then
  echo "❌ Error: Falló el push de la imagen"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ¡Proceso completado exitosamente!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Imagen disponible en:"
echo "   $FULL_IMAGE_NAME"
echo ""
echo "💡 Para usar esta imagen en K8s:"
echo "   kubectl set image deployment/barriofarma-backend backend=$FULL_IMAGE_NAME -n barriofarma"
echo ""
echo "💡 Para verificar en GCR:"
echo "   gcloud container images list-tags ${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}"
echo ""

