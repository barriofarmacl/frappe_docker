#!/bin/bash
# =============================================================================
# Script de Validacion de Conectividad a Cloud SQL
# =============================================================================
# Uso: ./scripts/test-cloudsql-connection.sh
# Prerequisitos:
#   - .env.hybrid configurado con CLOUD_SQL_IP
#   - mysql client instalado (apt install mysql-client)
#   - Certificados SSL en ./certs/ (opcional pero recomendado)
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=============================================="
echo "  Test de Conectividad a Cloud SQL"
echo "=============================================="

# Cargar variables de entorno
ENV_FILE="${1:-.env.hybrid}"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}ERROR: Archivo $ENV_FILE no encontrado${NC}"
    echo "Copia .env.hybrid.example a .env.hybrid y configura las variables"
    exit 1
fi

source "$ENV_FILE"

# Validar variables requeridas
if [ -z "$CLOUD_SQL_IP" ]; then
    echo -e "${RED}ERROR: CLOUD_SQL_IP no definida en $ENV_FILE${NC}"
    exit 1
fi

echo -e "\n${YELLOW}1. Verificando conectividad de red...${NC}"
if ping -c 1 -W 5 "$CLOUD_SQL_IP" > /dev/null 2>&1; then
    echo -e "${GREEN}   OK: Ping a $CLOUD_SQL_IP exitoso${NC}"
else
    echo -e "${YELLOW}   WARN: Ping bloqueado (normal en Cloud SQL)${NC}"
fi

echo -e "\n${YELLOW}2. Verificando puerto 3306...${NC}"
if nc -z -w 5 "$CLOUD_SQL_IP" 3306 2>/dev/null; then
    echo -e "${GREEN}   OK: Puerto 3306 accesible${NC}"
else
    echo -e "${RED}   ERROR: Puerto 3306 no accesible${NC}"
    echo "   Verificar:"
    echo "   - IP correcta: $CLOUD_SQL_IP"
    echo "   - Firewall de Cloud SQL permite tu IP"
    echo "   - Tu IP publica actual: $(curl -s ifconfig.me)"
    exit 1
fi

echo -e "\n${YELLOW}3. Verificando certificados SSL...${NC}"
CERTS_DIR="./certs"
SSL_OPTS=""

if [ -f "$CERTS_DIR/server-ca.pem" ] && [ -f "$CERTS_DIR/client-cert.pem" ] && [ -f "$CERTS_DIR/client-key.pem" ]; then
    echo -e "${GREEN}   OK: Certificados SSL encontrados${NC}"
    SSL_OPTS="--ssl-ca=$CERTS_DIR/server-ca.pem --ssl-cert=$CERTS_DIR/client-cert.pem --ssl-key=$CERTS_DIR/client-key.pem"
else
    echo -e "${YELLOW}   WARN: Certificados SSL no encontrados en $CERTS_DIR/${NC}"
    echo "   La conexion usara SSL pero sin verificacion de certificado cliente"
fi

echo -e "\n${YELLOW}4. Probando conexion MySQL...${NC}"

# Verificar si mysql client esta disponible
if ! command -v mysql &> /dev/null; then
    echo -e "${RED}   ERROR: mysql client no instalado${NC}"
    echo "   Instalar con: apt install mysql-client"
    echo ""
    echo "   Alternativa con Docker:"
    echo "   docker run --rm -it mysql:8 mysql -h $CLOUD_SQL_IP -u ${CLOUD_SQL_USER:-root} -p -e 'SELECT 1'"
    exit 1
fi

# Intentar conexion
DB_USER="${CLOUD_SQL_USER:-root}"
DB_PASS="${CLOUD_SQL_PASSWORD:-bfdb123}"

echo "   Conectando a $CLOUD_SQL_IP como $DB_USER..."

if mysql -h "$CLOUD_SQL_IP" -u "$DB_USER" -p"$DB_PASS" $SSL_OPTS -e "SELECT 1 as test" 2>/dev/null; then
    echo -e "${GREEN}   OK: Conexion MySQL exitosa${NC}"
else
    echo -e "${RED}   ERROR: No se pudo conectar a MySQL${NC}"
    echo "   Verificar credenciales en $ENV_FILE"
    exit 1
fi

echo -e "\n${YELLOW}5. Verificando base de datos...${NC}"
DB_NAME="${CLOUD_SQL_DATABASE:-barriofarma}"

if mysql -h "$CLOUD_SQL_IP" -u "$DB_USER" -p"$DB_PASS" $SSL_OPTS -e "USE $DB_NAME; SELECT 1" 2>/dev/null; then
    echo -e "${GREEN}   OK: Base de datos '$DB_NAME' existe${NC}"
else
    echo -e "${YELLOW}   WARN: Base de datos '$DB_NAME' no existe (se creara al hacer bench new-site)${NC}"
fi

echo -e "\n${YELLOW}6. Verificando latencia...${NC}"
START=$(date +%s%N)
mysql -h "$CLOUD_SQL_IP" -u "$DB_USER" -p"$DB_PASS" $SSL_OPTS -e "SELECT 1" > /dev/null 2>&1
END=$(date +%s%N)
LATENCY=$(( (END - START) / 1000000 ))

echo -e "   Latencia de query simple: ${LATENCY}ms"

if [ "$LATENCY" -lt 100 ]; then
    echo -e "${GREEN}   OK: Latencia excelente (<100ms)${NC}"
elif [ "$LATENCY" -lt 200 ]; then
    echo -e "${YELLOW}   OK: Latencia aceptable (100-200ms)${NC}"
else
    echo -e "${YELLOW}   WARN: Latencia alta (>200ms) - puede afectar rendimiento${NC}"
fi

echo -e "\n=============================================="
echo -e "${GREEN}  Todas las validaciones completadas${NC}"
echo "=============================================="
echo ""
echo "Siguiente paso:"
echo "  docker compose -f docker-compose.hybrid-poc.yml --env-file .env.hybrid up -d"
