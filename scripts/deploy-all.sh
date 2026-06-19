#!/usr/bin/env bash
# Despliegue end-to-end: Terraform + componentes de cluster + aplicacion.
#
# Uso:
#   ./scripts/deploy-all.sh          # ambiente dev (valores por defecto)
#   ./scripts/deploy-all.sh dev
#   ./scripts/deploy-all.sh uat
#
# UAT - variables obligatorias antes de ejecutar:
#   TF_VAR_mariadb_vm_db_password   # si enable_mariadb_vm=true en environments/uat/terraform.tfvars (min. 10 caracteres)
#
# UAT - Redis: por defecto en cluster (StatefulSets). Opcional para Memorystore u otro Redis externo:
#   UAT_REDIS_CACHE_HOST / UAT_REDIS_QUEUE_HOST (ambas; ver prepare-uat-external-config.sh)
#
# UAT - opcionales:
#   UAT_DB_HOST                       # si no se define, se usa terraform output mariadb_vm_private_ip cuando exista
#   UAT_GCS_BUCKET                    # ver prepare-uat-external-config.sh
#   DNS_PROJECT_ID                    # por defecto: barriofarmadigital (zona barriofarmacl); sobrescribir si aplica
#
# Base de datos en la VM UAT: MariaDB se instala en el primer arranque via
# terraform/modules/mariadb-vm/scripts/mariadb-setup.sh (metadata_startup_script).
# No hace falta instalar a mano salvo recuperacion (SSH por IAP y revision de logs/journal).
#
set -euo pipefail

DEPLOY_ENV="${1:-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================================"
echo "BarrioFarma - Deploy completo (${DEPLOY_ENV})"
echo "================================================"
echo ""

if [[ "$DEPLOY_ENV" != "dev" && "$DEPLOY_ENV" != "uat" ]]; then
  echo "Error: ambiente desconocido '${DEPLOY_ENV}'. Use: dev | uat"
  exit 1
fi

if [[ "$DEPLOY_ENV" == "dev" ]]; then
  PROJECT_ID="barriofarma-dev"
  CLUSTER_NAME="barriofarma-dev"
  ZONE="us-central1-a"
  TFVARS_REL="terraform.tfvars"
  K8S_NAMESPACE="barriofarma"
  CERT_NAMESPACE="barriofarma"
else
  PROJECT_ID="barriofarma-uat-cl"
  CLUSTER_NAME="barriofarma-uat"
  ZONE="us-central1-a"
  TFVARS_REL="environments/uat/terraform.tfvars"
  K8S_NAMESPACE="barriofarma-uat"
  CERT_NAMESPACE="barriofarma-uat"
fi

TFVARS_PATH="${ROOT_DIR}/terraform/${TFVARS_REL}"

echo "Proyecto (cluster): ${PROJECT_ID}"
echo "Cluster:            ${CLUSTER_NAME}"
echo "Zona:               ${ZONE}"
echo "tfvars:             ${TFVARS_REL}"
echo ""

# -----------------------------------------------------------------------------
# 1. Terraform
# -----------------------------------------------------------------------------
echo "----------------------------------------------------------------"
echo "FASE 1: Infraestructura Terraform"
echo "----------------------------------------------------------------"
cd "${ROOT_DIR}/terraform"

if [[ "$DEPLOY_ENV" == "uat" ]]; then
  if grep -qE '^\s*enable_mariadb_vm\s*=\s*true' "${TFVARS_PATH}" 2>/dev/null; then
    if [[ -z "${TF_VAR_mariadb_vm_db_password:-}" ]]; then
      echo "Aviso: enable_mariadb_vm=true pero TF_VAR_mariadb_vm_db_password no esta definida."
      echo "  export TF_VAR_mariadb_vm_db_password='(minimo 10 caracteres)'"
      echo "Sin esto, el check de Terraform puede fallar si mariadb_vm_db_password esta vacia en tfvars."
    fi
  fi
fi

echo "Terraform plan..."
terraform plan -var-file="${TFVARS_REL}"

read -r -p "Continuar con apply? (y/n): " -n 1
echo ""
if [[ ! "${REPLY:-}" =~ ^[Yy]$ ]]; then
  echo "Deploy cancelado."
  exit 1
fi

echo "Terraform apply..."
terraform apply -var-file="${TFVARS_REL}" -auto-approve

echo ""
echo "Configurando kubectl..."
gcloud container clusters get-credentials "${CLUSTER_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}"

# -----------------------------------------------------------------------------
# 2. Componentes externos (ingress, cert-manager)
# -----------------------------------------------------------------------------
echo ""
echo "----------------------------------------------------------------"
echo "FASE 2: Componentes externos en el cluster"
echo "----------------------------------------------------------------"
cd "${ROOT_DIR}/scripts"
./setup-external.sh

# -----------------------------------------------------------------------------
# 3. Aplicacion
# -----------------------------------------------------------------------------
echo ""
echo "----------------------------------------------------------------"
echo "FASE 3: Aplicacion BarrioFarma"
echo "----------------------------------------------------------------"

if [[ "$DEPLOY_ENV" == "dev" ]]; then
  cd "${ROOT_DIR}/k8s"
  echo "Aplicando manifests (base kustomize)..."
  kubectl apply -k .

  echo ""
  echo "Esperando pods..."
  sleep 10
  kubectl get pods -n "${K8S_NAMESPACE}"
else
  cd "${ROOT_DIR}/terraform"
  if [[ -z "${UAT_DB_HOST:-}" ]]; then
    MARIA_IP="$(terraform output -raw mariadb_vm_private_ip 2>/dev/null || true)"
    if [[ -n "${MARIA_IP}" && "${MARIA_IP}" != "null" ]]; then
      export UAT_DB_HOST="${MARIA_IP}"
      echo "UAT_DB_HOST desde Terraform (VM MariaDB): ${UAT_DB_HOST}"
    fi
  fi
  if [[ -z "${UAT_DB_HOST:-}" ]]; then
    echo "Error: defina UAT_DB_HOST o asegure salida mariadb_vm_private_ip (enable_mariadb_vm=true)."
    exit 1
  fi

  cd "${ROOT_DIR}/scripts"
  ./prepare-uat-external-config.sh

  ./apply-k8s-uat.sh

  PW_B64="$(cd "${ROOT_DIR}/terraform" && terraform output -raw mariadb_vm_k8s_secret_db_password_base64 2>/dev/null || true)"
  if [[ -n "${PW_B64}" && "${PW_B64}" != "null" ]]; then
    echo "Alineando Secret DB_PASSWORD con usuario de aplicacion de la VM MariaDB..."
    kubectl patch secret barriofarma-secrets -n "${K8S_NAMESPACE}" --type merge -p \
      "{\"data\":{\"DB_PASSWORD\":\"${PW_B64}\",\"DB_ROOT_PASSWORD\":\"${PW_B64}\"}}"
    echo "Reiniciando deployments que consumen el Secret..."
    kubectl get deploy -n "${K8S_NAMESPACE}" -o name | xargs -r -n1 kubectl rollout restart -n "${K8S_NAMESPACE}"
    kubectl rollout status deployment/barriofarma-backend -n "${K8S_NAMESPACE}" --timeout=300s
  else
    echo "Aviso: sin salida mariadb_vm_k8s_secret_db_password_base64; revise barriofarma-secrets (DB_PASSWORD) a mano."
  fi
fi

# -----------------------------------------------------------------------------
# 4. DNS
# -----------------------------------------------------------------------------
echo ""
echo "----------------------------------------------------------------"
echo "FASE 4: Actualizar DNS"
echo "----------------------------------------------------------------"
cd "${ROOT_DIR}/scripts"
export PROJECT_ID
export NAMESPACE="${K8S_NAMESPACE}"
if [[ "$DEPLOY_ENV" == "uat" ]]; then
  export DNS_PROJECT_ID="${DNS_PROJECT_ID:-barriofarmadigital}"
fi
./update-dns.sh

# -----------------------------------------------------------------------------
# 5. Certificado SSL
# -----------------------------------------------------------------------------
echo ""
echo "----------------------------------------------------------------"
echo "FASE 5: Verificar certificado SSL"
echo "----------------------------------------------------------------"

echo "Esperando emision del certificado (puede tardar 1-2 minutos)..."
CERT_READY="False"
for i in $(seq 1 24); do
  CERT_READY="$(kubectl get certificate barriofarma-tls -n "${CERT_NAMESPACE}" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")"

  if [[ "${CERT_READY}" == "True" ]]; then
    echo "OK: certificado SSL listo"
    break
  fi
  echo "   Esperando... (${i}/24)"
  sleep 5
done

if [[ "${CERT_READY}" != "True" ]]; then
  echo "Aviso: certificado aun en proceso"
  echo "   kubectl get certificate -n ${CERT_NAMESPACE}"
  echo "   kubectl describe certificate barriofarma-tls -n ${CERT_NAMESPACE}"
else
  echo ""
  echo "Verificando HTTPS..."
  HTTP_CODE="$(curl -s -o /dev/null -w "%{http_code}" "https://uat.barriofarma.cl" --max-time 10 || echo "000")"
  if [[ "${HTTP_CODE}" == "200" ]]; then
    echo "OK: sitio responde HTTP ${HTTP_CODE}"
  else
    echo "Aviso: codigo HTTP ${HTTP_CODE}"
  fi
fi

echo ""
echo "----------------------------------------------------------------"
echo "Deploy completo (${DEPLOY_ENV})"
echo "----------------------------------------------------------------"
kubectl get pods -n "${K8S_NAMESPACE}"
echo ""
kubectl get ingress -n "${K8S_NAMESPACE}"
echo ""
kubectl get certificate -n "${CERT_NAMESPACE}"
echo ""
echo "Comandos utiles:"
echo "  kubectl logs -f job/barriofarma-create-site -n ${K8S_NAMESPACE}"
echo "  kubectl get pods -n ${K8S_NAMESPACE} -w"
echo "  kubectl describe certificate barriofarma-tls -n ${CERT_NAMESPACE}"
echo ""
echo "URL: https://uat.barriofarma.cl"
if [[ "$DEPLOY_ENV" == "dev" ]]; then
  echo "Usuario: Administrator / Password: admin (valores por defecto de ejemplo en Secret)"
fi
