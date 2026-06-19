#!/bin/bash
set -e

# Sobrescribir para otros ambientes, por ejemplo UAT:
#   NAMESPACE=barriofarma-uat ./scripts/update-dns.sh
PROJECT_ID="${PROJECT_ID:-barriofarma-dev}"
# Autoridad DNS: barriofarmadigital/barriofarmacl (cluster puede vivir en otro proyecto)
DNS_PROJECT_ID="${DNS_PROJECT_ID:-barriofarmadigital}"
DNS_ZONE="${DNS_ZONE:-barriofarmacl}"
DOMAIN="${DOMAIN:-uat.barriofarma.cl}"
NAMESPACE="${NAMESPACE:-barriofarma}"
INGRESS_NAME="${INGRESS_NAME:-barriofarma-ingress}"

echo "================================================"
echo "BarrioFarma - Actualizar DNS"
echo "================================================"

# Verificar conexión a cluster
if ! kubectl cluster-info &>/dev/null; then
  echo "Error: No hay conexion al cluster"
  exit 1
fi

echo ""
echo "⏳ Esperando que el Ingress obtenga una IP externa..."
for i in {1..30}; do
  INGRESS_IP=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  
  if [ -n "$INGRESS_IP" ]; then
    echo "OK: IP del Ingress detectada: $INGRESS_IP"
    break
  fi
  
  echo "   Esperando... ($i/30)"
  sleep 10
done

if [ -z "$INGRESS_IP" ]; then
  echo "Error: No se pudo obtener la IP del Ingress despues de 5 minutos"
  exit 1
fi

echo ""
echo "Verificando registro DNS actual..."
CURRENT_IP=$(gcloud dns record-sets list --zone=$DNS_ZONE --project="$DNS_PROJECT_ID" \
  --filter="name:${DOMAIN}." --format="get(rrdatas[0])" 2>/dev/null || echo "")

if [ "$CURRENT_IP" == "$INGRESS_IP" ]; then
  echo "OK: DNS ya esta actualizado con la IP correcta: $INGRESS_IP"
  exit 0
fi

echo ""
echo "Actualizando registro DNS..."
echo "   Dominio: $DOMAIN"
echo "   IP anterior: ${CURRENT_IP:-ninguna}"
echo "   IP nueva: $INGRESS_IP"

if [ -z "$CURRENT_IP" ]; then
  # Crear nuevo registro
  gcloud dns record-sets create $DOMAIN \
    --rrdatas=$INGRESS_IP \
    --type=A \
    --ttl=300 \
    --zone=$DNS_ZONE \
    --project="$DNS_PROJECT_ID"
  echo "OK: Registro DNS creado"
else
  # Actualizar registro existente
  gcloud dns record-sets update $DOMAIN \
    --rrdatas=$INGRESS_IP \
    --type=A \
    --ttl=300 \
    --zone=$DNS_ZONE \
    --project="$DNS_PROJECT_ID"
  echo "OK: Registro DNS actualizado"
fi

echo ""
echo "Esperando propagacion DNS (30 segundos)..."
sleep 30

echo ""
echo "Verificando resolucion DNS..."
RESOLVED_IP=$(nslookup $DOMAIN 8.8.8.8 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}' || echo "")

if [ "$RESOLVED_IP" == "$INGRESS_IP" ]; then
  echo "OK: DNS propagado correctamente"
else
  echo "Aviso: DNS aun propagandose (puede tardar varios minutos)"
  echo "   Esperado: $INGRESS_IP"
  echo "   Resuelto: $RESOLVED_IP"
fi

echo ""
echo "Actualizacion DNS completa"
echo "   URL: https://$DOMAIN"

