#!/bin/bash
# =============================================================================
# Script de Descarga de Certificados SSL para Cloud SQL
# =============================================================================
# Uso: ./scripts/download-cloudsql-certs.sh [INSTANCE_NAME]
#      GCP_PROJECT=barriofarma-dev ./scripts/download-cloudsql-certs.sh barriofarma-hybrid-poc-db
# Prerequisitos:
#   - gcloud CLI instalado y autenticado (en WSL sin navegador: gcloud auth login --no-launch-browser)
#   - Proyecto: gcloud config set project barriofarma-dev
#   - Permisos: roles/cloudsql.admin en el proyecto
#   - Terraform aplicado con Cloud SQL creado
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=============================================="
echo "  Descarga de Certificados SSL - Cloud SQL"
echo "=============================================="

# Determinar nombre de instancia
INSTANCE_NAME="${1}"

# Si no se proporciona, intentar obtener desde Terraform
if [ -z "$INSTANCE_NAME" ]; then
    TERRAFORM_DIR="./terraform/hybrid-poc"
    
    if [ -d "$TERRAFORM_DIR" ] && [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        echo -e "\n${YELLOW}Obteniendo nombre de instancia desde Terraform...${NC}"
        INSTANCE_NAME=$(cd "$TERRAFORM_DIR" && terraform output -raw database_instance_name 2>/dev/null || echo "")
    fi
    
    if [ -z "$INSTANCE_NAME" ]; then
        echo -e "${RED}ERROR: No se pudo determinar el nombre de la instancia${NC}"
        echo ""
        echo "Uso: $0 [INSTANCE_NAME]"
        echo ""
        echo "O ejecutar desde el directorio del proyecto con Terraform aplicado"
        echo "Ejemplo: $0 barriofarma-hybrid-poc-db"
        exit 1
    fi
fi

echo -e "\n${BLUE}Instancia: ${INSTANCE_NAME}${NC}"

# Crear directorio de certificados
CERTS_DIR="./certs"
mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

echo -e "\n${YELLOW}1. Creando certificado de cliente (gcloud sql ssl client-certs)...${NC}"
CERT_NAME="client-cert"

# API actual: create escribe la clave privada en el archivo; luego describe devuelve el cert publico
if ! gcloud sql ssl client-certs create "$CERT_NAME" client-key.pem \
    --instance="$INSTANCE_NAME" \
    --project="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null)}" 2>/dev/null; then
    echo -e "${RED}   ERROR: No se pudo crear el certificado de cliente${NC}"
    echo "   Verificar:"
    echo "   - gcloud autenticado: gcloud auth login (en WSL sin navegador: gcloud auth login --no-launch-browser)"
    echo "   - Proyecto correcto: gcloud config set project barriofarma-dev"
    echo "   - Permisos: roles/cloudsql.admin en el proyecto"
    echo "   - Nombre de instancia: $INSTANCE_NAME"
    exit 1
fi
echo -e "${GREEN}   OK: clave privada en client-key.pem${NC}"

echo -e "\n${YELLOW}2. Obteniendo certificado publico (client-cert.pem)...${NC}"
if ! gcloud sql ssl client-certs describe "$CERT_NAME" \
    --instance="$INSTANCE_NAME" \
    --project="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null)}" \
    --format="value(cert)" > client-cert.pem 2>/dev/null; then
    echo -e "${RED}   ERROR: No se pudo obtener el certificado publico${NC}"
    gcloud sql ssl client-certs delete "$CERT_NAME" --instance="$INSTANCE_NAME" --quiet 2>/dev/null || true
    exit 1
fi
echo -e "${GREEN}   OK: client-cert.pem obtenido${NC}"

echo -e "\n${YELLOW}3. Obteniendo certificado CA del servidor...${NC}"
if gcloud sql instances describe "$INSTANCE_NAME" \
    --project="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null)}" \
    --format="value(serverCaCert.cert)" > server-ca.pem 2>/dev/null; then
    echo -e "${GREEN}   OK: server-ca.pem obtenido${NC}"
else
    echo -e "${RED}   ERROR: No se pudo obtener el certificado CA${NC}"
    exit 1
fi

echo -e "\n${YELLOW}4. Protegiendo archivos...${NC}"
chmod 600 client-key.pem client-cert.pem server-ca.pem
echo -e "${GREEN}   OK: Permisos configurados (600)${NC}"

echo -e "\n${YELLOW}5. Verificando certificados...${NC}"
if [ -f "client-cert.pem" ] && [ -f "client-key.pem" ] && [ -f "server-ca.pem" ]; then
    CERT_SIZE=$(wc -c < client-cert.pem)
    KEY_SIZE=$(wc -c < client-key.pem)
    CA_SIZE=$(wc -c < server-ca.pem)
    
    if [ "$CERT_SIZE" -gt 100 ] && [ "$KEY_SIZE" -gt 100 ] && [ "$CA_SIZE" -gt 100 ]; then
        echo -e "${GREEN}   OK: Todos los certificados tienen contenido valido${NC}"
        echo -e "   - client-cert.pem: ${CERT_SIZE} bytes"
        echo -e "   - client-key.pem: ${KEY_SIZE} bytes"
        echo -e "   - server-ca.pem: ${CA_SIZE} bytes"
    else
        echo -e "${RED}   ERROR: Uno o mas certificados parecen estar vacios${NC}"
        exit 1
    fi
else
    echo -e "${RED}   ERROR: Faltan archivos de certificados${NC}"
    exit 1
fi

echo -e "\n=============================================="
echo -e "${GREEN}  Certificados SSL descargados exitosamente${NC}"
echo "=============================================="
echo ""
echo "Certificados guardados en: $(pwd)"
echo ""
echo "Siguiente paso:"
echo "  ./scripts/test-cloudsql-connection.sh"
echo ""
echo "Nota: El certificado de cliente '$CERT_NAME' ha sido creado en Cloud SQL."
echo "      Para revocarlo: gcloud sql ssl client-certs delete $CERT_NAME --instance=$INSTANCE_NAME"
