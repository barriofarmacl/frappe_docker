# Scripts de Automatización BarrioFarma

Scripts para deploy y destroy automatizado de la infraestructura completa.

## 📋 Scripts Disponibles

### 1. `deploy-all.sh` - Deploy Completo 100% Automatizado
Despliega toda la infraestructura desde cero sin intervención manual:
- ✅ **Fase 1**: Infraestructura GCP (Terraform)
- ✅ **Fase 2**: Componentes externos (NGINX Ingress, cert-manager, Let's Encrypt)
- ✅ **Fase 3**: Aplicación BarrioFarma (Kubernetes)
- ✅ **Fase 4**: Actualización DNS automática
- ✅ **Fase 5**: Verificación de certificado SSL y acceso HTTPS

**Uso:**
```bash
cd frappe_docker
./scripts/deploy-all.sh
```

**Tiempo estimado:** ~30-40 minutos

**Resultado:**
- GKE cluster operativo
- Aplicación desplegada
- HTTPS configurado en https://uat.barriofarma.cl

---

### 2. `setup-external.sh` - Componentes Externos
Instala solo los componentes externos (útil si el cluster ya existe):
- NGINX Ingress Controller
- cert-manager

**Uso:**
```bash
cd frappe_docker
./scripts/setup-external.sh
```

**Tiempo estimado:** ~5-10 minutos

**Nota:** Requiere que kubectl esté configurado con acceso al cluster.

---

### 3. `update-dns.sh` - Actualización DNS Automática
Detecta la IP del Ingress y actualiza el registro DNS en Google Cloud DNS automáticamente.

**Uso:**
```bash
cd frappe_docker
./scripts/update-dns.sh
```

**Funcionalidad:**
- Detecta IP del Ingress automáticamente
- Crea o actualiza registro DNS en Google Cloud DNS
- Espera propagación DNS
- Verifica resolución

**Tiempo estimado:** ~1-2 minutos

**Nota:** Se ejecuta automáticamente en `deploy-all.sh` (Fase 4).

---

### 4. `push-image.sh` - Subir Imagen Docker al Registry
Sube la imagen Docker local al Google Container Registry (GCR) para que GKE pueda usarla.

**Uso:**
```bash
cd frappe_docker
./scripts/push-image.sh [TAG]
```

**Ejemplos:**
```bash
# Usar tag por defecto (0.0.2-dev)
./scripts/push-image.sh

# Especificar tag personalizado
./scripts/push-image.sh 0.0.2-otel
./scripts/push-image.sh latest
```

**Funcionalidad:**
- Verifica que la imagen local existe
- Autentica con Google Container Registry
- Taggea la imagen para GCR
- Sube la imagen al registry

**Tiempo estimado:** ~2-5 minutos (depende del tamaño de la imagen)

**Requisitos:**
- Imagen local construida: `bf-app-dev:TAG`
- Autenticación con GCP: `gcloud auth login`
- Permisos para push a GCR

**Nota:** Este script debe ejecutarse ANTES de `deploy-all.sh` si has construido una nueva versión de la imagen.

---

### 5. `migrate-site.sh` - Migración de DocTypes
Ejecuta `bench migrate` en el sitio para aplicar cambios en DocTypes, customizaciones y actualizar la base de datos.

**Uso:**
```bash
cd frappe_docker
./scripts/migrate-site.sh [SITE_NAME]
```

**Ejemplos:**
```bash
# Migrar sitio por defecto (frontend)
./scripts/migrate-site.sh

# Migrar sitio específico
./scripts/migrate-site.sh frontend
./scripts/migrate-site.sh otro-sitio
```

**Funcionalidad:**
- Busca automáticamente el pod del backend
- Ejecuta `bench --site SITE_NAME migrate`
- Aplica cambios en DocTypes, customizaciones y dashboards
- Reconstruye índices de búsqueda

**Tiempo estimado:** ~2-5 minutos (depende de la cantidad de DocTypes)

**Cuándo usar:**
- Después de crear/modificar DocTypes en `barriofarma_app`
- Después de actualizar customizaciones
- Cuando los DocTypes no aparecen en la interfaz web
- Después de actualizar la aplicación con nuevos DocTypes

**Nota:** Este script se ejecuta dentro del pod del backend, no requiere acceso directo a la base de datos.

---

### 6. `destroy-all.sh` - Destrucción Completa
Destruye toda la infraestructura para ahorrar costos.

**Uso:**
```bash
cd frappe_docker
./scripts/destroy-all.sh
```

**⚠️ ADVERTENCIA:** 
- Elimina TODO el cluster y datos
- Requiere confirmación explícita (escribir "DESTROY")
- Preserva el bucket GCS de backups

**Tiempo estimado:** ~10 minutos

---

### 7. `download-cloudsql-certs.sh` - Descarga Certificados SSL Cloud SQL
Descarga automáticamente los certificados SSL necesarios para conectarse a Cloud SQL de forma segura.

**Uso:**
```bash
cd frappe_docker
./scripts/download-cloudsql-certs.sh [INSTANCE_NAME]
```

**Ejemplos:**
```bash
# Detectar instancia automáticamente desde Terraform
./scripts/download-cloudsql-certs.sh

# Especificar instancia manualmente
./scripts/download-cloudsql-certs.sh barriofarma-hybrid-poc-db
```

**Funcionalidad:**
- Crea certificado de cliente en Cloud SQL
- Descarga certificado de cliente (client-cert.pem)
- Descarga clave privada (client-key.pem)
- Descarga certificado CA del servidor (server-ca.pem)
- Configura permisos seguros (600) en todos los archivos
- Valida que los certificados tengan contenido válido

**Tiempo estimado:** ~30 segundos

**Requisitos:**
- gcloud CLI instalado y autenticado
- Permisos Cloud SQL Admin
- Terraform aplicado (si se usa detección automática)

**Nota:** Los certificados se guardan en `./certs/` y son necesarios para conexiones SSL seguras a Cloud SQL.

---

### 8. `test-cloudsql-connection.sh` - Validación de Conectividad Cloud SQL
Valida la conectividad y configuración de Cloud SQL antes de levantar Docker Compose.

**Uso:**
```bash
cd frappe_docker
./scripts/test-cloudsql-connection.sh [.env.hybrid]
```

**Ejemplos:**
```bash
# Usar .env.hybrid por defecto
./scripts/test-cloudsql-connection.sh

# Especificar archivo de entorno diferente
./scripts/test-cloudsql-connection.sh .env.hybrid.prod
```

**Funcionalidad:**
- Verifica conectividad de red (ping)
- Verifica acceso al puerto 3306
- Verifica existencia de certificados SSL (opcional)
- Prueba conexión MySQL con credenciales
- Verifica existencia de base de datos
- Mide latencia de queries simples

**Tiempo estimado:** ~10-20 segundos

**Requisitos:**
- Archivo `.env.hybrid` configurado con `CLOUD_SQL_IP`
- mysql client instalado (`apt install mysql-client`)
- Certificados SSL en `./certs/` (opcional pero recomendado)

**Nota:** Este script debe ejecutarse ANTES de levantar Docker Compose para validar que Cloud SQL es accesible.

---

## 🔄 Flujo de Trabajo Típico

### Deploy Diario (Desarrollo)
```bash
# Mañana: Levantar infraestructura
./scripts/deploy-all.sh

# Trabajar durante el día...

# Noche: Destruir para ahorrar costos
./scripts/destroy-all.sh
```

### Re-deploy Rápido
Si el cluster ya existe pero necesitas reinstalar componentes externos:
```bash
# Solo componentes externos
./scripts/setup-external.sh

# Aplicación
cd k8s
kubectl apply -k .
```

### Actualizar Imagen Docker
Si has construido una nueva versión de la imagen y quieres desplegarla:
```bash
# 1. Construir la imagen localmente
cd frappe_docker
docker build -f images/barriofarma/dev/Containerfile -t bf-app-dev:0.0.2-dev .

# 2. Subir al registry
./scripts/push-image.sh 0.0.2-dev

# 3. Si el cluster ya existe, solo actualizar la aplicación
cd k8s
kubectl apply -k .

# 4. Forzar el pull de la nueva imagen (si el tag es el mismo)
kubectl rollout restart deployment/barriofarma-backend -n barriofarma
kubectl rollout restart deployment/barriofarma-frontend -n barriofarma
kubectl rollout restart deployment/barriofarma-websocket -n barriofarma
# ... (otros deployments)
```

### Crear/Modificar DocTypes
Si has creado o modificado DocTypes en `barriofarma_app`:
```bash
# 1. Si la imagen cambió (nuevos DocTypes en código), construir y subir
docker build -f images/barriofarma/dev/Containerfile -t bf-app-dev:0.0.2-dev .
./scripts/push-image.sh 0.0.2-dev
kubectl rollout restart deployment/barriofarma-backend -n barriofarma

# 2. Ejecutar migrate para aplicar los cambios en la base de datos
./scripts/migrate-site.sh frontend

# 3. Verificar que los DocTypes aparecen en la interfaz web
# Acceder a https://uat.barriofarma.cl y buscar en Lista de DocTypes
```

---

## 🛠️ Requisitos Previos

### Herramientas Necesarias
- `gcloud` CLI configurado
- `kubectl` instalado
- `terraform` instalado
- Autenticación en GCP configurada

### Configuración
```bash
# Autenticar con GCP
gcloud auth login
gcloud auth application-default login

# Configurar proyecto
gcloud config set project barriofarma-dev
```

---

## 📊 Validación Post-Deploy

### Verificar Infraestructura
```bash
# Verificar nodos
kubectl get nodes

# Verificar pods
kubectl get pods -n barriofarma

# Verificar ingress
kubectl get ingress -n barriofarma

# Verificar certificado SSL
kubectl get certificate -n barriofarma
```

### Verificar Aplicación
```bash
# Logs del job create-site
kubectl logs -f job/barriofarma-create-site -n barriofarma

# Estado de backend
kubectl get pods -n barriofarma -l app.kubernetes.io/component=backend

# Endpoints de servicios
kubectl get endpoints -n barriofarma
```

### Acceso Web
- URL: https://uat.barriofarma.cl
- Usuario: Administrator
- Password: admin

---

## 🐛 Troubleshooting

### Error: "No hay conexión al cluster"
```bash
gcloud container clusters get-credentials barriofarma-dev \
  --zone us-central1-a \
  --project barriofarma-dev
```

### Error: "Image pull failed"
Verificar que el rol `artifactregistry.reader` esté configurado en Terraform.

### Pods en Pending
Verificar que el node tenga el label correcto:
```bash
kubectl get nodes --show-labels | grep shared-storage
```

### Certificado SSL pendiente
Verificar DNS:
```bash
nslookup uat.barriofarma.cl
```

Verificar cert-manager:
```bash
kubectl get certificate -n barriofarma
kubectl describe certificate barriofarma-tls -n barriofarma
```

---

## 📝 Notas

- Los scripts son idempotentes (se pueden ejecutar múltiples veces)
- El bucket GCS de backups NO se elimina con `destroy-all.sh`
- Los scripts incluyen validaciones y mensajes de progreso
- Se requiere confirmación para operaciones destructivas

