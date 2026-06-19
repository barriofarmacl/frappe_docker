# Estrategia de branching - fork frappe_docker

Este repositorio es un **fork de frappe/frappe_docker**. La rama `main` se mantiene sincronizada con upstream; el trabajo BarrioFarma vive en una rama larga dedicada.

## Ramas

```
main
  Solo sincronizacion con upstream/frappe_docker (frappe/frappe_docker).
  No contiene cambios BarrioFarma.

barriofarma/develop
  Rama larga de trabajo diario BarrioFarma.
  Contiene: compose, devcontainer, k8s/, observability/, images/barriofarma/, scripts/.
  Infra operativa consume esta rama via submodule (platform_ref).
```

## Flujo de trabajo

```
1. Desarrollo en barriofarma/develop (devcontainer, compose, plataforma)
2. Commit + push (HTTPS con cuenta org: earaya-barriofarma)
3. Bump submodule en barriofarma-infrastructure cuando cambie plataforma
4. Deploy UAT desde barriofarma-infrastructure (Ansible)
```

## Sincronizacion con upstream (frappe)

```bash
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

Integrar cambios de upstream a `barriofarma/develop` periodicamente (merge o rebase segun politica del equipo). No mezclar cambios BF en `main`.

## Convenciones de commits

| Prefijo | Uso |
|---------|-----|
| `feat(platform):` | Compose, config, scripts de plataforma |
| `feat(dev):` | Devcontainer, installer, development/ |
| `chore(openspec):` | Bump submodule .cursor (methodology) |
| `infra(k8s):` | Manifests Kubernetes / GitOps |
| `docs:` | Documentacion |

## Modelo deprecado

El modelo `barriofarma-develop` / `barriofarma-production` (ArgoCD dual-branch) fue reemplazado por `barriofarma/develop` como rama unica de plataforma. GitOps futuro puede reintroducir ramas de release cuando exista cluster productivo.

## Push e identidad Git

El remote puede usar SSH (`git@github.com`), pero el push requiere cuenta con write en `barriofarmacl/frappe_docker`:

```bash
# Push one-shot por HTTPS (usa gh auth earaya-barriofarma)
git push https://github.com/barriofarmacl/frappe_docker.git barriofarma/develop:barriofarma/develop
```

## Referencias

- Estructura repos: [REPOSITORY_STRUCTURE.md](./REPOSITORY_STRUCTURE.md)
- Entorno dev: [development/README.md](../development/README.md)
- Infra operativa: https://github.com/barriofarmacl/barriofarma-infrastructure
