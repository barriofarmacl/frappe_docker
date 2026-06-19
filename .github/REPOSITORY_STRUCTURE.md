# Estrategia de repositorios BarrioFarma

Documento de contrato vigente (ADR-003). Define la frontera entre el fork de plataforma/dev y el repo de infraestructura cloud operativa.

## Roles

| Repositorio | Rol | Equipo principal |
|-------------|-----|------------------|
| `barriofarmacl/frappe_docker` (fork) | Plataforma, devcontainer, build imagen, app-layer GitOps | Desarrollo + DevOps plataforma |
| `barriofarmacl/barriofarma-infrastructure` | IaC cloud, Ansible deploy, runbooks operativos | DevOps operaciones |

## Contenido del fork (`frappe_docker`)

```
frappe_docker/  (rama barriofarma/develop)
├── development/              # Devcontainer, installer, .cursor submodule, sii/
├── images/barriofarma/       # Containerfile bf-app-uat
├── docker-compose.barriofarma*.yml   # Stack runtime (CANONICO)
├── docker-compose.uat-vps.yml
├── apps-*.json               # Manifests de apps por entorno
├── config/                   # redis-cache.conf, redis-queue.conf
├── scripts/                  # build/push imagen, create-site-if-needed.sh
├── k8s/                      # Manifests Kubernetes (app-layer / GitOps)
├── observability/            # Stack OTEL/Prometheus/Grafana (app-layer)
└── .github/
```

**No incluye:** `terraform/` ni `ansible/` de operacion cloud (viven en `barriofarma-infrastructure`).

## Contenido de infra (`barriofarma-infrastructure`)

```
barriofarma-infrastructure/
├── terraform/environments/uat-vps/   # VM GCE, DNS, firewall
├── terraform/dns/                    # Cloud DNS barriofarmadigital
├── ansible/                          # bootstrap, deploy, TLS, seed
├── vendor/frappe_docker/             # Submodule -> fork barriofarma/develop
└── docs/runbooks/ + docs/adr/
```

## Contrato submodule

Infra consume el fork via submodule fijado por `platform_ref`:

```yaml
# barriofarma-infrastructure/ansible/inventories/uat/group_vars/all/main.yml
platform_vendor_path: "{{ playbook_dir }}/../../vendor/frappe_docker"
platform_ref: "923dd0c"   # commit en barriofarma/develop con compose canonico
uat_app_image: gcr.io/barriofarma-uat-cl/bf-app-uat:<tag>
```

Artefactos que Ansible copia desde `vendor/frappe_docker` a la VM UAT:

- `docker-compose.barriofarma.yml`
- `docker-compose.uat-vps.yml`
- `config/redis-*.conf`
- `scripts/create-site-if-needed.sh`

## Flujo de cambios coordinados

Cuando cambia el compose **y** el deploy:

1. PR en `frappe_docker` (`barriofarma/develop`) con cambios de plataforma.
2. PR en `barriofarma-infrastructure` bump `vendor/frappe_docker` + `platform_ref`.
3. Si cambia imagen: rebuild + bump `uat_app_image`.

## k8s/ y observability/

Permanecen en el **fork** como app-layer. ArgoCD (futuro) apunta al fork, no a infra.

La ruta historica GKE UAT (`k8s/overlays/uat/`) es referencia; el canal UAT operativo actual es VPS Compose (ADR-001).

## Referencias

- ADR-003: `barriofarma-infrastructure/docs/adr/003-frontera-fork-infra.md`
- ADR-001 UAT VPS: `barriofarma-infrastructure/docs/adr/001-uat-vps-official.md`
- Runbook UAT: `barriofarma-infrastructure/docs/runbooks/uat-vps-compose-ansible.md`
- Branching: [.github/BRANCHING_STRATEGY.md](./BRANCHING_STRATEGY.md)
