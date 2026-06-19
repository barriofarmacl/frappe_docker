#!/bin/bash
# ============================================================================
# Script para Reconstruir y Subir Imagen Docker UAT a GCR
# ============================================================================
# Reconstruye la imagen bf-app-uat y la sube a Google Container Registry
# Usa apps-uat.json (refs congeladas). Override: FRAPPE_BRANCH, APPS_JSON.
# ============================================================================

set -e

PROJECT_ID="barriofarma-uat-cl"
IMAGE_NAME="bf-app-uat"
IMAGE_TAG="${1:-0.0.4-uat}"
REGISTRY="gcr.io"
FULL_IMAGE_NAME="${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"
LOCAL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINERFILE="${ROOT_DIR}/images/barriofarma/dev/Containerfile"
APPS_JSON="${APPS_JSON:-${ROOT_DIR}/apps-uat.json}"

if [ -z "${FRAPPE_BRANCH:-}" ]; then
  if grep -q '"branch"[[:space:]]*:[[:space:]]*"version-16"' "$APPS_JSON" 2>/dev/null; then
    FRAPPE_BRANCH="version-16"
  else
    FRAPPE_BRANCH="version-15"
  fi
fi

if [[ "${FRAPPE_BRANCH}" == version-16* ]]; then
  PYTHON_VERSION="${PYTHON_VERSION:-3.14.0}"
  NODE_VERSION="${NODE_VERSION:-24.12.0}"
else
  PYTHON_VERSION="${PYTHON_VERSION:-3.11.6}"
  NODE_VERSION="${NODE_VERSION:-20.19.2}"
fi

echo "================================================================"
echo "  Reconstruir y Subir Imagen Docker UAT"
echo "================================================================"
echo "Proyecto:    $PROJECT_ID"
echo "Imagen:      $IMAGE_NAME"
echo "Tag:         $IMAGE_TAG"
echo "Registry:    $REGISTRY"
echo "Imagen Full: $FULL_IMAGE_NAME"
echo "Apps JSON:   $APPS_JSON"
echo "Frappe:      $FRAPPE_BRANCH"
echo "Python:      $PYTHON_VERSION"
echo "Node:        $NODE_VERSION"
echo ""

if [ ! -f "$CONTAINERFILE" ]; then
  echo "ERROR: No se encontro el Containerfile en: $CONTAINERFILE"
  exit 1
fi

if [ ! -f "$APPS_JSON" ]; then
  echo "ERROR: No se encontro apps-uat.json en: $APPS_JSON"
  echo "NOTA: Este archivo debe existir con las refs congeladas para UAT."
  exit 1
fi

cd "$ROOT_DIR"

# Preparar APPS_JSON_BASE64
echo "================================================================"
echo "  Preparando APPS_JSON_BASE64 desde apps-uat.json..."
echo "================================================================"
APPS_JSON_BASE64=$(base64 -w 0 "$APPS_JSON" 2>/dev/null || base64 "$APPS_JSON" | tr -d '\n')
if [ -z "$APPS_JSON_BASE64" ]; then
  echo "ERROR: No se pudo codificar apps-uat.json en base64"
  exit 1
fi
echo "OK: apps-uat.json codificado en base64"
echo ""

# Paso 1: Construir la imagen
echo "================================================================"
echo "  Paso 1: Construyendo imagen Docker UAT..."
echo "================================================================"
echo "Containerfile: $CONTAINERFILE"
echo "Tag local:     $LOCAL_IMAGE_NAME"
echo ""

docker build \
  --no-cache \
  --pull \
  --build-arg=PYTHON_VERSION="${PYTHON_VERSION}" \
  --build-arg=NODE_VERSION="${NODE_VERSION}" \
  --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
  --build-arg=FRAPPE_BRANCH="${FRAPPE_BRANCH}" \
  --build-arg=APPS_JSON_BASE64="$APPS_JSON_BASE64" \
  --tag="$LOCAL_IMAGE_NAME" \
  --file="$CONTAINERFILE" \
  .

if [ $? -ne 0 ]; then
  echo "ERROR: Fallo la construccion de la imagen"
  exit 1
fi

echo ""
echo "OK: Imagen construida exitosamente: $LOCAL_IMAGE_NAME"
echo ""

# Paso 2: Autenticar con GCR
echo "================================================================"
echo "  Paso 2: Autenticando con Google Container Registry..."
echo "================================================================"
gcloud auth configure-docker --quiet

if [ $? -ne 0 ]; then
  echo "ERROR: Fallo la autenticacion con GCR"
  echo "NOTA: Asegurate de tener gcloud configurado: gcloud config set project $PROJECT_ID"
  exit 1
fi

echo "OK: Autenticacion exitosa"
echo ""

# Paso 3: Verificar si la imagen ya existe en GCR
echo "================================================================"
echo "  Paso 3: Verificando imagen existente en GCR..."
echo "================================================================"
if gcloud container images describe "$FULL_IMAGE_NAME" &>/dev/null; then
  echo "WARN: La imagen $FULL_IMAGE_NAME ya existe en el registry"
  echo "      Eliminando imagen existente..."

  gcloud container images delete "$FULL_IMAGE_NAME" --quiet --force-delete-tags || {
    echo "WARN: No se pudo eliminar el tag, intentando por digest..."
    DIGEST=$(gcloud container images list-tags "${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}" \
      --filter="tags:$IMAGE_TAG" \
      --format="get(digest)" \
      --limit=1 2>/dev/null | head -n1)

    if [ -n "$DIGEST" ]; then
      echo "      Eliminando por digest: $DIGEST"
      gcloud container images delete "${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}@${DIGEST}" --quiet || true
    fi
  }

  echo "OK: Imagen anterior eliminada"
else
  echo "OK: La imagen no existe en el registry (primera vez)"
fi
echo ""

# Paso 4: Taggear la imagen para GCR
echo "================================================================"
echo "  Paso 4: Taggeando imagen para GCR..."
echo "================================================================"
docker tag "$LOCAL_IMAGE_NAME" "$FULL_IMAGE_NAME"

if [ $? -ne 0 ]; then
  echo "ERROR: Fallo el tag de la imagen"
  exit 1
fi

echo "OK: Imagen taggeada: $FULL_IMAGE_NAME"
echo ""

# Paso 5: Subir la imagen
echo "================================================================"
echo "  Paso 5: Subiendo imagen a GCR..."
echo "================================================================"
docker push "$FULL_IMAGE_NAME"

if [ $? -ne 0 ]; then
  echo "ERROR: Fallo el push de la imagen"
  exit 1
fi

echo ""
echo "================================================================"
echo "  Proceso completado exitosamente"
echo "================================================================"
echo ""
echo "Imagen disponible en:"
echo "  $FULL_IMAGE_NAME"
echo ""
echo "Antes de aplicar: resolver MariaDB en VPS + Redis externos y generar ConfigMap:"
echo "  ./scripts/prepare-uat-external-config.sh   # requiere UAT_DB_HOST, UAT_REDIS_CACHE_HOST, UAT_REDIS_QUEUE_HOST"
echo "Aplicar overlay UAT:"
echo "  ./scripts/apply-k8s-uat.sh"
echo "  # o: kubectl kustomize --load-restrictor=LoadRestrictionsNone \"${ROOT_DIR}/k8s/overlays/uat\" | kubectl apply -f -"
echo ""
echo "Para verificar en GCR:"
echo "  gcloud container images list-tags ${REGISTRY}/${PROJECT_ID}/${IMAGE_NAME}"
echo ""
