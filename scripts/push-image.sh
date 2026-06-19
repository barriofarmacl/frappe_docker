#!/bin/bash
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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 Subiendo Imagen Docker al Registry"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Proyecto:    $PROJECT_ID"
echo "Imagen:      $IMAGE_NAME"
echo "Tag:         $IMAGE_TAG"
echo "Registry:    $REGISTRY"
echo "Imagen Full: $FULL_IMAGE_NAME"
echo ""

# Verificar que la imagen local existe
echo "🔍 Verificando imagen local: $LOCAL_IMAGE_NAME"
if ! docker image inspect "$LOCAL_IMAGE_NAME" &>/dev/null; then
  echo "❌ Error: La imagen local '$LOCAL_IMAGE_NAME' no existe."
  echo ""
  echo "💡 Para construir la imagen, ejecuta:"
  echo "   cd $ROOT_DIR"
  echo "   docker build -f images/barriofarma/dev/Containerfile -t $LOCAL_IMAGE_NAME ."
  exit 1
fi

echo "✅ Imagen local encontrada"
echo ""

# Autenticar con GCR
echo "🔐 Autenticando con Google Container Registry..."
gcloud auth configure-docker --quiet

# Verificar si la imagen ya existe en el registry
echo "🔍 Verificando si la imagen ya existe en el registry..."
IMAGE_EXISTS=false
if gcloud container images describe "$FULL_IMAGE_NAME" &>/dev/null; then
  IMAGE_EXISTS=true
  echo "⚠️  La imagen $FULL_IMAGE_NAME ya existe en el registry"
  echo "🗑️  Eliminando imagen existente..."
  
  # Eliminar el tag específico
  gcloud container images delete "$FULL_IMAGE_NAME" --quiet --force-delete-tags || {
    echo "⚠️  No se pudo eliminar el tag específico, intentando eliminar por digest..."
    # Si falla, intentar obtener el digest y eliminar por digest
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
  echo ""
else
  echo "✅ La imagen no existe en el registry (primera vez)"
  echo ""
fi

# Taggear la imagen para GCR
echo "🏷️  Taggeando imagen para GCR..."
docker tag "$LOCAL_IMAGE_NAME" "$FULL_IMAGE_NAME"

# Subir la imagen
echo "📤 Subiendo imagen nueva a $REGISTRY..."
docker push "$FULL_IMAGE_NAME"

echo ""
echo "✅ Imagen subida exitosamente: $FULL_IMAGE_NAME"
echo ""
echo "📋 Para usar esta imagen en K8s, asegúrate de que los manifests usen:"
echo "   image: $FULL_IMAGE_NAME"
echo ""
echo "💡 Comando para verificar en GCR:"
echo "   gcloud container images list-tags ${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}"

