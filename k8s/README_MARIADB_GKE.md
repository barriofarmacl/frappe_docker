# MariaDB 11.8 en GKE - Implementación Híbrida

## 📋 Resumen

Este proyecto utiliza una **estrategia híbrida** para la base de datos:

| Ambiente | Base de Datos | Managed | Costo/mes |
|----------|---------------|---------|-----------|
| **Dev** | MariaDB 11.8 en GKE (StatefulSet) | ❌ | ~$3-17 |
| **Staging** | MariaDB 11.8 en GKE (StatefulSet) | ❌ | ~$3-17 |
| **Production** | Cloud SQL MySQL 8.0 | ✅ | ~$80-120 |

---

## 🎯 Ventajas de esta Estrategia

### **Dev/Staging:**
- ✅ MariaDB nativo 11.8 (100% compatible)
- ✅ Sin restricciones de Cloud SQL
- ✅ `bench new-site` funciona sin problemas
- ✅ Más económico
- ✅ Mismo cluster que la aplicación (menor latencia)

### **Production:**
- ✅ Cloud SQL con HA automática
- ✅ Backups automáticos y PITR
- ✅ Menos mantenimiento
- ✅ Alta disponibilidad garantizada
- ✅ Escalabilidad vertical fácil

---

## 📦 Recursos Creados

### 1. **StatefulSet de MariaDB**
Archivo: `statefulset-mariadb.yaml`

- 1 réplica de MariaDB 11.8
- Volumen persistente de 20GB (SSD)
- Configuración similar a docker-compose local
- Probes de liveness y readiness

### 2. **ConfigMap de MariaDB**
Archivo: `configmap-mariadb.yaml`

- Configuración personalizada (`custom.cnf`)
- InnoDB optimizado
- Character set UTF-8mb4
- Slow query log habilitado

### 3. **Service de MariaDB**
Archivo: `service.yaml` (agregado al final)

- ClusterIP: `mariadb.barriofarma.svc.cluster.local`
- Puerto: 3306
- Acceso interno al cluster

### 4. **CronJob de Backups**
Archivo: `cronjob-mariadb-backup.yaml`

- Ejecución diaria a las 2 AM UTC
- Backup completo con `mysqldump`
- Upload automático a Cloud Storage
- Retención: 7 días (dev), 30 días (production)
- ServiceAccount con permisos de lectura

---

## 🚀 Despliegue Inicial

### Paso 1: Provisionar infraestructura con Terraform

```bash
cd terraform

# Inicializar Terraform (si no lo has hecho)
terraform init

# Para dev (sin Cloud SQL)
terraform apply -var="environment=dev"

# Los outputs mostrarán:
# - database_host = "mariadb.barriofarma.svc.cluster.local"
# - database_type = "mariadb-gke"
```

### Paso 2: Configurar kubectl

```bash
# Obtener credenciales del cluster
gcloud container clusters get-credentials barriofarma-dev --zone us-central1-a --project PROJECT_ID

# Verificar conectividad
kubectl cluster-info
```

### Paso 3: Actualizar ConfigMap con valores de Terraform

```bash
cd terraform
./scripts/update-k8s-config.sh dev
```

Este script actualiza automáticamente:
- `DB_HOST` → `mariadb.barriofarma.svc.cluster.local`
- `FRAPPE_REDIS_CACHE` → IP de Memorystore Redis Cache
- `FRAPPE_REDIS_QUEUE` → IP de Memorystore Redis Queue
- `GCS_BUCKET_NAME` → Nombre del bucket de backups

### Paso 4: Desplegar todos los recursos de Kubernetes

```bash
cd ../k8s

# Aplicar todo el stack con Kustomize
kubectl apply -k .
```

### Paso 5: Monitorear despliegue

```bash
# Ver todos los recursos
kubectl get all -n barriofarma

# Ver estado del StatefulSet de MariaDB
kubectl get statefulset mariadb -n barriofarma

# Ver logs de MariaDB
kubectl logs -f statefulset/mariadb -n barriofarma

# Ver estado de los Jobs de inicialización
kubectl get jobs -n barriofarma
kubectl logs -f job/barriofarma-configurator -n barriofarma
kubectl logs -f job/barriofarma-create-site -n barriofarma
```

---

## 🔄 Orden de Despliegue

El orden correcto de inicialización es:

1. **Namespace, ConfigMap, Secrets, PVCs**
2. **MariaDB StatefulSet** → Esperar a que esté `Running` y `Ready`
3. **Jobs de inicialización:**
   - `job-configurator` → Configura Frappe
   - `job-create-site` → Crea sitio con `bench new-site`
4. **Deployments de la aplicación:**
   - Backend
   - Frontend
   - WebSocket
   - Scheduler
   - Workers (queue-short, queue-long)

**Kustomize maneja automáticamente este orden**, pero puedes aplicar manualmente si prefieres más control:

```bash
# 1. Base
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f configmap-mariadb.yaml
kubectl apply -f secret.yaml
kubectl apply -f pvc.yaml

# 2. MariaDB
kubectl apply -f statefulset-mariadb.yaml
kubectl apply -f service.yaml  # Incluye Service de MariaDB

# 3. Esperar a que MariaDB esté listo
kubectl wait --for=condition=ready pod -l app=mariadb -n barriofarma --timeout=300s

# 4. Jobs de inicialización
kubectl apply -f job-configurator.yaml
kubectl apply -f job-create-site.yaml

# 5. Deployments (después de que los Jobs completen)
kubectl apply -f deployment.yaml
kubectl apply -f deployment-frontend.yaml
kubectl apply -f deployment-websocket.yaml
kubectl apply -f deployment-scheduler.yaml
kubectl apply -f deployment-queue-short.yaml
kubectl apply -f deployment-queue-long.yaml
```

---

## 🔐 Backups Automáticos

### Configuración del CronJob

El CronJob de backups (`cronjob-mariadb-backup.yaml`) ejecuta diariamente:

1. **Backup con mysqldump:**
   - Todas las bases de datos
   - Single transaction (consistent snapshot)
   - Quick mode (optimizado para grandes datasets)

2. **Upload a Cloud Storage:**
   - Bucket: `gs://barriofarma-dev-storage/backups/mariadb/dev/`
   - Formato: `backup-YYYYMMDD-HHMMSS.sql.gz`

3. **Retención automática:**
   - Dev: 7 días
   - Staging: 7 días
   - Production: 30 días

### Verificar backups

```bash
# Ver Jobs de backup ejecutados
kubectl get jobs -n barriofarma -l app=mariadb-backup

# Ver logs del último backup
kubectl logs -n barriofarma -l app=mariadb-backup --tail=100

# Listar backups en Cloud Storage
gsutil ls gs://barriofarma-dev-storage/backups/mariadb/dev/
```

### Ejecutar backup manualmente

```bash
# Crear Job desde CronJob
kubectl create job --from=cronjob/mariadb-backup mariadb-backup-manual -n barriofarma

# Ver progreso
kubectl logs -f job/mariadb-backup-manual -n barriofarma
```

---

## 🔄 Restore de Backup

### Opción 1: Restore completo desde Cloud Storage

```bash
# 1. Descargar backup
gsutil cp gs://barriofarma-dev-storage/backups/mariadb/dev/backup-YYYYMMDD-HHMMSS.sql.gz /tmp/

# 2. Copiar al pod de MariaDB
kubectl cp /tmp/backup-YYYYMMDD-HHMMSS.sql.gz barriofarma/mariadb-0:/tmp/

# 3. Restaurar
kubectl exec -it mariadb-0 -n barriofarma -- bash -c '
  gunzip < /tmp/backup-YYYYMMDD-HHMMSS.sql.gz | \
  mariadb -u root -p$MYSQL_ROOT_PASSWORD
'

# 4. Reiniciar aplicación
kubectl rollout restart deployment -n barriofarma
```

### Opción 2: Restore desde dentro del pod

```bash
# 1. Entrar al pod de MariaDB
kubectl exec -it mariadb-0 -n barriofarma -- bash

# 2. Descargar backup directamente
gsutil cp gs://barriofarma-dev-storage/backups/mariadb/dev/backup-YYYYMMDD-HHMMSS.sql.gz /tmp/

# 3. Restaurar
gunzip < /tmp/backup-YYYYMMDD-HHMMSS.sql.gz | mariadb -u root -p$MYSQL_ROOT_PASSWORD

# 4. Salir
exit

# 5. Reiniciar aplicación
kubectl rollout restart deployment -n barriofarma
```

---

## 🔍 Troubleshooting

### MariaDB no inicia

```bash
# Ver logs
kubectl logs statefulset/mariadb -n barriofarma

# Describir pod para ver eventos
kubectl describe pod mariadb-0 -n barriofarma

# Verificar PVC
kubectl get pvc -n barriofarma
kubectl describe pvc mariadb-data-mariadb-0 -n barriofarma
```

### Jobs de inicialización fallan

```bash
# Ver logs del Job configurator
kubectl logs job/barriofarma-configurator -n barriofarma

# Ver logs del Job create-site
kubectl logs job/barriofarma-create-site -n barriofarma

# Verificar que MariaDB está accesible
kubectl exec -it mariadb-0 -n barriofarma -- mariadb-admin ping -h localhost -uroot -p$MYSQL_ROOT_PASSWORD
```

### Conectividad a MariaDB desde aplicación

```bash
# Ejecutar shell en backend
kubectl exec -it deployment/barriofarma-backend -n barriofarma -- bash

# Probar conexión
mariadb -h mariadb.barriofarma.svc.cluster.local -u barriofarma -pbfdb123 -e "SELECT VERSION()"

# Ver variables de entorno
env | grep DB_
```

### Backups no se ejecutan

```bash
# Ver estado del CronJob
kubectl get cronjob mariadb-backup -n barriofarma

# Ver últimos Jobs creados
kubectl get jobs -n barriofarma -l app=mariadb-backup

# Ver logs del ServiceAccount
kubectl get serviceaccount mariadb-backup-sa -n barriofarma
kubectl describe serviceaccount mariadb-backup-sa -n barriofarma

# Verificar permisos en Cloud Storage
gsutil iam get gs://barriofarma-dev-storage
```

---

## 📊 Monitoreo

### Métricas de MariaDB

```bash
# Conexiones activas
kubectl exec -it mariadb-0 -n barriofarma -- mariadb -uroot -p$MYSQL_ROOT_PASSWORD -e "SHOW STATUS LIKE 'Threads_connected'"

# Uso de memoria
kubectl exec -it mariadb-0 -n barriofarma -- mariadb -uroot -p$MYSQL_ROOT_PASSWORD -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size'"

# Tamaño de bases de datos
kubectl exec -it mariadb-0 -n barriofarma -- mariadb -uroot -p$MYSQL_ROOT_PASSWORD -e "
  SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
  FROM information_schema.TABLES
  GROUP BY table_schema;
"
```

### Uso de disco del PVC

```bash
# Ver uso de disco
kubectl exec -it mariadb-0 -n barriofarma -- df -h /var/lib/mysql
```

---

## 🔄 Migración a Production (Cloud SQL)

Cuando estés listo para migrar a production con Cloud SQL:

### Paso 1: Provisionar Cloud SQL

```bash
cd terraform
terraform apply -var="environment=production"

# Esto creará Cloud SQL MySQL 8.0 en lugar de usar MariaDB en GKE
```

### Paso 2: Actualizar ConfigMap

```bash
./scripts/update-k8s-config.sh production

# Esto actualizará DB_HOST con la IP privada de Cloud SQL
```

### Paso 3: Actualizar kustomization.yaml

```yaml
# En k8s/kustomization.yaml, comentar recursos de MariaDB:

resources:
  # ...
  # Database (MariaDB 11.8 en GKE para dev/staging)
  # En production, comentar estos recursos y usar Cloud SQL
  # - statefulset-mariadb.yaml
  # - configmap-mariadb.yaml
  # - cronjob-mariadb-backup.yaml
  # ...
```

### Paso 4: Migrar datos (si es necesario)

```bash
# 1. Crear backup de MariaDB en GKE
kubectl exec -it mariadb-0 -n barriofarma -- \
  mysqldump -uroot -p$MYSQL_ROOT_PASSWORD --all-databases --single-transaction | \
  gzip > mariadb-migration-backup.sql.gz

# 2. Importar a Cloud SQL (desde Cloud Shell o compute engine con acceso a VPC)
gcloud sql import sql barriofarma-production-db \
  gs://barriofarma-production-storage/migration/mariadb-migration-backup.sql.gz \
  --database=barriofarma
```

### Paso 5: Re-desplegar con Cloud SQL

```bash
kubectl apply -k .
```

---

## 📚 Referencias

- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Cloud SQL for MySQL](https://cloud.google.com/sql/docs/mysql)
- [Kustomize](https://kustomize.io/)

---

**Última actualización:** 12 de Noviembre 2025  
**Archivo:** `/home/faelo/barriofarmacl/frappe_docker/k8s/README_MARIADB_GKE.md`


