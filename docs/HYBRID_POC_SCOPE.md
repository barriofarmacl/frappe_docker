# Alcance del PoC - Arquitectura Hibrida BarrioFarma (POC-001)

**Issue:** [whiteboard #46](https://github.com/barriofarmacl/whiteboard/issues/46)  
**Estado:** Sujeto a aprobacion del Arquitecto  
**Aprobado por:** [pendiente]

---

## Objetivo del PoC

Validar que Frappe/ERPNext en Docker Compose local puede utilizar **Cloud SQL (GCP)** como base de datos unica, con **Redis local** para cache y colas, de forma estable y con latencia aceptable para un entorno de desarrollo o validacion (no produccion).

## Dentro de alcance

- Conectividad a Cloud SQL desde el host/compose (puerto 3306, SSL).
- Creacion de sitio con `bench new-site` usando Cloud SQL como backend MariaDB/MySQL.
- Acceso a la UI (HTTP en puerto configurado, pagina de login).
- Login con usuario Administrator y verificacion de acceso al escritorio.
- Transaccion basica opcional: crear un Item o abrir un listado para validar lectura/escritura contra Cloud SQL.
- Documentacion de pasos de despliegue, checklist y resultados.

## Referencia: Base de datos recomendada por Frappe (y opciones en GCP)

Segun la documentacion oficial de Frappe (v14/v15):

- **Recomendado:** **MariaDB 10.6.6+** (backend principal soportado).
- **Alternativa soportada:** **PostgreSQL 12 a 14**.
- No se recomienda oficialmente MySQL 8; el stack esta pensado para MariaDB (por eso el aviso "MariaDB version 8.0 is less than 10.6" cuando se usa Cloud SQL MySQL 8).

**Opciones en GCP:**

| Opcion | Compatibilidad con Frappe | Notas |
|--------|----------------------------|--------|
| **Cloud SQL for MySQL** | Funcional con ajustes | No es MariaDB; requiere parches (ej. MyISAM deshabilitado -> uso de InnoDB en __global_search). Cloud SQL 2nd gen solo permite InnoDB. |
| **Cloud SQL for PostgreSQL** | Soportado (PostgreSQL 12-14) | Opcion managed nativa de GCP alineada con alternativas documentadas por Frappe. |
| **MariaDB en GCE (VM)** | Totalmente alineado | MariaDB 10.6+ instalado en una VM; maxima compatibilidad, mas trabajo operativo. |
| **MariaDB SkySQL (DBaaS en GCP)** | Totalmente alineado | Servicio gestionado de MariaDB sobre GCP; opcion si se prioriza MariaDB managed. |

Para este PoC se uso **Cloud SQL for MySQL 8** para validar conectividad y creacion de sitio con parches documentados; una fase posterior puede evaluar Cloud SQL for PostgreSQL o MariaDB en GCE/SkySQL segun requisitos de produccion.

**Opciones fuera de GCP (y forma recomendada por Frappe/ERPNext):**

| Opcion | Base de datos | Notas |
|--------|----------------|--------|
| **Frappe Cloud** (recomendacion oficial) | MariaDB en EC2 (gestionado por ellos) | Hosting oficial; no usan RDS/Cloud SQL; MariaDB en instancias EC2; AWS, DigitalOcean, OCI. |
| **AWS RDS for MariaDB** | MariaDB 10.6+ gestionado | Compatible con ERPNext; documentado en la comunidad; configurar parameter group (utf8mb4, collation); app en EC2 en la misma VPC. |
| **Azure Database for MariaDB** | MariaDB gestionado | Servicio gestionado en Azure; misma linea que MariaDB 10.6+. |
| **MariaDB en VM (cualquier cloud)** | MariaDB 10.6+ | EC2, DigitalOcean, OCI, GCE: instalar MariaDB en servidor separado; maxima compatibilidad y control; mas trabajo operativo. |
| **PostgreSQL 12-14 (cualquier cloud)** | PostgreSQL | Soportado por Frappe como alternativa; disponible en RDS, Cloud SQL, Azure, etc. |

La forma recomendada por Frappe para no gestionar infra es **Frappe Cloud**. Para self-hosted, la opcion mas alineada es **MariaDB 10.6+** (en VM o servicio gestionado como RDS/Azure) con arquitectura de dos capas: servidor de aplicacion + servidor de base de datos.

**MariaDB en GCE vs SkySQL (dentro de GCP):**

- **MariaDB en GCE:** Instalar y administrar MariaDB 10.6+ en una **maquina virtual de Google Compute Engine**. Tu equipo hace el install (paquetes, Docker o imagen del Marketplace), configuracion (utf8mb4, buffer pool, backups), parches y monitoreo. Ventaja: control total, sin dependencia de un proveedor de DBaaS; inconveniente: mas trabajo operativo (alta disponibilidad, replicas y backups son responsabilidad tuya). Ideal si ya tienes equipo DevOps y quieres todo el stack en GCP con MariaDB nativo.

- **SkySQL (ahora MariaDB Cloud):** Servicio **gestionado de MariaDB** ofrecido por MariaDB plc, que se despliega sobre GCP (y AWS/Azure). No es un producto de Google: es DBaaS de MariaDB que usa infra de GCP. Incluye aprovisionamiento, parches, backups, opciones de HA y escalado; se conecta a tu VPC en GCP (p. ej. via Private Service Connect). Ventaja: MariaDB “oficial” gestionado, compatible al 100% con Frappe; inconveniente: coste y dependencia de un tercero ademas de GCP. Util cuando se prioriza MariaDB gestionado sin operar la BD en GCE.

## Fuera de alcance (para este PoC)

- Alta disponibilidad (HA) de Cloud SQL o de la aplicacion.
- Multiples sedes o VPN site-to-site.
- Cloud SQL Auth Proxy (solo recomendaciones para siguiente fase).
- Uso en produccion; este PoC es solo validacion tecnica.
- Comparativa de rendimiento exhaustiva o pruebas de carga.

## Criterios de exito

| # | Criterio | Verificacion |
|---|----------|--------------|
| 1 | Conectividad a Cloud SQL desde el host/compose | Script `./scripts/test-cloudsql-connection.sh` pasa; puerto 3306 accesible |
| 2 | Sitio creado sin errores | Servicio `create-site` termina con exito; sitio `frontend` existe en `sites/` |
| 3 | UI accesible y login correcto | `curl -I http://localhost:8080` devuelve 200; login Administrator/admin OK |
| 4 | Latencia a BD documentada | Tiempo de conexion o latencia anotado en informe; umbral sugerido para PoC: < 200 ms |

## Checklist de despliegue (Fase 2)

Ejecutar en orden y marcar al completar:

- [x] **Terraform:** `cd terraform/hybrid-poc`, `terraform init`, `terraform plan`, `terraform apply` sin errores. (Apply completo 2025-02; proyecto barriofarma-dev; IP 35.222.68.184)
- [x] **Autorizar IP:** IP 181.42.178.185/32 agregada con `gcloud sql instances patch barriofarma-hybrid-poc-db --authorized-networks=181.42.178.185/32 --project=barriofarma-dev`.
- [x] **Variables:** `.env.hybrid` configurado con `CLOUD_SQL_IP=35.222.68.184` y credenciales.
- [x] **Certificados:** Certificados en `./certs/` (server-ca.pem, client-cert.pem, client-key.pem).
- [x] **Conectividad:** `./scripts/test-cloudsql-connection.sh` paso: ping, 3306, SSL, MySQL, BD barriofarma. Latencia medida: **813 ms** (por encima del umbral PoC 200 ms; aceptable para validacion, documentar en informe).
- [ ] **Compose:** Primera vez debe correr con volumen limpio para que create-site cree el sitio en Cloud SQL. Si el volumen tenia un sitio `frontend` de otro entorno (ej. devcontainer), create-site falla con "Access denied" (usuario del sitio no existe en Cloud SQL). Solucion: `docker-compose -f docker-compose.hybrid-poc.yml --env-file .env.hybrid down -v` y volver a `up`.

**Estado del despliegue (ultima verificacion):** Tras down -v y up, create-site fallo con `Access denied for user 'root'@'181.42.178.185'`. Causas probables: (1) Cloud SQL exige SSL: el configurator ahora escribe `db_ssl_ca`, `db_ssl_cert`, `db_ssl_key` en common_site_config si existen los certs en `./certs/`. (2) Password: `CLOUD_SQL_PASSWORD` en `.env.hybrid` debe coincidir exactamente con el `db_password` usado en Terraform (por defecto `bfdb123`).

### Troubleshooting: Access denied (root o usuario sitio)

- **Password:** Revisar que en `.env.hybrid` figure `CLOUD_SQL_PASSWORD=<mismo valor que db_password en Terraform>`, sin espacios ni comillas extra.
- **SSL:** Cloud SQL (ssl_mode ENCRYPTED_ONLY) rechaza conexiones sin TLS; el error puede mostrarse como "Access denied". Asegurar que `./certs/` tenga `server-ca.pem` (y opcionalmente `client-cert.pem`, `client-key.pem`). El configurator copia los certs a `sites/ssl_certs/` dentro del volumen para evitar PermissionError (Errno 13) cuando el usuario del contenedor no puede leer los archivos montados desde el host.
- **Usuario root en GCP:** En Cloud SQL, el usuario root con host `%` y la contraseña definida en Terraform debe existir; si se cambio la clave manualmente en GCP, actualizar `.env.hybrid` en consecuencia.

### Troubleshooting: 500 Internal Server Error y acceso por IP

- **Acceso por IP:** Para entrar por IP (ej. `http://172.17.141.190:8080`) definir en `.env.hybrid` la variable `SITE_HOST=172.17.141.190` (o la IP de la maquina). Si el sitio ya existia con `localhost`, actualizar y limpiar cache: `docker exec -it <backend-container> bench --site frontend set-config host_name <IP>; bench --site frontend clear-cache`.
- **500 no es por host_name:** Si tras configurar la IP sigue apareciendo Internal Server Error, la causa suele ser el estado del sitio en Cloud SQL, no el host.
- **Tablas faltantes (tabUser, Website Route Redirect) / Module Core not found:** La base del sitio en Cloud SQL puede haber quedado incompleta (tablas no creadas). Comprobar con `mysql -h $CLOUD_SQL_IP ... -e "SHOW TABLES FROM _HASH;"` (el nombre de la BD es el hash en `sites/frontend/site_config.json`, campo `db_name`). Si faltan tablas, recrear sitio desde cero:
  1. En Cloud SQL, borrar la base del sitio: `mysql ... -e "DROP DATABASE \`_5e5899d8398b5f7b\`;"` (usar el db_name real del site_config).
  2. Eliminar volumen de sitios y levantar de nuevo: `docker-compose -f docker-compose.hybrid-poc.yml --env-file .env.hybrid down -v` y luego `up -d` para que create-site cree un sitio nuevo.
- **bench migrate falla (ADD COLUMN IF NOT EXISTS):** Algunas versiones de MySQL 8 (Cloud SQL) pueden no aceptar la sintaxis usada por Frappe en migraciones. MySQL 8.0.29+ la soporta; si falla, documentar version exacta de Cloud SQL y considerar actualizar o parchear Frappe para compatibilidad.

### Troubleshooting: MyISAM disabled (Error 3161)

- **Causa:** Cloud SQL (2nd gen) no permite el motor MyISAM; Frappe crea la tabla `__global_search` con ENGINE=MyISAM por defecto.
- **Solucion aplicada:** El servicio `create-site` parchea antes de `bench new-site` el archivo `apps/frappe/frappe/database/mariadb/database.py` sustituyendo `ENGINE=MyISAM` por `ENGINE=InnoDB` en `create_global_search_table`. InnoDB soporta FULLTEXT en MySQL 5.6+.
- **Nota:** El aviso "MariaDB version 8.0 is less than 10.6" aparece porque Frappe detecta MySQL 8 como MariaDB; el fallo real era MyISAM. No es necesario cambiar la version de Cloud SQL.

### Troubleshooting: MariaDB Cloud - Access denied to database (Error 1044)

- **Causa:** En MariaDB Cloud (SkySQL) el usuario administrador no tiene privilegios GRANT sobre bases creadas; `bench new-site` falla en `grant_all_privileges` con `(1044, "Access denied for user '...' to database '...'"`.
- **Solucion aplicada:** Definir en `.env.hybrid` la variable `MARIADB_CLOUD_USE_ROOT_FOR_SITE=1`. El compose monta `scripts/patch_mariadb_cloud_setup_db.py`, que se ejecuta antes de `bench new-site` y parchea `setup_database()` para que solo ejecute CREATE DATABASE y use el mismo usuario (root) para el sitio, sin CREATE USER ni GRANT. El sitio queda configurado con las credenciales de `CLOUD_SQL_USER`/`CLOUD_SQL_PASSWORD`. Ver [MARIADB_CLOUD_POC_SETUP.md](MARIADB_CLOUD_POC_SETUP.md).

---

## Parches aplicados en el PoC (Cloud SQL for MySQL)

Resumen de los cambios en el compose y la configuracion para que Frappe funcione con Cloud SQL (MySQL 8, solo InnoDB, SSL obligatorio):

| # | Donde | Que se hace | Motivo |
|---|--------|-------------|--------|
| 1 | **configurator** (compose) | Copia de `/certs/*.pem` a `sites/ssl_certs/` como root; `chown 1000:1000 sites`; `bench set-config -g db_ssl_ca/cert/key` con rutas a `sites/ssl_certs/`. Ejecucion de `bench` con `runuser -u frappe`. | Cloud SQL exige SSL; el usuario del contenedor no puede leer certs montados desde el host; evitar "Permission denied" y "run as root" en bench. |
| 2 | **create-site** (compose) | `sed -i 's/ENGINE=MyISAM/ENGINE=InnoDB/' apps/frappe/frappe/database/mariadb/database.py` antes de `bench new-site`. | Cloud SQL 2nd gen no permite MyISAM (Error 3161); la tabla `__global_search` se crea con InnoDB. |
| 3 | **create-site** (compose) | Uso de `SITE_HOST` en `bench set-config host_name` (por defecto `localhost`). | Permitir acceso por IP (ej. `SITE_HOST=172.17.141.190` en `.env.hybrid`). |
| 4 | **create-site** (compose) | Si `MARIADB_CLOUD_USE_ROOT_FOR_SITE=1`: montaje de `scripts/patch_mariadb_cloud_setup_db.py` y ejecucion antes de `bench new-site`. | MariaDB Cloud no otorga GRANT al usuario administrador (error 1044); el parche hace solo CREATE DATABASE y usa el mismo usuario para el sitio. |

No se aplica parche previo para `bench migrate` (ADD COLUMN IF NOT EXISTS); si en el futuro una migracion falla por sintaxis MySQL, se documentara y se evaluara parche o version de Cloud SQL.

---

## Pruebas de validacion (Fase 3)

| ID | Prueba | Criterio de paso | Resultado |
|----|--------|------------------|-----------|
| P1 | Conectividad Cloud SQL | `./scripts/test-cloudsql-connection.sh` OK; latencia 813 ms (WARN >200 ms) | OK (latencia alta documentada) |
| P2 | Creacion de sitio | Logs de `create-site` sin error de BD; sitio `frontend` presente | Pendiente |
| P3 | Acceso UI | `curl -I http://localhost:8080` devuelve 200; login page accesible | Pendiente |
| P4 | Login | Administrator / admin; se llega al escritorio o primera pantalla post-login | Pendiente |
| P5 | Transaccion basica (opcional) | Crear Item o abrir listado; lectura/escritura contra Cloud SQL OK | Pendiente |

Resultados detallados y recomendacion go/no-go: ver [HYBRID_POC_REPORT.md](HYBRID_POC_REPORT.md).
