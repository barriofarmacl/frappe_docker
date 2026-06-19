# 🚀 BarrioFarma - Kubernetes Manifests

## SDD / OpenSpec

El marco de especificación y colaboración entre desarrollo y DevOps está en el submódulo de metodología: desde la raíz del monorepo, [development/.cursor/docs/development/devops_dev_collaboration.md](../development/.cursor/docs/development/devops_dev_collaboration.md). Los cambios a estos manifiestos deben enlazarse a un issue (whiteboard) y, cuando aplique, a una carpeta bajo `development/.cursor/openspec/changes/`.

## 📋 Descripción

Manifests de Kubernetes para desplegar BarrioFarma en un cluster de GKE con Cloud SQL MariaDB y Memorystore Redis.

### Contrato de versión dev

- Registry dev oficial: `gcr.io/barriofarma-dev/bf-app-dev`
- Tag operativo dev: `0.0.2-dev`
- Fuente de verdad de tag: `kustomization.yaml` (`images.newTag`)

### Overlay UAT (artefacto congelado 0.0.3)

- Namespace Kubernetes: `barriofarma-uat`
- Proyecto GCP (registry): `barriofarma-uat-cl`
- Imagen: `gcr.io/barriofarma-uat-cl/bf-app-uat:0.0.3-uat`
- Pin de app custom: `apps-uat.json` apunta a `barriofarma_app` tag `v0.0.3` (campo `branch` en JSON)
- Build y push: desde `frappe_docker`, `scripts/rebuild-and-push-uat.sh`
- **Antes del apply:** MariaDB en VPS y Redis externos resueltos; generar `k8s/overlays/uat/configmap-external.yaml` con `scripts/prepare-uat-external-config.sh` (archivo gitignored; plantilla `configmap-external.example.yaml`)
- Apply: `scripts/apply-k8s-uat.sh` (falla si falta `configmap-external.yaml`; usa `kubectl kustomize --load-restrictor=LoadRestrictionsNone`)
- El overlay excluye StatefulSets/Services de MariaDB y Redis en cluster; `Secret` debe alinear `DB_PASSWORD` con la VPS (ver `terraform/DEPLOY_UAT.md`)

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Ingress       │    │   Frontend      │    │   Backend       │
│   (Nginx)       │───▶│   (Port 8080)   │───▶│   (Port 8000)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                      │
                                                      ▼
                                              ┌─────────────────┐
                                              │   WebSocket     │
                                              │   (Port 9000)   │
                                              └─────────────────┘
                                                      │
                    ┌────────────────────────────────┼────────────────────┐
                    │                                │                    │
                    ▼                                ▼                    ▼
        ┌──────────────────┐            ┌──────────────────┐  ┌──────────────────┐
        │  Cloud SQL       │            │ Memorystore      │  │ Memorystore      │
        │  MariaDB 11.8    │            │ Redis Cache      │  │ Redis Queue      │
        │  (Private IP)    │            │ (Private IP)     │  │ (Private IP)     │
        │  Port 3306       │            │ Port 6379        │  │ Port 6379        │
        └──────────────────┘            └──────────────────┘  └──────────────────┘
```

## 📁 Estructura de Archivos

```
k8s/
├── ✅ ESENCIALES (7 archivos)
│   ├── namespace.yaml                    # Namespace barriofarma
│   ├── configmap.yaml                   # Configuración de la aplicación
│   ├── secret.yaml                      # Credenciales y secrets
│   ├── pvc.yaml                         # Persistent Volume Claims
│   ├── deployment.yaml                  # Deployment del backend
│   ├── service.yaml                     # Servicios (backend, frontend, websocket)
│   └── kustomization.yaml               # Kustomize configuration
│
├── ⚠️ RECOMENDADOS (5 archivos)
│   ├── deployment-frontend.yaml         # Deployment del frontend (Nginx)
│   ├── deployment-websocket.yaml        # Deployment del websocket (SocketIO)
│   ├── deployment-scheduler.yaml        # Deployment del scheduler
│   ├── deployment-queue-short.yaml      # Deployment de queue workers cortos
│   └── deployment-queue-long.yaml       # Deployment de queue workers largos
│
├── 🚀 INICIALIZACIÓN (2 archivos - solo primera vez)
│   ├── job-configurator.yaml            # Job para inicializar common_site_config.json
│   └── job-create-site.yaml             # Job para crear el sitio inicial
│
├── 🌐 OPCIONALES (8 archivos)
│   ├── ingress.yaml                     # Ingress con TLS (si necesitas acceso externo)
│   ├── servicemonitor.yaml              # ServiceMonitor para Prometheus (si usas Prometheus Operator)
│   ├── hpa-backend.yaml                 # HPA para autoscaling backend (opcional)
│   ├── hpa-frontend.yaml                # HPA para autoscaling frontend (opcional)
│   ├── hpa-queue-short.yaml            # HPA para autoscaling queue (opcional)
│   ├── argocd-application.yaml          # ArgoCD Application (si usas ArgoCD)
│   ├── argocd-application-dev.yaml     # ArgoCD Application dev (si usas ArgoCD)
│   └── argocd-install.yaml              # Instalar ArgoCD (generalmente no se usa)
│
└── 📝 EJEMPLOS/DOCUMENTACIÓN
    ├── configmap-gcp.example.yaml        # Ejemplo para GCP
    ├── deployment-gcp.example.yaml      # Ejemplo con Cloud SQL Proxy
    ├── ARGOCD_SETUP.md                  # Guía de instalación ArgoCD
    ├── DOCKER_COMPOSE_TO_K8S.md         # Equivalencias docker-compose ↔ k8s
    ├── RESOURCE_RECOMMENDATIONS.md      # Recomendaciones de recursos
    ├── YAML_FILES_EXPLAINED.md          # Explicación detallada de cada archivo
    └── FILES_QUICK_REFERENCE.md          # Referencia rápida de archivos necesarios
```

**📊 Resumen:**
- **Esenciales:** 7 archivos (mínimo para funcionar)
- **Recomendados:** 5 archivos (stack completo)
- **Inicialización:** 2 archivos (solo primera vez)
- **Opcionales:** 8 archivos (según necesidad)
- **Ejemplos:** 2 archivos (solo documentación)

**Ver:** [FILES_QUICK_REFERENCE.md](./FILES_QUICK_REFERENCE.md) para guía rápida de qué archivos necesitas.

## 🔧 Componentes

### 1. **Namespace**
- `barriofarma`: Namespace principal con labels para identificación

### 2. **ConfigMap**
- Configuración de Frappe
- Variables de entorno para observabilidad
- Configuración de Redis (Memorystore) y MariaDB (Cloud SQL)
- **Nota**: Actualizar IPs después de `terraform apply` usando `terraform/update-k8s-config.sh`

### 3. **Secrets**
- Credenciales de base de datos (Cloud SQL MariaDB)
- Passwords de Redis (si se requiere autenticación)
- API keys para observabilidad

### 4. **PersistentVolumeClaim**
- `barriofarma-sites-pvc`: Datos del sitio (10Gi)
- `barriofarma-logs-pvc`: Logs de la aplicación (5Gi)

### 5. **Jobs (Ejecución Única)**
- **Configurator**: Inicializa `common_site_config.json` con configuración de DB y Redis
- **Create Site**: Crea el sitio inicial `frontend` con ERPNext y BarrioFarma App
- **TTL**: Se eliminan automáticamente después de 24 horas

### 6. **Deployments**
- **Backend**: 2 réplicas con observabilidad integrada (Gunicorn)
- **Frontend**: 2 réplicas (Nginx reverse proxy)
- **WebSocket**: 2 réplicas (SocketIO)
- **Scheduler**: 1 réplica (tareas programadas)
- **Queue Short**: 2 réplicas (workers para queues cortas)
- **Queue Long**: 1 réplica (workers para queues largas)
- **Health checks**: Liveness y readiness probes en todos
- **Resources**: Requests y limits optimizados según uso real de cada componente
  - Ver [RESOURCE_RECOMMENDATIONS.md](./RESOURCE_RECOMMENDATIONS.md) para detalles completos
- **Init containers**: 
  - Espera por Cloud SQL MariaDB (usando `mysqladmin ping`)
  - Espera por Memorystore Redis Cache
  - Espera por Memorystore Redis Queue

### 7. **Services**
- `barriofarma-backend-service`: Puerto 8000
- `barriofarma-frontend-service`: Puerto 8080  
- `barriofarma-websocket-service`: Puerto 9000

### 8. **Ingress**
- TLS habilitado con Let's Encrypt
- Routing por paths:
  - `/api` → Backend
  - `/socket.io` → WebSocket
  - `/` → Frontend
- Headers de seguridad configurados

### 9. **ServiceMonitor**
- Métricas de Prometheus
- Scraping cada 30s
- Filtros para métricas relevantes

## 🚀 Despliegue

### Prerrequisitos

```bash
# 1. Infraestructura creada con Terraform
cd ../terraform
terraform apply -var-file=environments/dev/terraform.tfvars

# 2. Obtener outputs y actualizar ConfigMap automáticamente
./update-k8s-config.sh dev

# O manualmente: Actualizar configmap.yaml con IPs obtenidas de:
# terraform output database_private_ip
# terraform output redis_cache_host
# terraform output redis_queue_host

# 3. Configurar kubectl
terraform output kubectl_config  # Ejecutar el comando mostrado
# Ejemplo: gcloud container clusters get-credentials barriofarma-dev --zone us-central1-a --project barriofarma-dev

# 4. Verificar conexión al cluster
kubectl get nodes

# 5. Namespace creado
kubectl apply -f ../k8s/namespace.yaml

# 6. Secrets configurados (editar secret.yaml con valores reales)
kubectl apply -f ../k8s/secret.yaml
```

### Despliegue con Kustomize

```bash
# Desplegar todo
kubectl apply -k .

# Verificar recursos
kubectl get all -n barriofarma

# Ver logs
kubectl logs -f deployment/barriofarma-backend -n barriofarma
```

### Despliegue con ArgoCD (GitOps - Recomendado)

**ArgoCD es el método principal de despliegue** siguiendo principios GitOps.

#### 1. Instalar ArgoCD

```bash
# Crear namespace
kubectl create namespace argocd

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Esperar a que esté listo
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s
```

#### 2. Configurar acceso

```bash
# Obtener password inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward para acceso local
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Acceder a: https://localhost:8080
# Usuario: admin
```

#### 3. Aplicar Application manifests

```bash
# Para desarrollo
kubectl apply -f argocd-application-dev.yaml

# Para staging/producción
kubectl apply -f argocd-application.yaml

# Verificar aplicaciones
kubectl get applications -n argocd
```

#### 4. Flujo GitOps

1. **Actualizar manifests** con IPs de Terraform:
   ```bash
   cd ../terraform
   ./update-k8s-config.sh dev
   ```

2. **Commit y push a Git**:
   ```bash
   cd ../k8s
   git checkout barriofarma-develop  # Asegurarse de estar en la rama correcta
   git add configmap.yaml
   git commit -m "feat: actualizar configmap con IPs de Cloud SQL y Memorystore"
   git push origin barriofarma-develop
   ```

3. **ArgoCD sincroniza automáticamente** (si `syncPolicy.automated` está habilitado)

4. **Verificar en ArgoCD UI**:
   - Acceder a https://localhost:8080
   - Ver aplicación `barriofarma-dev`
   - Estado debe ser "Healthy" y "Synced"

**Ventajas de ArgoCD:**
- ✅ Git como source of truth
- ✅ Sincronización automática
- ✅ Self-healing (detecta y corrige drift)
- ✅ Historial de cambios
- ✅ Rollback fácil
- ✅ UI para monitoreo

Ver más detalles en: [ARGOCD_SETUP.md](./ARGOCD_SETUP.md)

## 📊 Observabilidad

### Métricas Disponibles

- **Técnicas (RED Method)**:
  - `http_requests_total`: Total de requests HTTP
  - `http_request_duration_seconds`: Duración de requests
  - `http_requests_errors_total`: Errores HTTP

- **Business Metrics**:
  - `barriofarma_users_total`: Usuarios registrados
  - `barriofarma_orders_total`: Órdenes procesadas
  - `barriofarma_inventory_items_total`: Items en inventario

### Logs Estructurados

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "INFO",
  "service": "barriofarma-backend",
  "trace_id": "abc123",
  "span_id": "def456",
  "message": "User login successful",
  "user_id": "admin",
  "ip_address": "192.168.1.100"
}
```

## 🔒 Seguridad

- **TLS**: Certificados automáticos con Let's Encrypt
- **Headers**: X-Frame-Options, X-Content-Type-Options, etc.
- **Secrets**: Encriptados en etcd
- **Network Policies**: (Pendiente implementación)
- **Cloud SQL**: Conexión privada (sin IP pública)
- **Memorystore**: Acceso solo desde VPC privada

## 📈 Escalabilidad

- **HPA**: Horizontal Pod Autoscaler (archivos disponibles: `hpa-*.yaml`)
  - Backend: 2-10 réplicas (CPU 70%, Memoria 80%)
  - Frontend: 2-5 réplicas (CPU 70%)
  - Queue Short: 2-5 réplicas (CPU 70%)
  - Descomentar en `kustomization.yaml` cuando esté listo para usar
- **VPA**: Vertical Pod Autoscaler (pendiente implementación)
- **Resources**: Requests y limits optimizados según uso real de cada componente
  - Ver [RESOURCE_RECOMMENDATIONS.md](./RESOURCE_RECOMMENDATIONS.md) para detalles completos
- **Replicas**: Configuradas según componente
  - Backend: 2, Frontend: 2, WebSocket: 2, Scheduler: 1, Queue Short: 2, Queue Long: 1

## 🛠️ Troubleshooting

### Verificar Estado

```bash
# Estado general
kubectl get all -n barriofarma

# Logs del backend
kubectl logs -f deployment/barriofarma-backend -n barriofarma

# Describir pod
kubectl describe pod <pod-name> -n barriofarma

# Verificar eventos
kubectl get events -n barriofarma --sort-by='.lastTimestamp'
```

### Problemas Comunes

1. **Pod no inicia**: Verificar secrets y configmaps
2. **Health check falla**: Verificar conectividad a Cloud SQL MariaDB y Memorystore Redis
3. **Error de conexión a Cloud SQL**:
   - Verificar que `DB_HOST` tiene la IP privada correcta (obtener con `terraform output database_private_ip`)
   - Verificar que el cluster GKE está en la misma VPC
   - Verificar que Private Service Connection está activo
   - Probar conexión desde un pod: `mysql -h <DB_IP> -u barriofarma -pbfdb123 barriofarma`
4. **Error de conexión a Memorystore Redis**:
   - Verificar que `FRAPPE_REDIS_CACHE` y `FRAPPE_REDIS_QUEUE` tienen IPs correctas
   - Obtener IPs con: `terraform output redis_cache_host` y `terraform output redis_queue_host`
   - Verificar que Memorystore está en la misma VPC
   - Probar conexión desde un pod: `redis-cli -h <REDIS_IP> -p 6379 ping`
5. **Ingress no funciona**: Verificar certificados TLS
6. **Métricas no aparecen**: Verificar ServiceMonitor

## 🔄 Actualizaciones

### Rolling Update

```bash
# Actualizar imagen
kubectl set image deployment/barriofarma-backend backend=gcr.io/barriofarma-dev/bf-app-dev:0.0.2-dev -n barriofarma

# Verificar rollout
kubectl rollout status deployment/barriofarma-backend -n barriofarma

# Rollback si es necesario
kubectl rollout undo deployment/barriofarma-backend -n barriofarma
```

### Blue-Green Deployment

```bash
# (Pendiente implementación con ArgoCD)
```

## 📚 Referencias

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Cloud SQL Connection](https://cloud.google.com/sql/docs/mysql/connect-kubernetes-engine)
- [Memorystore Redis](https://cloud.google.com/memorystore/docs/redis)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Cert-Manager](https://cert-manager.io/docs/)
- [Guía de Despliegue GCP](../terraform/DEPLOYMENT_GUIDE.md)
