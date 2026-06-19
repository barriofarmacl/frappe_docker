# 📊 Stack de Observabilidad - BarrioFarma

Stack completo de observabilidad para BarrioFarma utilizando OpenTelemetry, Prometheus, Grafana y Loki.

## 🏗️ Arquitectura

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│   Application   │────▶│  OTEL Collector  │────▶│ Prometheus  │
│   (Backend)     │     │                  │     │             │
└─────────────────┘     └──────────────────┘     └──────┬──────┘
                                                          │
                                                          ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│   Docker Logs   │────▶│     Promtail      │────▶│    Loki     │
│                 │     │                  │     │             │
└─────────────────┘     └──────────────────┘     └──────┬──────┘
                                                          │
                                                          ▼
                                                   ┌─────────────┐
                                                   │   Grafana   │
                                                   │             │
                                                   └─────────────┘
```

## 🚀 Inicio Rápido

### 1. Levantar el Stack de Observabilidad

```bash
cd /home/faelo/barriofarmacl/frappe_docker/observability
docker-compose -f docker-compose.observability.yml up -d
```

### 2. Verificar que los Servicios Están Corriendo

```bash
docker-compose -f docker-compose.observability.yml ps
```

Deberías ver:
- ✅ `otel-collector` - Running
- ✅ `prometheus` - Running
- ✅ `grafana` - Running
- ✅ `loki` - Running
- ✅ `promtail` - Running
- ✅ `mariadb-exporter` - Running

### 3. Acceder a las Interfaces

- **Grafana**: http://localhost:3000
  - Usuario: `admin`
  - Password: `admin`
- **Prometheus**: http://localhost:9090
- **Loki**: http://localhost:3100

## 📋 Componentes

### OpenTelemetry Collector
- **Puerto**: 4317 (gRPC), 4318 (HTTP)
- **Función**: Recibe trazas y métricas de la aplicación
- **Exporta a**: Prometheus, Debug (logging)

### Prometheus
- **Puerto**: 9090
- **Función**: Scraping y almacenamiento de métricas
- **Retención**: 30 días
- **Targets activos**: `otel-collector`, `prometheus` (self-monitoring)

### Grafana
- **Puerto**: 3000
- **Función**: Visualización de métricas y logs
- **Datasources**: Prometheus y Loki (auto-configurados)

### Loki
- **Puerto**: 3100
- **Función**: Agregación de logs
- **Storage**: Filesystem local

### Promtail
- **Función**: Recolecta logs de contenedores Docker
- **Envía a**: Loki

### MariaDB Exporter
- **Puerto**: 9104
- **Función**: Expone métricas de MariaDB en formato Prometheus
- **Configuración**: Archivo `.my.cnf` con credenciales del usuario `exporter`
- **Usuario de monitoreo**: `exporter` (creado con permisos limitados)

### Redis Exporters
- **Puerto**: 9121 (ambos exporters)
- **Función**: Expone métricas de Redis en formato Prometheus
- **Servicios**: 
  - `redis-exporter-cache` - Métricas de Redis Cache
  - `redis-exporter-queue` - Métricas de Redis Queue
- **Configuración**: Variable de entorno `REDIS_ADDR` apuntando a cada instancia

## 🔧 Configuración

### Variables de Entorno OTEL (Backend)

El backend ya está configurado con estas variables en `docker-compose.barriofarma.yml`:

```yaml
OTEL_SERVICE_NAME: barriofarma-backend
OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4317
METRICS_ENABLED: "true"
METRICS_PORT: "9090"
```

### Scraping de Métricas

Prometheus está configurado para hacer scraping de:
- ✅ `otel-collector:8889` - Métricas del OTEL Collector
- ✅ `localhost:9090` - Self-monitoring de Prometheus
- ✅ `mariadb-exporter:9104` - Métricas de MariaDB
- ✅ `redis-exporter-cache:9121` - Métricas de Redis Cache
- ✅ `redis-exporter-queue:9121` - Métricas de Redis Queue
- ⚠️ `backend:9090` - Métricas de la aplicación (requiere activación manual)

## ⚠️ Estado Actual de Métricas del Backend

El módulo de métricas (`observability_metrics.py`) está disponible en la imagen pero **NO está activado automáticamente**. 

### Para Activar Métricas del Backend

El endpoint `/metrics` necesita ser iniciado manualmente. Opciones:

1. **Usar el módulo directamente en código Python** (recomendado para desarrollo):
   ```python
   from frappe.utils.observability_metrics import get_metrics
   # El módulo expone métricas pero necesita un servidor HTTP
   ```

2. **Agregar un servicio separado de métricas** en docker-compose (recomendado para producción):
   - Crear un servicio que ejecute un servidor HTTP simple en el puerto 9090
   - Exponer el endpoint `/metrics` usando `prometheus_client`

3. **Integrar con Gunicorn** (requiere modificar el entrypoint):
   - Agregar middleware de métricas al servidor Gunicorn

**Por ahora**, el stack está funcionando con:
- ✅ Trazas OTEL (si están habilitadas en el código)
- ✅ Logs estructurados (si están habilitados)
- ✅ Métricas del OTEL Collector
- ⏳ Métricas de aplicación (requieren activación)

## 📊 Dashboards

### Dashboards Predefinidos
- **BarrioFarma - Overview**: Dashboard básico con métricas principales (disponible cuando las métricas estén activas)
- **MariaDB - Overview**: Dashboard específico para métricas de MariaDB con queries, conexiones, slow queries, buffer pool y más
- **Redis - Overview**: Dashboard específico para métricas de Redis (Cache y Queue) con hit ratio, operaciones, memoria y latencia

### Crear Nuevos Dashboards

1. Accede a Grafana: http://localhost:3000
2. Ve a "Dashboards" → "New Dashboard"
3. Importa desde JSON o crea manualmente
4. Guarda en `/observability/grafana/dashboards/` para persistencia

## 📝 Logs

Los logs se recolectan automáticamente de todos los contenedores Docker mediante Promtail.

### Ver Logs en Grafana

1. Accede a Grafana: http://localhost:3000
2. Ve a "Explore" → Selecciona "Loki"
3. Usa LogQL para filtrar:
   ```
   {service="barriofarma-backend"}
   {container="frappe_docker-backend-1"}
   ```

## 🔍 Métricas Disponibles

### Métricas del OTEL Collector
- `otelcol_receiver_accepted_spans` - Trazas aceptadas
- `otelcol_receiver_refused_spans` - Trazas rechazadas
- `otelcol_processor_batch_batch_send_size` - Tamaño de batches

### Métricas de Prometheus (Self-Monitoring)
- `prometheus_tsdb_head_samples_appended_total` - Samples agregados
- `prometheus_target_interval_length_seconds` - Intervalo de scraping

### Métricas de MariaDB
- `mysql_global_status_queries` - Total de queries ejecutadas
- `mysql_global_status_slow_queries` - Queries lentas
- `mysql_global_status_threads_connected` - Conexiones activas
- `mysql_global_status_innodb_buffer_pool_pages_total` - Buffer pool total
- `mysql_global_status_innodb_buffer_pool_pages_data` - Páginas de datos en buffer
- `mysql_global_status_innodb_buffer_pool_pages_free` - Páginas libres en buffer
- `mysql_global_variables_max_connections` - Máximo de conexiones permitidas
- `mysql_global_status_uptime` - Tiempo de actividad del servidor

### Métricas de Redis
- `redis_keyspace_hits_total` - Total de hits en keyspace
- `redis_keyspace_misses_total` - Total de misses en keyspace
- `redis_commands_processed_total` - Comandos procesados
- `redis_memory_used_bytes` - Memoria utilizada
- `redis_memory_max_bytes` - Memoria máxima configurada
- `redis_connected_clients` - Clientes conectados
- `redis_command_duration_seconds` - Duración de comandos (histograma)
- `redis_db_keys` - Número de keys en la base de datos

### Métricas de Aplicación (cuando estén activas)
- `http_requests_total` - Total de requests HTTP
- `http_request_duration_seconds` - Duración de requests
- `barriofarma_sales_total` - Ventas registradas
- `barriofarma_inventory_level` - Niveles de inventario

## 🛠️ Troubleshooting

### Verificar que OTEL Collector está recibiendo datos

```bash
docker logs barriofarma-otel-collector
```

### Verificar que Prometheus está haciendo scraping

1. Accede a http://localhost:9090/targets
2. Verifica que los targets activos estén "UP"
3. El target `mariadb` debería estar "UP" si el exporter está funcionando
4. Los targets comentados (redis) aparecerán como DOWN hasta que se agreguen los exporters

### Verificar que MariaDB Exporter está funcionando

```bash
# Ver logs del exporter
docker logs barriofarma-mariadb-exporter

# Verificar que expone métricas
curl http://localhost:9104/metrics | grep mysql_global_status

# Verificar en Prometheus
curl 'http://localhost:9090/api/v1/query?query=mysql_global_status_queries'
```

### Crear Usuario de Monitoreo en MariaDB

Si necesitas recrear el usuario `exporter` en MariaDB:

```bash
# Ejecutar el script SQL dentro del contenedor db
docker-compose -f docker-compose.barriofarma.yml exec -T db mariadb -uroot -pbfdb123 < observability/mariadb-exporter/create-exporter-user.sql
```

El usuario `exporter` tiene permisos limitados:
- `PROCESS` - Para ver procesos y queries activas
- `REPLICATION CLIENT` - Para métricas de replicación
- `SELECT` - Para métricas de estado y variables del sistema
- `MAX_USER_CONNECTIONS 3` - Limita conexiones simultáneas

### Verificar que Loki está recibiendo logs

```bash
docker logs barriofarma-loki
docker logs barriofarma-promtail
```

### Verificar Datasources en Grafana

1. Accede a Grafana: http://localhost:3000
2. Ve a "Connections" → "Data sources"
3. Verifica que Prometheus y Loki estén configurados y funcionando

### Reiniciar el Stack

```bash
docker-compose -f docker-compose.observability.yml restart
```

### Detener el Stack

```bash
docker-compose -f docker-compose.observability.yml down
```

## 📚 Referencias

- [OpenTelemetry](https://opentelemetry.io/)
- [Prometheus](https://prometheus.io/)
- [Grafana](https://grafana.com/)
- [Loki](https://grafana.com/docs/loki/latest/)
- [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/)
- [Documentación Métricas BarrioFarma](../images/barriofarma/dev/OBSERVABILITY_USAGE.md)

## 🔐 Seguridad

⚠️ **Nota**: Esta configuración es para desarrollo. Para producción:
- Cambiar passwords por defecto de Grafana
- Habilitar autenticación en Prometheus
- Configurar TLS para todos los servicios
- Restringir acceso a los puertos expuestos

## ✅ Estado del Stack

### Funcionando Correctamente
- ✅ Grafana (puerto 3000)
- ✅ Prometheus (puerto 9090)
- ✅ Loki (puerto 3100)
- ✅ Promtail (recolectando logs)
- ✅ OTEL Collector (puerto 4317/4318)

### Pendiente de Configuración
- ⏳ Métricas del backend (requiere activación del endpoint `/metrics`)
- ⏳ Exporters de MariaDB (opcional, para métricas de DB)
- ⏳ Exporters de Redis (opcional, para métricas de cache/queue)
