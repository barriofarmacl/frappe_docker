# Configuracion MariaDB Cloud (SkySQL) para PoC Hybrid

Guia para usar MariaDB Cloud como base de datos del PoC en lugar de Cloud SQL for MySQL.

---

## 1. Formulario "Launch a Cloud Database"

### Type
- **Dejar: Serverless.** Adecuado para PoC; tier gratuito hasta 10 MCU-h/mes.
- Scale to zero when idle: **dejar marcado** para ahorrar cuando no uses el sitio.

### Cloud Provider
- **Dejar: Google Cloud** si quieres mantener todo en GCP.
- Region: **Oregon (us-west1)** esta bien; si prefieres menor latencia desde Chile, Virginia (us-east4) suele dar buenos resultados.

### Instance, storage
- **Min 1 MCU, Max 2 MCU:** correcto para PoC.
- **Scale to zero when idle:** activado.

### Service Attributes
- **Version: MariaDB Community Server 11.3.5.** Compatible con Frappe (requiere 10.6+).
- **Service Name:** Puedes usar `barriofarma-poc` o `fahelo-dev-axun` (max 24 caracteres, minusculas, numeros y guiones).

### Security
- **IP Allowlist:** Para PoC rapido puedes dejar **"Open to all 0.0.0.0/0"**. Para algo mas seguro: elegir **"Add my current IP"** y, una vez creado el servicio, anadir en el allowlist la IP publica de la maquina donde corre Docker (la misma que usaste con Cloud SQL, ej. 181.42.178.185/32).
- Tras crear el servicio podras anadir o quitar IPs desde la consola de MariaDB Cloud.

### Resumen y lanzamiento
- Revisa el panel derecho (Type, Provider, Location, Storage, Version, Billing).
- Pulsa **Launch Free**.

---

## 2. Despues del lanzamiento (modal "Connect to service")

1. En MariaDB Cloud, abre el servicio y el modal **"Connect to service"** (Primary Endpoint). Anota:
   - **Fully qualified domain name:** ej. `serverless-us-west1-sysp0000.db2.skysql.com` → sera `CLOUD_SQL_IP`.
   - **Read-write port:** ej. `4051` (no es 3306) → sera `DB_PORT`.
   - **Username:** ej. `dbpgf07012507` → sera `CLOUD_SQL_USER`.
   - **Default password:** (revelar y copiar) → sera `CLOUD_SQL_PASSWORD`.

2. **Certificate authority chain:** Pulsa **Download** y guarda el archivo como `./certs/server-ca.pem` en el directorio del PoC (frappe_docker). Si MariaDB Cloud entrega varios PEM, el que necesitas para verificar el servidor es la cadena CA (server/ca).

3. **Allowlist:** Si no usaste "Open to all", anade la IP publica de la maquina donde corre Docker en la seccion de IP Allowlist del servicio.

---

## 3. Usar este PoC con MariaDB Cloud

El mismo `docker-compose.hybrid-poc.yml` y `.env.hybrid` sirven. El compose ya soporta puerto y usuario configurables.

1. En **.env.hybrid** define (con los valores del modal "Connect to service"):
   - `CLOUD_SQL_IP=serverless-us-west1-sysp0000.db2.skysql.com` (tu FQDN del modal).
   - `DB_PORT=4051` (Read-write port del modal; no uses 3306).
   - `CLOUD_SQL_USER=dbpgf07012507` (tu Username del modal).
   - `CLOUD_SQL_PASSWORD=<pega la default password del modal>`.

2. **Certificados:** Pon el CA de MariaDB Cloud en `./certs/server-ca.pem`. Si MariaDB Cloud ofrece certificado cliente (mutual TLS), pon tambien `client-cert.pem` y `client-key.pem` en `./certs/`. El configurator ya copiara estos a `sites/ssl_certs/` y configurara `db_ssl_ca` / `db_ssl_cert` / `db_ssl_key`.

3. **Crear sitio desde cero:** Borra la base anterior si habia una (en MariaDB Cloud se gestiona desde la consola o no existira aun). Ejecuta con volumen limpio:
   ```bash
   docker-compose -f docker-compose.hybrid-poc.yml --env-file .env.hybrid down -v
   docker-compose -f docker-compose.hybrid-poc.yml --env-file .env.hybrid up -d
   docker-compose -f docker-compose.hybrid-poc.yml --env-file .env.hybrid logs -f configurator create-site
   ```

4. **Politica de contrasenas (simple_password_check):** MariaDB Cloud aplica una politica que rechaza contrasenas debiles. Al crear el sitio, Frappe crea un usuario de BD para el sitio; si la contrasena generada no cumple la politica, falla con error 1819. El compose ya pasa `--db-password` con una contrasena fuerte generada con `openssl rand -base64 24` (o la que definas en `SITE_DB_PASSWORD` en `.env.hybrid`). Opcional: en `.env.hybrid` puedes definir `SITE_DB_PASSWORD=<tu contrasena fuerte>` (minimo longitud y complejidad segun MariaDB Cloud).

5. **Ventaja con MariaDB 11.3:** No deberian hacer falta los parches de MyISAM ni TEXT default; el driver detectara MariaDB 11 y no mostrara el aviso de version. Si el servicio exige solo InnoDB, el parche de `ENGINE=InnoDB` en create-site no perjudica.

6. **Error 1044 (Access denied to database):** En MariaDB Cloud el usuario administrador no tiene permisos GRANT sobre bases creadas. Si create-site falla con `(1044, "Access denied for user '...' to database '...'")`, anade en `.env.hybrid` la linea `MARIADB_CLOUD_USE_ROOT_FOR_SITE=1`. El compose ya monta y ejecuta `scripts/patch_mariadb_cloud_setup_db.py` antes de `bench new-site`; con esa variable el script parchea `setup_database()` para que solo cree la base y use el mismo usuario (CLOUD_SQL_USER) para el sitio, sin CREATE USER ni GRANT. El sitio quedara usando las credenciales de CLOUD_SQL_USER/CLOUD_SQL_PASSWORD. Reinicia create-site con volumen limpio si ya habia fallado: `docker-compose ... down -v` y luego `up -d`.

---

## 4. Resumen de campos del formulario (recomendado PoC)

| Seccion        | Valor recomendado                          |
|----------------|--------------------------------------------|
| Type           | Serverless                                 |
| Cloud Provider | Google Cloud                               |
| Region         | Oregon (us-west1) o Virginia (us-east4)    |
| MCU            | Min 1, Max 2; Scale to zero: ON           |
| Version        | MariaDB Community Server 11.3.5           |
| Service Name   | barriofarma-poc (o el que prefieras)       |
| IP Allowlist   | Add my current IP (o Open to all solo PoC) |
| Accion         | Launch Free                                |
