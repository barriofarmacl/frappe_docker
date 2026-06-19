# 🚀 Instrucciones para Ejecutar BarrioFarma con Docker Compose

**Fecha:** 10 de Noviembre de 2025  
**Imagen:** bf-app-dev:0.0.1-otel  
**Archivo:** docker-compose.barriofarma.yml

---

## 📋 Requisitos Previos

1. ✅ Imagen `bf-app-dev:0.0.1-otel` construida (con `apps.json` y `APPS_JSON_BASE64`)
2. ✅ Docker Compose instalado
3. ✅ Puerto 8080 libre (frontend)
4. ✅ Puerto 3307 libre (MariaDB - para DBeaver)

---

## 🚀 Paso 1: Levantar los Servicios

```bash
cd /home/faelo/barriofarmacl/frappe_docker

# Levantar todos los servicios
docker-compose -f docker-compose.barriofarma.yml up -d
```

**Servicios que se levantarán:**
1. `db` - MariaDB 11.8
2. `redis-cache` - Redis 7.2 para cache
3. `redis-queue` - Redis 7.2 para queues
4. `configurator` - Configura common_site_config.json
5. `create-site` - Crea el sitio `frontend` con MariaDB
6. `backend` - Servidor Gunicorn
7. `frontend` - Nginx
8. `websocket` - SocketIO
9. `scheduler` - Tareas programadas
10. `queue-short` - Worker queue short
11. `queue-long` - Worker queue long

---

## 🔍 Paso 2: Monitorear el Levantamiento

```bash
# Ver logs en tiempo real
docker-compose -f docker-compose.barriofarma.yml logs -f

# Ver solo logs de create-site (importante)
docker-compose -f docker-compose.barriofarma.yml logs -f create-site

# Ver estado de servicios
docker-compose -f docker-compose.barriofarma.yml ps
```

**Orden de ejecución:**
1. `db` (MariaDB), `redis-cache`, `redis-queue` → Se levantan primero
2. `configurator` → Crea common_site_config.json con configuración MariaDB
3. `create-site` → Crea el sitio `frontend` con `--mariadb-user-host-login-scope='%'` (puede tardar 5-10 minutos)
4. `backend`, `frontend`, `websocket`, `scheduler`, `queues` → Se levantan después

**Nota importante:** El flag `--mariadb-user-host-login-scope='%'` asegura que el usuario de la base de datos se cree con acceso desde cualquier IP del contenedor, evitando errores de `Access denied`.

---

## ✅ Paso 3: Verificar que Funciona

### Acceder al Frontend

```bash
# Esperar a que termine create-site
# Luego abrir en navegador:
http://localhost:8080

# Credenciales:
Usuario: Administrator
Password: admin
```

### Verificar Backend

```bash
curl http://localhost:8080/api/method/ping
```

**Respuesta esperada:**
```json
{"message":"pong"}
```

---

## 🗄️ Paso 4: Conectar DBeaver a MariaDB

### Configuración de Conexión

```yaml
Connection Type: MariaDB / MySQL
Host: localhost
Port: 3307  # Puerto expuesto en el host (mapea a 3306 interno)
Database: <NOMBRE_HASH>  # Lo obtenemos después
Username: root
Password: bfdb123
```

**Nota para Windows + WSL:**
Si ejecutas Docker desde WSL y DBeaver en Windows, necesitas crear un túnel con `socat`:

```bash
# En WSL, crear túnel temporal
docker run --rm -p 3307:3306 --network frappe_docker_devcontainer_default \
  alpine/socat tcp-listen:3306,fork,reuseaddr tcp:frappe_docker-db-1:3306
```

Luego conecta DBeaver a `localhost:3307`.

### Obtener el Nombre de la Database

```bash
# Ejecutar dentro del container backend
docker-compose -f docker-compose.barriofarma.yml exec backend bash

# Dentro del container:
cd /home/frappe/frappe-bench
bench --site frontend show-config | grep db_name
```

**Output esperado:**
```json
"db_name": "_5e5899d8398b5f7b"  # Hash del sitio
```

**Usar ese nombre** en DBeaver como "Database".

---

## 🛠️ Comandos Útiles

### Ver todos los servicios

```bash
docker-compose -f docker-compose.barriofarma.yml ps
```

### Acceder al container backend

```bash
docker-compose -f docker-compose.barriofarma.yml exec backend bash

# Dentro:
cd /home/frappe/frappe-bench
bench list-apps
bench --site barriofarma.localhost migrate
```

### Ver logs específicos

```bash
# Backend
docker-compose -f docker-compose.barriofarma.yml logs -f backend

# Database
docker-compose -f docker-compose.barriofarma.yml logs -f db

# Todos
docker-compose -f docker-compose.barriofarma.yml logs -f
```

### Detener servicios

```bash
# Detener sin eliminar volúmenes
docker-compose -f docker-compose.barriofarma.yml down

# Detener y eliminar volúmenes (CUIDADO: borra datos)
docker-compose -f docker-compose.barriofarma.yml down -v
```

### Reiniciar un servicio específico

```bash
docker-compose -f docker-compose.barriofarma.yml restart backend
```

---

## ⚠️ Troubleshooting

### create-site falla

**Síntoma:** Service create-site termina con error

**Verificar:**
```bash
docker-compose -f docker-compose.barriofarma.yml logs create-site
```

**Causas comunes:**
- MariaDB no está listo → Esperar más tiempo (healthcheck con `mariadb-admin ping`)
- Site ya existe → Eliminar volumen `sites` y recrear
- Apps no se instalaron → Verificar `apps.json` y `APPS_JSON_BASE64` en build
- Error `Access denied` → Verificar que `create-site` use `--mariadb-user-host-login-scope='%'`

### Frontend no responde

**Verificar:**
```bash
# Backend debe estar running
docker-compose -f docker-compose.barriofarma.yml ps backend

# Ver logs de frontend
docker-compose -f docker-compose.barriofarma.yml logs frontend
```

### DBeaver no conecta

**Verificar:**
```bash
# MariaDB debe estar expuesto en 3307
docker-compose -f docker-compose.barriofarma.yml ps db

# Test de conexión desde el host
docker-compose -f docker-compose.barriofarma.yml exec db mariadb -uroot -pbfdb123 -e "SELECT VERSION();"

# Verificar que el puerto está escuchando
docker-compose -f docker-compose.barriofarma.yml port db 3306
```

**Si estás en Windows + WSL:**
- Verifica que el túnel `socat` esté corriendo
- Conecta a `localhost:3307` (no `localhost:3306`)

---

## 🔄 Recrear desde Cero

Si algo falla y quieres empezar de nuevo:

```bash
# 1. Detener y eliminar todo
docker-compose -f docker-compose.barriofarma.yml down -v

# 2. Verificar que los volúmenes se eliminaron
docker volume ls | grep frappe_docker

# 3. Levantar de nuevo
docker-compose -f docker-compose.barriofarma.yml up -d

# 4. Monitorear
docker-compose -f docker-compose.barriofarma.yml logs -f create-site
```

---

## 📊 Diferencias vs pwd.yml Original

| Aspecto | pwd.yml | barriofarma.yml |
|---------|---------|-----------------|
| **Imagen** | frappe/erpnext:v15.83.2 | bf-app-dev:0.0.1-otel |
| **Database** | MariaDB 10.6 | MariaDB 11.8 |
| **Puerto DB** | 3306 (interno) | 3307:3306 (expuesto en host) |
| **Site name** | frontend | frontend |
| **DB Password** | admin | bfdb123 |
| **DB Root User** | root | root |
| **Apps** | frappe + erpnext | frappe + erpnext + barriofarma_app |
| **DB Type** | MariaDB | MariaDB |
| **Redis** | 6.2-alpine | 7.2-alpine |
| **Healthcheck** | mysqladmin ping | mariadb-admin ping |
| **User Scope** | `--mariadb-user-host-login-scope='%'` | `--mariadb-user-host-login-scope='%'` ✅ |

---

## ✅ Checklist de Verificación

Después de levantar, verificar:

- [ ] MariaDB running (puerto 3307 expuesto en host, 3306 interno)
- [ ] MariaDB healthcheck passing (`mariadb-admin ping`)
- [ ] Redis cache running (7.2-alpine)
- [ ] Redis queue running (7.2-alpine)
- [ ] Configurator completó exitosamente
- [ ] Create-site completó exitosamente (con flag `--mariadb-user-host-login-scope='%'`)
- [ ] Backend running (sin errores `Access denied` en logs)
- [ ] Frontend running (puerto 8080)
- [ ] WebSocket running
- [ ] Scheduler running
- [ ] Queue workers running
- [ ] DBeaver conecta a MariaDB (localhost:3307, root/bfdb123)
- [ ] Login funciona en http://localhost:8080 (Administrator/admin)

---

## 🔧 Construcción de la Imagen Personalizada

Antes de levantar el stack, asegúrate de construir la imagen `bf-app-dev:0.0.1-otel`:

```bash
cd /home/faelo/barriofarmacl/frappe_docker

# 1. Crear apps.json desde el ejemplo
cp development/apps-example.json apps.json

# 2. Codificar en base64
export APPS_JSON_BASE64=$(base64 -w 0 apps.json)

# 3. Construir la imagen
docker build -f images/barriofarma/dev/Containerfile \
  --build-arg APPS_JSON_BASE64=$APPS_JSON_BASE64 \
  -t bf-app-dev:0.0.1-otel .
```

**Nota:** La imagen incluye automáticamente `erpnext` y `barriofarma_app` gracias a `APPS_JSON_BASE64`.

---

## ⚠️ Notas Importantes sobre MariaDB 11.8

- **Versión no certificada:** Frappe Framework muestra un warning sobre MariaDB 11.8 siendo más nueva que la versión certificada (10.8). Es seguro ignorarlo en desarrollo.
- **Flag `--mariadb-user-host-login-scope='%'`:** Este flag asegura que el usuario de la base se cree con acceso desde cualquier IP del contenedor, evitando errores de `Access denied` cuando el backend se conecta desde una IP diferente a la del contenedor `create-site`.
- **Puerto 3307:** Se usa `3307:3306` para evitar conflictos con posibles instancias de MySQL/MariaDB corriendo en el host en el puerto 3306.

---

**Archivo:** `/home/faelo/barriofarmacl/frappe_docker/docker-compose.barriofarma.yml`  
**Última actualización:** 10 de Noviembre 2025  
**Listo para ejecutar.** 🚀

