# Alcance del PoC - MariaDB en GCE VM (POC-002)

**Relacion:** Sucesor de POC-001 (Cloud SQL / MariaDB Cloud).  
**Estado:** Sujeto a aprobacion del Arquitecto  
**Aprobado por:** [pendiente]

---

## Objetivo del PoC

Validar que Frappe/ERPNext en Docker Compose local puede utilizar **MariaDB 10.6 en una VM GCE** (southamerica-west1, Santiago) como base de datos unica, con Redis local, de forma estable y con latencia minima, **sin parches de compatibilidad** (MariaDB 10.6 es la BD recomendada por Frappe).

## Motivacion respecto a POC-001

- POC-001 con Cloud SQL MySQL 8 requeria parches (MyISAM, deteccion de version).
- POC-001 con MariaDB Cloud (SkySQL) requeria parches de GRANT/db_user y el tier minimo excedia el presupuesto; latencia desde Chile a us-central1 era alta (~813 ms).
- POC-002 con **MariaDB 10.6 en GCE** en southamerica-west1 elimina parches y reduce latencia (estimada 5-15 ms).

## Dentro de alcance

- VM e2-standard-2 en GCP (southamerica-west1) con MariaDB 10.6 instalado via startup script.
- Conectividad desde el host/compose al puerto 3306 de la VM (firewall restringido a IP autorizada).
- Creacion de sitio con `bench new-site` usando el flujo estandar de Frappe (CREATE USER hash + GRANT); sin `MARIADB_CLOUD_USE_ROOT_FOR_SITE` ni script de parche.
- Acceso a la UI (HTTP en puerto configurado, pagina de login).
- Login con usuario Administrator y verificacion de acceso al escritorio.
- Transaccion basica opcional: crear un Item o abrir un listado.
- Documentacion de pasos de despliegue, checklist y resultados.
- Snapshot semanal del disco de la VM para respaldo.

## Fuera de alcance

- Alta disponibilidad (HA) de la VM o de la aplicacion.
- Multiples sedes o VPN site-to-site.
- TLS obligatorio en MariaDB (la VM acepta conexiones sin SSL por defecto; SSL se puede anadir despues).
- Uso en produccion; este PoC es solo validacion tecnica.
- Comparativa de rendimiento exhaustiva o pruebas de carga.

## Criterios de exito

| # | Criterio | Verificacion |
|---|----------|--------------|
| 1 | VM creada y MariaDB escuchando | `mariadb -h <IP> -u root -p -e "SELECT VERSION();"` devuelve 10.6.x |
| 2 | Conectividad desde compose | Servicio create-site alcanza DB_HOST:3306 |
| 3 | Sitio creado sin errores | Servicio `create-site` termina con exito; sitio `frontend` existe en `sites/` |
| 4 | UI accesible y login correcto | `curl -I http://localhost:8080` devuelve 200; login Administrator/admin OK |
| 5 | Latencia a BD documentada | Tiempo de conexion o latencia anotado; umbral sugerido: < 100 ms (region local) |

## Checklist de despliegue

Ejecutar en orden y marcar al completar:

- [ ] **Terraform:** `cd frappe_docker/terraform/hybrid-poc-vm`, `terraform init`, `terraform plan`, `terraform apply` sin errores.
- [ ] **Autorizar IP:** Configurar `authorized_ip` en Terraform (ej. `-var="authorized_ip=TU_IP/32"`) o aplicar despues con regla de firewall manual. Sin esto, el puerto 3306 no sera accesible desde tu IP.
- [ ] **Esperar startup:** Tras el apply, esperar 5-10 minutos para que el startup script de la VM instale y configure MariaDB.
- [ ] **Variables:** Copiar `.env.hybrid-vm.example` a `.env.hybrid-vm`. Asignar `CLOUD_SQL_IP=$(terraform output -raw mariadb_public_ip)` y `CLOUD_SQL_PASSWORD` igual al `db_password` de Terraform.
- [ ] **Conectividad:** `mariadb -h $(terraform output -raw mariadb_public_ip) -u root -p -e "SELECT VERSION();"` debe devolver MariaDB 10.6.x.
- [ ] **Compose:** Primera vez con volumen limpio: `docker-compose -f docker-compose.hybrid-poc-vm.yml --env-file .env.hybrid-vm down -v` y luego `docker-compose -f docker-compose.hybrid-poc-vm.yml --env-file .env.hybrid-vm up -d`. Seguir logs de create-site hasta "Sitio creado exitosamente".
- [ ] **Frontend:** Si el backend tarda en pasar healthy, recrear frontend: `docker-compose -f docker-compose.hybrid-poc-vm.yml --env-file .env.hybrid-vm up -d --force-recreate frontend`.

## Arquitectura de archivos POC-002

| Componente | Ruta |
|------------|------|
| Terraform (VM, disco, firewall, snapshot) | `terraform/hybrid-poc-vm/main.tf` |
| Startup script MariaDB 10.6 | `terraform/hybrid-poc-vm/scripts/mariadb-setup.sh` |
| Compose (sin parches GRANT) | `docker-compose.hybrid-poc-vm.yml` |
| Env template | `.env.hybrid-vm.example` |
| Alcance y checklist | `docs/HYBRID_POC_VM_SCOPE.md` (este archivo) |

## Diferencias con el compose POC-001 (MariaDB Cloud)

- No se monta `scripts/patch_mariadb_cloud_setup_db.py` en create-site ni en los servicios de runtime.
- No existe la variable `MARIADB_CLOUD_USE_ROOT_FOR_SITE`.
- Backend, scheduler, websocket y workers no tienen entrypoint wrapper; usan el CMD por defecto de la imagen.
- create-site solo aplica el `sed` MyISAM -> InnoDB como precaucion (MariaDB 10.6 soporta MyISAM; InnoDB es mas robusto).
- Healthcheck del backend conserva `Host: frontend` para resolucion de sitio.
- Puerto por defecto 3306.

## Troubleshooting

### Access denied (1045) desde el host

- **Password:** `CLOUD_SQL_PASSWORD` en `.env.hybrid-vm` debe coincidir con el `db_password` pasado a Terraform (por defecto `bfdb123`).
- **Firewall:** Si `authorized_ip` esta vacio, la regla de firewall no se crea; ninguna IP podra conectar a 3306. Añadir con `-var="authorized_ip=TU_IP/32"` y `terraform apply`, o crear una regla manual en GCP que permita 3306 desde tu IP al tag `barriofarma-mariadb`.

### La VM no responde en 3306

- El startup script tarda varios minutos (instalacion de paquetes, reinicio de MariaDB). Comprobar en GCP Console > Compute Engine > VM > Ver serial output para ver el progreso del script.
- Comprobar que MariaDB esta en marcha en la VM: `gcloud compute ssh barriofarma-hybrid-poc-vm-mariadb --zone=southamerica-west1-a --command="systemctl status mariadb"`.

### create-site falla con "Database already exists" o usuario hash

- Si el volumen de sitios tenia un sitio previo (de otra PoC), borrar la base del sitio en MariaDB: `mariadb -h <IP> -u root -p -e "DROP DATABASE \`_HASH\`;"` (reemplazar _HASH por el `db_name` de `sites/frontend/site_config.json` si existe).
- Luego `docker-compose ... down -v` y `up -d` de nuevo.

### Backend unhealthy o frontend no carga

- Verificar que create-site termino correctamente (logs del contenedor create-site).
- Healthcheck del backend usa `Host: frontend`; si el backend esta Up pero unhealthy, comprobar con `docker exec <backend> curl -f -H "Host: frontend" http://localhost:8000/api/method/ping`.
- Si el frontend no resuelve el backend (nginx "host not found in upstream"), recrear el frontend despues de que el backend este healthy.

## Pruebas de validacion

| ID | Prueba | Criterio de paso | Resultado |
|----|--------|------------------|-----------|
| P1 | Conectividad VM MariaDB | `mariadb -h <IP> -u root -p -e "SELECT VERSION();"` OK | Pendiente |
| P2 | Creacion de sitio | Logs de create-site sin error; sitio `frontend` presente | Pendiente |
| P3 | Acceso UI | `curl -I http://localhost:8080` devuelve 200 | Pendiente |
| P4 | Login | Administrator / admin; acceso al escritorio | Pendiente |
| P5 | Transaccion basica (opcional) | Crear Item o listado; lectura/escritura OK | Pendiente |

Resultados detallados y recomendacion go/no-go: documentar en informe o en este archivo tras la ejecucion.
