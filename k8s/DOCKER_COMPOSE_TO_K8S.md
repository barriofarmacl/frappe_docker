# 🔄 Equivalencias Docker Compose ↔ Kubernetes

Este documento mapea los servicios de `docker-compose.barriofarma.yml` a sus equivalentes en Kubernetes.

## 📊 Tabla de Equivalencias

| Docker Compose Service | Kubernetes Resource | Tipo | Archivo | Notas |
|----------------------|---------------------|------|---------|-------|
| `configurator` | `barriofarma-configurator` | Job | `job-configurator.yaml` | Ejecuta una vez para inicializar `common_site_config.json` |
| `create-site` | `barriofarma-create-site` | Job | `job-create-site.yaml` | Ejecuta una vez para crear el sitio inicial |
| `backend` | `barriofarma-backend` | Deployment | `deployment.yaml` | Servidor Gunicorn (2 réplicas) |
| `frontend` | `barriofarma-frontend` | Deployment | `deployment-frontend.yaml` | Nginx reverse proxy (2 réplicas) |
| `websocket` | `barriofarma-websocket` | Deployment | `deployment-websocket.yaml` | SocketIO server (2 réplicas) |
| `scheduler` | `barriofarma-scheduler` | Deployment | `deployment-scheduler.yaml` | Tareas programadas (1 réplica) |
| `queue-short` | `barriofarma-queue-short` | Deployment | `deployment-queue-short.yaml` | Workers para queues cortas (2 réplicas) |
| `queue-long` | `barriofarma-queue-long` | Deployment | `deployment-queue-long.yaml` | Workers para queues largas (1 réplica) |
| `db` (MariaDB) | Cloud SQL | Servicio Gestionado | N/A | Provisionado con Terraform |
| `redis-cache` | Memorystore Redis Cache | Servicio Gestionado | N/A | Provisionado con Terraform |
| `redis-queue` | Memorystore Redis Queue | Servicio Gestionado | N/A | Provisionado con Terraform |

## 🔄 Diferencias Clave

### 1. Base de Datos y Redis

**Docker Compose:**
- Contenedores locales (`db`, `redis-cache`, `redis-queue`)
- Red simple entre contenedores
- Volúmenes locales

**Kubernetes:**
- Servicios gestionados de GCP (Cloud SQL, Memorystore)
- Conexión privada a través de VPC
- IPs privadas configuradas en ConfigMap

### 2. Init Containers vs depends_on

**Docker Compose:**
```yaml
depends_on:
  - create-site
```

**Kubernetes:**
```yaml
initContainers:
  - name: wait-for-db
    # Verifica conectividad antes de iniciar
```

### 3. Jobs vs Services

**Docker Compose:**
- `configurator` y `create-site` son servicios con `restart_policy: none`
- Se ejecutan una vez al iniciar

**Kubernetes:**
- `configurator` y `create-site` son Jobs
- Se ejecutan una vez y completan
- `ttlSecondsAfterFinished: 86400` los elimina después de 24 horas

### 4. Volúmenes

**Docker Compose:**
```yaml
volumes:
  sites:
  logs:
```

**Kubernetes:**
```yaml
volumes:
  - name: sites-data
    persistentVolumeClaim:
      claimName: barriofarma-sites-pvc
```

### 5. Redes

**Docker Compose:**
```yaml
networks:
  - frappe_network
  - observability_network
```

**Kubernetes:**
- Todas las comunicaciones dentro del mismo namespace
- Services proporcionan DNS interno (`barriofarma-backend-service:8000`)

## 📝 Orden de Ejecución

### Docker Compose
1. `db`, `redis-cache`, `redis-queue` → Se levantan primero
2. `configurator` → Crea `common_site_config.json`
3. `create-site` → Crea el sitio (depende de `configurator`)
4. `backend`, `frontend`, `websocket`, `scheduler`, `queues` → Se levantan después

### Kubernetes
1. **Jobs (una sola vez):**
   - `barriofarma-configurator` → Crea `common_site_config.json`
   - `barriofarma-create-site` → Crea el sitio (depende de configurator)

2. **Deployments (siempre corriendo):**
   - `barriofarma-backend` → Servidor Gunicorn
   - `barriofarma-frontend` → Nginx (depende de backend y websocket)
   - `barriofarma-websocket` → SocketIO
   - `barriofarma-scheduler` → Tareas programadas
   - `barriofarma-queue-short` → Workers cortos
   - `barriofarma-queue-long` → Workers largos

## 🔧 Configuración de Variables de Entorno

### Docker Compose
```yaml
environment:
  FRAPPE_REDIS_CACHE: redis://redis-cache:6379
  DB_HOST: db
```

### Kubernetes
```yaml
env:
  - name: FRAPPE_REDIS_CACHE
    valueFrom:
      configMapKeyRef:
        name: barriofarma-config
        key: FRAPPE_REDIS_CACHE
  - name: DB_HOST
    valueFrom:
      configMapKeyRef:
        name: barriofarma-config
        key: DB_HOST
```

## 🚀 Comandos Equivalentes

### Ver estado

**Docker Compose:**
```bash
docker-compose -f docker-compose.barriofarma.yml ps
```

**Kubernetes:**
```bash
kubectl get pods -n barriofarma
kubectl get jobs -n barriofarma
kubectl get deployments -n barriofarma
```

### Ver logs

**Docker Compose:**
```bash
docker-compose -f docker-compose.barriofarma.yml logs -f backend
```

**Kubernetes:**
```bash
kubectl logs -f deployment/barriofarma-backend -n barriofarma
```

### Reiniciar servicio

**Docker Compose:**
```bash
docker-compose -f docker-compose.barriofarma.yml restart backend
```

**Kubernetes:**
```bash
kubectl rollout restart deployment/barriofarma-backend -n barriofarma
```

### Escalar réplicas

**Docker Compose:**
```yaml
# Editar docker-compose.yml
deploy:
  replicas: 3
```

**Kubernetes:**
```bash
kubectl scale deployment barriofarma-backend --replicas=3 -n barriofarma
```

## 📚 Referencias

- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)

