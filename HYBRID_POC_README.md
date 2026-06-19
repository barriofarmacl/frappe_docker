# PoC Arquitectura Hibrida - BarrioFarma

## Alcance del PoC

Este PoC valida que Frappe/ERPNext en Docker local pueda usar Cloud SQL (GCP) como BD unica con Redis local, de forma estable y con latencia aceptable. Quedan fuera de alcance: HA, multiples sedes, Auth Proxy y uso en produccion. Objetivos, criterios de exito y checklist: [docs/HYBRID_POC_SCOPE.md](docs/HYBRID_POC_SCOPE.md).

## Descripcion

Este PoC implementa una arquitectura hibrida donde:

- **Cloud SQL (GCP)**: Base de datos MySQL centralizada en la nube
- **Redis (Local)**: Cache y colas locales para baja latencia
- **Frappe/ERPNext (Local)**: Aplicacion completa en Docker Compose

```
+------------------+          +---------------------------+
|      GCP         |          |   Docker Compose Local    |
|                  |          |                           |
|  +------------+  |  TLS     |  +-------+  +-------+    |
|  | Cloud SQL  |<-|----------|->| Redis |  | Redis |    |
|  | MySQL 8.0  |  |  3306    |  | Cache |  | Queue |    |
|  +------------+  |          |  +-------+  +-------+    |
|                  |          |       |          |       |
+------------------+          |  +----+----------+----+  |
                              |  |                    |  |
                              |  |  Frappe/ERPNext    |  |
                              |  |  - backend         |  |
                              |  |  - frontend        |  |
                              |  |  - workers         |  |
                              |  |  - scheduler       |  |
                              |  |  - websocket       |  |
                              |  +--------------------+  |
                              +---------------------------+
```

## Prerequisitos

1. **GCP Project** con APIs habilitadas:
   ```bash
   gcloud services enable sqladmin.googleapis.com
   gcloud services enable compute.googleapis.com
   ```

2. **Terraform** >= 1.0

3. **Docker** y **Docker Compose** v2

4. **gcloud CLI** autenticado

## Despliegue

Checklist de despliegue y estado de la ultima verificacion: [docs/HYBRID_POC_SCOPE.md](docs/HYBRID_POC_SCOPE.md).

### Paso 1: Crear Cloud SQL con Terraform

```bash
cd frappe_docker/terraform/hybrid-poc

# Inicializar Terraform
terraform init

# Revisar plan
terraform plan

# Opcional: autorizar tu IP desde el principio (evita 0.0.0.0/0 que la API puede rechazar)
# terraform apply -var='authorized_networks=[{name="poc",value="TU_IP_PUBLICA/32"}]'

# Aplicar (crear Cloud SQL)
terraform apply
```

Si no pasaste `authorized_networks`, tras el apply agrega tu IP: `gcloud sql instances patch barriofarma-hybrid-poc-db --authorized-networks=TU_IP/32` (ver Troubleshooting).

Esperar ~10 minutos para que Cloud SQL se cree.

### Paso 2: Obtener IP y configurar .env

```bash
# Obtener IP publica
terraform output database_public_ip

# Volver al directorio principal
cd ../..

# Copiar template
cp .env.hybrid.example .env.hybrid

# Editar con la IP obtenida
nano .env.hybrid
```

### Paso 3: Descargar Certificados SSL (Recomendado)

**Opción A: Script automatizado (recomendado)**

```bash
# Desde el directorio frappe_docker/
./scripts/download-cloudsql-certs.sh

# O especificar instancia manualmente
./scripts/download-cloudsql-certs.sh barriofarma-hybrid-poc-db
```

**Opción B: Manual con Terraform**

```bash
# Crear directorio
mkdir -p certs
cd certs

# Descargar certificados (ejecutar desde terraform/hybrid-poc)
cd ../terraform/hybrid-poc
terraform output ssl_cert_download_commands
# Ejecutar los comandos mostrados

# Mover certificados
mv *.pem ../../certs/
cd ../..

# Proteger archivos
chmod 600 certs/*.pem
```

**Opción C: Comandos gcloud directos**

```bash
# Crear directorio
mkdir -p certs
cd certs

# 1. Crear certificado de cliente
gcloud sql ssl-certs create client-cert \
  --instance=barriofarma-hybrid-poc-db \
  --format="value(cert)" > client-cert.pem

# 2. Obtener clave privada
gcloud sql ssl-certs describe client-cert \
  --instance=barriofarma-hybrid-poc-db \
  --format="value(privateKey)" > client-key.pem

# 3. Obtener certificado CA del servidor
gcloud sql instances describe barriofarma-hybrid-poc-db \
  --format="value(serverCaCert.cert)" > server-ca.pem

# 4. Proteger archivos
chmod 600 client-key.pem client-cert.pem server-ca.pem
```

### Paso 4: Validar Conectividad

```bash
chmod +x scripts/test-cloudsql-connection.sh
./scripts/test-cloudsql-connection.sh
```

### Paso 5: Levantar Docker Compose

```bash
# Primera vez (crea el sitio)
docker compose -f docker-compose.hybrid-poc.yml --env-file .env.hybrid up

# Siguientes veces (sin crear sitio)
docker compose -f docker-compose.hybrid-poc.yml --env-file .env.hybrid up -d
```

### Paso 6: Acceder a la Aplicacion

- URL: http://localhost:8080
- Usuario: Administrator
- Password: admin

## Costos Estimados

| Componente | Costo/mes |
|------------|-----------|
| Cloud SQL db-f1-micro | ~$8-10 |
| Egress datos | ~$2-5 |
| **Total GCP** | **~$10-15** |
| Docker Compose local | $0 |

## Seguridad

### Para PoC (actual)

- Cloud SQL acepta conexiones de cualquier IP (`0.0.0.0/0`)
- SSL obligatorio pero sin verificacion de cliente

### Para Produccion (recomendado)

1. Restringir `authorized_networks` a IPs conocidas:
   ```terraform
   authorized_networks = [
     { name = "sede-santiago", value = "200.x.x.x/32" },
     { name = "sede-valparaiso", value = "190.x.x.x/32" }
   ]
   ```

2. Usar Cloud SQL Auth Proxy en lugar de IP publica

3. Usar Secret Manager para credenciales

## Troubleshooting

### Error: No se puede conectar a Cloud SQL

1. Verificar IP publica actual:
   ```bash
   curl ifconfig.me
   ```

2. Verificar que la IP este autorizada en Cloud SQL:
   ```bash
   gcloud sql instances describe barriofarma-hybrid-poc-db \
     --format="value(settings.ipConfiguration.authorizedNetworks)"
   ```

3. Agregar IP si es necesario:
   ```bash
   gcloud sql instances patch barriofarma-hybrid-poc-db \
     --authorized-networks=TU_IP/32
   ```

### Error: Connection timeout

- Verificar latencia con el script de test
- Si latencia > 200ms, considerar region de Cloud SQL mas cercana

### Error: SSL certificate verify failed

- Verificar que los certificados esten en `./certs/`
- Verificar permisos: `chmod 600 certs/*.pem`

## Limpieza

```bash
# Eliminar contenedores
docker compose -f docker-compose.hybrid-poc.yml down -v

# Eliminar Cloud SQL (CUIDADO: elimina datos)
cd terraform/hybrid-poc
terraform destroy
```

## Siguiente Paso: Produccion

Si el PoC es exitoso, considerar:

1. **Cloud SQL Auth Proxy** en lugar de IP publica
2. **VPN site-to-site** para multiples sedes
3. **Backups automaticos** con retencion adecuada
4. **Monitoreo** con Cloud Monitoring + Grafana
5. **Alta disponibilidad** con Cloud SQL HA

## Lecciones aprendidas

*(Completar tras ejecutar el PoC y registrar en [docs/HYBRID_POC_REPORT.md](docs/HYBRID_POC_REPORT.md).)*

- **Que funciono bien:** Integracion Cloud SQL + Compose, script de certificados, separacion Redis local vs BD en cloud (ejemplos; rellenar con hallazgos reales).
- **Problemas encontrados:** Autorizacion de IP en Cloud SQL, compatibilidad MySQL 8.0 vs MariaDB si aplica, tiempos de creacion de sitio (ejemplos; rellenar tras validacion).
- **Recomendaciones para produccion:** Restringir `authorized_networks`, usar Cloud SQL Auth Proxy, Secret Manager para credenciales, backups y monitoreo (alineado con seccion Seguridad arriba).
