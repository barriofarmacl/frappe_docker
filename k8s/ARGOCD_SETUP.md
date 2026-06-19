# 🔄 ArgoCD GitOps Setup - BarrioFarma

## 📋 Descripción

Configuración completa de ArgoCD para GitOps con BarrioFarma, incluyendo aplicaciones, proyectos y políticas de sincronización.

## 🏗️ Arquitectura GitOps

```
GitHub Repo → ArgoCD → GKE Cluster → BarrioFarma App
     ↓              ↓
  Source of Truth  GitOps Sync
```

## 🚀 Instalación

### 1. Instalar ArgoCD

```bash
# Crear namespace
kubectl create namespace argocd

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verificar instalación
kubectl get pods -n argocd
```

### 2. Configurar Acceso

```bash
# Obtener password inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward para acceso local
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 3. Aplicar Configuración

```bash
# Aplicar aplicaciones
kubectl apply -f argocd-application.yaml

# Verificar aplicaciones
kubectl get applications -n argocd
```

## 📊 Aplicaciones Configuradas

### BarrioFarma Development
- **Source**: `barriofarma-develop` branch
- **Destination**: barriofarma namespace
- **Sync Policy**: Automated with self-heal

### BarrioFarma Staging
- **Source**: `barriofarma-develop` branch (mismo que dev)
- **Destination**: barriofarma namespace
- **Sync Policy**: Automated with self-heal

### BarrioFarma Production
- **Source**: `barriofarma-production` branch
- **Destination**: barriofarma namespace
- **Sync Policy**: Automated with self-heal

**Nota:** La rama `main` NO se usa para BarrioFarma, solo para mantener el fork de frappe sincronizado.

## 🔄 Flujo GitOps

1. **Push to Git** → Trigger GitHub Actions
2. **Build & Test** → Create new image
3. **Deploy to GKE** → Update manifests
4. **ArgoCD Sync** → Apply changes automatically
5. **Health Check** → Validate deployment

## 📚 Referencias

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://www.gitops.tech/)
- [Kubernetes GitOps](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)
