# BarrioFarma - Entorno de Desarrollo

Este directorio contiene las herramientas y configuración para el entorno de desarrollo de BarrioFarma.

## Contenido

- `.cursor/`: **Git submodule** → [barriofarma-methodology](https://github.com/barriofarmacl/barriofarma-methodology) (reglas, docs, `openspec/`, `.agents/`, `.atl/`). Tras clonar: `git submodule update --init --recursive`. Onboarding: `.cursor/docs/submodule_onboarding.md`.
- **Documentación de apoyo del monorepo** (topología repos, PRDs, sprint-artifacts, `bf_docs`, etc.): ya no se mantiene en rutas bajo `development/`; el volcado está en **Engram** (proyecto `barriofarma`, claves `topic_key` tipo `archive/docs/...` / `archive/bf_docs/...`). Recuperar con `engram search "<término>" --project barriofarma` o MCP `mem_search`.
- `e2e/barriofarma-cypress/`: plantilla para publicar `barriofarma-e2e`.
- `installer.py`: Script para inicializar el bench de Frappe y crear sitios
- `apps-example.json`: Configuración de apps a instalar (ERPNext, barriofarma_app)
- `vscode-example/`: Configuración de VSCode para debugging y tareas
- `frappe-bench/`: Bench generado por el installer (no versionado, gitignored)

## Setup Inicial

### 1. Instalar el Bench

El script `installer.py` automatiza la creación del bench y la configuración inicial:

```bash
python3 installer.py
```

**Parámetros disponibles:**

- `-j, --apps-json`: Ruta al archivo JSON de apps (default: `apps-example.json`)
- `-b, --bench-name`: Nombre del directorio del bench (default: `frappe-bench`)
- `-s, --site-name`: Nombre del sitio (default: `development.localhost`)
- `-r, --frappe-repo`: Repositorio de Frappe (default: `https://github.com/frappe/frappe`)
- `-t, --frappe-branch`: Rama de Frappe (default: `version-15`)
- `-p, --py-version`: Versión de Python (opcional)
- `-n, --node-version`: Versión de Node.js (opcional)
- `-v, --verbose`: Salida detallada
- `-a, --admin-password`: Contraseña del admin (default: `admin`)
- `-d, --db-type`: Tipo de base de datos (`mariadb` o `postgres`, default: `mariadb`)

**Ejemplo:**

```bash
python3 installer.py -s mi-sitio.localhost -a mi-password -d mariadb
```

### 2. Configuración del Bench

El installer configura automáticamente:

- Redis (cache, queue, socketio) con timeouts para evitar desconexiones
- Base de datos (MariaDB o PostgreSQL) según el parámetro `--db-type`
- Modo desarrollador (`developer_mode = 1`)

**Nota:** El installer asume que los servicios de base de datos y Redis están disponibles (pueden estar en Docker usando `docker-compose.barriofarma.yml` del repo root).

### 3. Configuración de VSCode

Para configurar VSCode para debugging:

```bash
cp -R vscode-example .vscode
```

Esto configura:
- Launch configurations para Bench Web, Workers (short, default, long), Scheduler
- Tasks para limpiar procesos Honcho

## Estructura del Bench

El bench se crea en `frappe-bench/` (o el nombre especificado con `-b`) y contiene:

- `apps/`: Aplicaciones instaladas (frappe, erpnext, barriofarma_app)
- `sites/`: Sitios creados
- `env/`: Entorno virtual de Python
- `config/`: Configuración del bench

## Apps Instaladas

Por defecto, el installer instala las apps definidas en `apps-example.json`:

- **ERPNext**: Versión 15 (rama `version-15`)
- **barriofarma_app**: Rama `development`

## Integración con Docker

El installer está diseñado para trabajar con servicios Docker:

- **Solo DB + Redis**: Levanta solo los servicios de base de datos y Redis desde `docker-compose.barriofarma.yml`
- **Stack completo**: Usa el stack completo de Docker (backend, frontend, workers, etc.)

Para desarrollo local con el installer, típicamente se usa solo DB + Redis:

```bash
# En el repo root
docker-compose -f docker-compose.barriofarma.yml up -d db redis-cache redis-queue
```

Luego ejecuta el installer normalmente.

## Metodología de Trabajo

### Dominio vs Proceso

Este proyecto utiliza una metodología híbrida:

- **Dominio** (BarrioFarma específico): Se mantiene en reglas y documentación
  - DDD, modelo de dominio, mapeo a ERPNext
  - Reglas: `ddd_erpnext_mapping.mdc`, `frappe_doctype_creation.mdc`, `modelo_de_dominio.mdc`
  - Documentación: `.cursor/docs/domain_model/`

- **Proceso** (desarrollo): Orquestado por BMAD
  - Workflows: `*story-ready`, `*dev-story`, `*story-done`
  - Agentes: Architect, Dev, PM, SM, Analyst, TEA
  - Ver `.cursor/rules/roles.mdc` y `workflow.mdc` para más detalles

### Fuente de Verdad

- **Tareas**: GitHub Issues en `barriofarmacl/whiteboard`
- **Backlog**: GitHub Projects (DevOps y Desarrollo)
- **Documentación técnica**: `.cursor/docs/`

### Workflows Custom

Workflows específicos de BarrioFarma:

- `*barriofarma-doctype-ddd`: Crear DocTypes siguiendo DDD
- `*barriofarma-custom-fields-tdd`: Agregar campos custom con TDD
- `*barriofarma-setup-dev`: Configurar entorno de desarrollo

Ver `.cursor/rules/barriofarma_workflows.mdc` para más detalles.

## Referencias

- **Installer**: `installer.py` (este directorio)
- **Apps**: `apps-example.json` (este directorio)
- **Docker Compose**: `../docker-compose.barriofarma.yml` (repo root)
- **Plan de Alineación BMAD**: `.cursor/docs/PLAN_ALINEACION_BMAD.md`
- **Auditoría de Reglas**: `.cursor/docs/FASE1_AUDITORIA_REGLAS.md`
- **Análisis del repositorio (histórico)**: Engram, topic `archive/docs/REPOSITORIO_ANALISIS_Y_PROPUESTA_REORDENACION.md`
- **Reglas**: `.cursor/rules/`
- **Issues**: https://github.com/barriofarmacl/whiteboard/issues

## Troubleshooting

### El bench no se crea

- Verifica que los servicios de DB y Redis estén corriendo
- Revisa los logs del installer (usa `-v` para verbose)
- Asegúrate de tener permisos de escritura en el directorio

### Error de conexión a Redis

- Verifica que `redis-cache` y `redis-queue` estén corriendo
- Revisa la configuración en `frappe-bench/sites/common_site_config.json`
- El installer configura automáticamente los timeouts necesarios

### Error de conexión a la base de datos

- Verifica que el servicio de DB esté corriendo
- Revisa las credenciales en `frappe-bench/sites/common_site_config.json`
- Para MariaDB, el installer configura `--mariadb-user-host-login-scope=%`
