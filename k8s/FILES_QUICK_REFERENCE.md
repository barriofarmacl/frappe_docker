# 📋 Referencia Rápida - Archivos YAML Necesarios

## 🎯 Resumen Visual

```
k8s/
├── ✅ ESENCIALES (7 archivos)
│   ├── namespace.yaml              # Namespace
│   ├── configmap.yaml              # Configuración
│   ├── secret.yaml                 # Credenciales
│   ├── pvc.yaml                    # Almacenamiento
│   ├── deployment.yaml             # Backend
│   ├── service.yaml                # Services
│   └── kustomization.yaml          # Gestión
│
├── ⚠️ RECOMENDADOS (5 archivos)
│   ├── deployment-frontend.yaml    # Frontend
│   ├── deployment-websocket.yaml  # WebSocket
│   ├── deployment-scheduler.yaml   # Scheduler
│   ├── deployment-queue-short.yaml # Queue Short
│   └── deployment-queue-long.yaml # Queue Long
│
├── 🚀 INICIALIZACIÓN (2 archivos - solo primera vez)
│   ├── job-configurator.yaml       # Config inicial
│   └── job-create-site.yaml        # Crear sitio
│
├── 🌐 OPCIONALES - Red/Acceso (1 archivo)
│   └── ingress.yaml                # Acceso externo TLS
│
├── 📊 OPCIONALES - Observabilidad (1 archivo)
│   └── servicemonitor.yaml         # Prometheus scraping
│
├── 🔄 OPCIONALES - Autoscaling (3 archivos)
│   ├── hpa-backend.yaml            # HPA Backend
│   ├── hpa-frontend.yaml           # HPA Frontend
│   └── hpa-queue-short.yaml        # HPA Queue
│
├── 🔄 OPCIONALES - GitOps (3 archivos)
│   ├── argocd-application.yaml     # ArgoCD App
│   ├── argocd-application-dev.yaml # ArgoCD Dev
│   └── argocd-install.yaml          # Instalar ArgoCD
│
└── 📝 EJEMPLOS (2 archivos)
    ├── configmap-gcp.example.yaml  # Ejemplo ConfigMap
    └── deployment-gcp.example.yaml # Ejemplo Deployment
```

## ✅ Mínimo Necesario (7 archivos)

Para desplegar solo el backend básico:

1. ✅ `namespace.yaml`
2. ✅ `configmap.yaml`
3. ✅ `secret.yaml`
4. ✅ `pvc.yaml`
5. ✅ `deployment.yaml`
6. ✅ `service.yaml`
7. ✅ `kustomization.yaml`

**Total: 7 archivos**

---

## ⚠️ Recomendado Completo (12 archivos)

Para stack completo funcional:

**Esenciales (7) + Recomendados (5):**
8. ⚠️ `deployment-frontend.yaml`
9. ⚠️ `deployment-websocket.yaml`
10. ⚠️ `deployment-scheduler.yaml`
11. ⚠️ `deployment-queue-short.yaml`
12. ⚠️ `deployment-queue-long.yaml`

**Total: 12 archivos**

---

## 🚀 Primera Vez (14 archivos)

Para primera ejecución, agregar Jobs:

13. 🚀 `job-configurator.yaml`
14. 🚀 `job-create-site.yaml`

**Total: 14 archivos**

**Nota:** Después de ejecutar exitosamente, puedes remover los Jobs de `kustomization.yaml`.

---

## 🌐 Producción Completa (18 archivos)

Agregar opcionales según necesidad:

15. 🌐 `ingress.yaml` - Acceso externo con TLS
16. 📊 `servicemonitor.yaml` - Métricas Prometheus
17. 🔄 `hpa-backend.yaml` - Autoscaling Backend
18. 🔄 `hpa-frontend.yaml` - Autoscaling Frontend
19. 🔄 `hpa-queue-short.yaml` - Autoscaling Queue

**Total: 18 archivos activos**

---

## 🗑️ Archivos que Puedes Eliminar

### Si NO usas ArgoCD:
- ❌ `argocd-application.yaml`
- ❌ `argocd-application-dev.yaml`
- ❌ `argocd-install.yaml`

### Si NO usas Prometheus Operator:
- ❌ `servicemonitor.yaml` (pero annotations en deployments funcionan)

### Si NO quieres autoscaling:
- ❌ `hpa-backend.yaml`
- ❌ `hpa-frontend.yaml`
- ❌ `hpa-queue-short.yaml`

### Después de primera ejecución:
- ❌ `job-configurator.yaml` (remover de kustomization.yaml)
- ❌ `job-create-site.yaml` (remover de kustomization.yaml)

### Siempre puedes eliminar:
- ❌ `configmap-gcp.example.yaml` (solo ejemplo)
- ❌ `deployment-gcp.example.yaml` (solo ejemplo)

---

## 📊 Tabla de Decisión Rápida

| Archivo | ¿Necesario? | ¿Cuándo? | ¿Puedo eliminarlo? |
|---------|-------------|----------|-------------------|
| `namespace.yaml` | ✅ SÍ | Siempre | ❌ NO |
| `configmap.yaml` | ✅ SÍ | Siempre | ❌ NO |
| `secret.yaml` | ✅ SÍ | Siempre | ❌ NO |
| `pvc.yaml` | ✅ SÍ | Siempre | ❌ NO |
| `deployment.yaml` | ✅ SÍ | Siempre | ❌ NO |
| `service.yaml` | ✅ SÍ | Siempre | ❌ NO |
| `kustomization.yaml` | ✅ SÍ | Si usas Kustomize | ❌ NO |
| `deployment-frontend.yaml` | ⚠️ Recomendado | Stack completo | ✅ SÍ (si no usas frontend) |
| `deployment-websocket.yaml` | ⚠️ Recomendado | Stack completo | ✅ SÍ (si no usas websockets) |
| `deployment-scheduler.yaml` | ⚠️ Recomendado | Stack completo | ✅ SÍ (si no usas scheduled jobs) |
| `deployment-queue-short.yaml` | ⚠️ Recomendado | Stack completo | ✅ SÍ (si no usas background jobs) |
| `deployment-queue-long.yaml` | ⚠️ Recomendado | Stack completo | ✅ SÍ (si no generas reportes) |
| `job-configurator.yaml` | 🚀 Primera vez | Solo inicialización | ✅ SÍ (después de primera vez) |
| `job-create-site.yaml` | 🚀 Primera vez | Solo inicialización | ✅ SÍ (después de primera vez) |
| `ingress.yaml` | 🌐 Opcional | Si necesitas acceso externo | ✅ SÍ (si usas LoadBalancer directo) |
| `servicemonitor.yaml` | 📊 Opcional | Si usas Prometheus Operator | ✅ SÍ (si no usas Prometheus Operator) |
| `hpa-*.yaml` | 🔄 Opcional | Si quieres autoscaling | ✅ SÍ (si no quieres autoscaling) |
| `argocd-*.yaml` | 🔄 Opcional | Si usas ArgoCD | ✅ SÍ (si no usas ArgoCD) |
| `*-example.yaml` | 📝 Ejemplo | Nunca | ✅ SÍ (solo documentación) |

---

## 🎯 Escenarios de Uso

### Escenario A: Desarrollo Local Mínimo
```
✅ 7 esenciales
= 7 archivos
```

### Escenario B: Desarrollo Local Completo
```
✅ 7 esenciales
⚠️ 5 recomendados
🚀 2 jobs (primera vez)
= 14 archivos
```

### Escenario C: Staging
```
✅ 7 esenciales
⚠️ 5 recomendados
🌐 1 ingress
📊 1 servicemonitor
= 14 archivos (sin jobs después de primera vez)
```

### Escenario D: Producción Completa
```
✅ 7 esenciales
⚠️ 5 recomendados
🌐 1 ingress
📊 1 servicemonitor
🔄 3 hpa (opcional)
🔄 1 argocd-application (si usas ArgoCD)
= 18 archivos (sin jobs después de primera vez)
```

---

## 💡 Recomendación Final

**Para empezar:**
- Usa todos los esenciales + recomendados (12 archivos)
- Incluye los Jobs la primera vez (14 archivos)
- Después de primera ejecución exitosa, remueve Jobs de `kustomization.yaml`

**Para producción:**
- Agrega `ingress.yaml` y `servicemonitor.yaml`
- Considera HPA si tienes carga variable
- Usa ArgoCD si quieres GitOps

**Puedes eliminar siempre:**
- Archivos `*-example.yaml` (solo documentación)
- Archivos de ArgoCD si no lo usas
- Archivos de HPA si no quieres autoscaling

Ver documentación completa en: [YAML_FILES_EXPLAINED.md](./YAML_FILES_EXPLAINED.md)

