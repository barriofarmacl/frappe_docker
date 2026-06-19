# 🤔 ¿Por qué Kustomize?

## 📋 Contexto

Kustomize fue elegido como herramienta para gestionar los manifests de Kubernetes en BarrioFarma. Este documento explica las razones de esta decisión y compara con alternativas.

## 🎯 Razones para Elegir Kustomize

### 1. ✅ Nativo de Kubernetes

**Kustomize viene integrado con `kubectl` desde Kubernetes 1.14+**

```bash
# No necesitas instalar nada adicional
kubectl apply -k .  # Funciona directamente
```

**Ventajas:**
- ✅ No requiere instalación adicional
- ✅ Funciona en cualquier entorno con kubectl
- ✅ Menos dependencias externas
- ✅ Compatible con herramientas que usan kubectl

**Comparación:**
- Helm requiere instalar `helm` CLI
- Otros tools requieren instalación adicional

---

### 2. ✅ Sin Templates Complejos

**Kustomize usa overlays y patches, no templates**

```yaml
# Kustomize: Simple y declarativo
resources:
  - deployment.yaml

images:
  - name: gcr.io/barriofarma-dev/bf-app-dev
    newTag: 0.0.1-otel
```

**Ventajas:**
- ✅ Fácil de entender y mantener
- ✅ No requiere aprender un lenguaje de templates
- ✅ Los manifests siguen siendo YAML puro
- ✅ Fácil de debuggear (puedes ver el output con `kubectl kustomize .`)

**Comparación con Helm:**
```yaml
# Helm: Requiere templates Go
{{- if .Values.image.tag }}
image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- else }}
image: {{ .Values.image.repository }}:latest
{{- end }}
```
- ❌ Más complejo para casos simples
- ❌ Requiere aprender sintaxis de templates
- ❌ Más difícil de debuggear

---

### 3. ✅ GitOps Friendly

**Kustomize funciona perfectamente con ArgoCD**

```yaml
# ArgoCD puede usar Kustomize directamente
source:
  path: k8s
  # ArgoCD detecta kustomization.yaml automáticamente
```

**Ventajas:**
- ✅ ArgoCD tiene soporte nativo para Kustomize
- ✅ No requiere configuración adicional
- ✅ Los cambios en Git se reflejan automáticamente
- ✅ Compatible con otros tools GitOps (Flux, etc.)

**Comparación:**
- Helm también funciona con ArgoCD, pero requiere más configuración
- Raw kubectl funciona pero es más manual

---

### 4. ✅ Gestión de Variantes (Environments)

**Kustomize facilita gestionar dev/staging/production**

```
k8s/
├── base/
│   ├── kustomization.yaml
│   └── deployment.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml  # Patches para dev
│   ├── staging/
│   │   └── kustomization.yaml  # Patches para staging
│   └── production/
│       └── kustomization.yaml  # Patches para production
```

**Ventajas:**
- ✅ Un solo base, múltiples variantes
- ✅ Fácil de mantener (DRY principle)
- ✅ Cambios en base se propagan a todos los ambientes
- ✅ Overlays solo contienen diferencias

**Ejemplo práctico:**
```yaml
# base/kustomization.yaml
resources:
  - deployment.yaml

# overlays/dev/kustomization.yaml
resources:
  - ../../base
patches:
  - replicas: 1  # Dev usa menos réplicas

# overlays/production/kustomization.yaml
resources:
  - ../../base
patches:
  - replicas: 5  # Production usa más réplicas
```

---

### 5. ✅ Patches Estratégicos

**Kustomize permite modificar recursos sin duplicar código**

```yaml
# kustomization.yaml
patchesStrategicMerge:
  - |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: barriofarma-backend
    spec:
      template:
        spec:
          containers:
          - name: backend
            resources:
              requests:
                memory: "1Gi"
                cpu: "500m"
```

**Ventajas:**
- ✅ Modifica solo lo necesario
- ✅ Mantiene el archivo original intacto
- ✅ Fácil de versionar cambios
- ✅ Puedes tener múltiples patches

**Comparación:**
- Raw kubectl: Tendrías que duplicar archivos completos
- Helm: Requiere templates más complejos

---

### 6. ✅ Gestión de Imágenes

**Kustomize facilita actualizar tags de imágenes**

```yaml
# kustomization.yaml
images:
  - name: gcr.io/barriofarma-dev/bf-app-dev
    newTag: 0.0.2-otel  # Cambiar aquí actualiza todos los deployments
```

**Ventajas:**
- ✅ Un solo lugar para actualizar versión de imagen
- ✅ Se aplica a todos los recursos que usan esa imagen
- ✅ Perfecto para CI/CD (actualizar tag automáticamente)

**Comparación:**
- Raw kubectl: Tendrías que buscar/reemplazar en múltiples archivos
- Helm: Similar pero requiere configuración de values

---

### 7. ✅ Labels y Annotations Comunes

**Kustomize aplica labels comunes automáticamente**

```yaml
# kustomization.yaml
commonLabels:
  app.kubernetes.io/name: barriofarma
  app.kubernetes.io/version: "0.0.1"
  app.kubernetes.io/managed-by: argocd
```

**Ventajas:**
- ✅ Consistencia automática
- ✅ Fácil de filtrar recursos (`kubectl get all -l app.kubernetes.io/name=barriofarma`)
- ✅ Mejores prácticas de Kubernetes

---

### 8. ✅ Orden de Aplicación

**Kustomize gestiona el orden de recursos automáticamente**

```yaml
resources:
  - namespace.yaml      # Se aplica primero
  - configmap.yaml     # Luego configmaps
  - secret.yaml        # Luego secrets
  - pvc.yaml           # Luego PVCs
  - deployment.yaml    # Finalmente deployments
```

**Ventajas:**
- ✅ Orden correcto automáticamente
- ✅ Evita errores de dependencias
- ✅ No necesitas aplicar archivos manualmente uno por uno

**Comparación:**
- Raw kubectl: Tendrías que aplicar en orden correcto manualmente
- Helm: También gestiona orden, pero con más complejidad

---

## 🔄 Alternativas Consideradas

### Opción A: Raw kubectl (Sin Kustomize)

**Cómo sería:**
```bash
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
# ... aplicar cada archivo individualmente
```

**Desventajas:**
- ❌ Más tedioso (muchos comandos)
- ❌ Propenso a errores de orden
- ❌ Difícil gestionar variantes (dev/staging/prod)
- ❌ Actualizar imágenes requiere editar múltiples archivos
- ❌ No hay gestión automática de labels comunes

**Cuándo usar:**
- Proyectos muy pequeños (1-2 archivos)
- Cuando no necesitas variantes de ambiente
- Cuando prefieres control total manual

---

### Opción B: Helm

**Cómo sería:**
```
charts/
├── barriofarma/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-production.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── ...
```

**Ventajas:**
- ✅ Muy maduro y popular
- ✅ Gran ecosistema de charts
- ✅ Gestión de dependencias (subcharts)
- ✅ Versionado de releases

**Desventajas:**
- ❌ Requiere aprender sintaxis de templates Go
- ❌ Más complejo para casos simples
- ❌ Requiere instalar `helm` CLI
- ❌ Debugging más difícil (templates compilados)
- ❌ Overhead para proyectos pequeños/medianos

**Cuándo usar:**
- Proyectos grandes con muchas variantes
- Cuando necesitas distribuir charts públicamente
- Cuando necesitas gestión de dependencias complejas
- Cuando el equipo ya conoce Helm

---

### Opción C: Kustomize (Elegida) ✅

**Cómo es:**
```
k8s/
├── kustomization.yaml  # Gestión centralizada
├── deployment.yaml     # YAML puro
├── service.yaml        # YAML puro
└── ...
```

**Ventajas:**
- ✅ Nativo de Kubernetes (no requiere instalación)
- ✅ YAML puro, fácil de entender
- ✅ Perfecto para GitOps (ArgoCD)
- ✅ Gestión de variantes con overlays
- ✅ Patches estratégicos sin duplicar código
- ✅ Gestión de imágenes centralizada

**Desventajas:**
- ⚠️ Menos popular que Helm (pero creciendo)
- ⚠️ No tiene gestión de dependencias como Helm
- ⚠️ Menos charts públicos disponibles

**Cuándo usar:**
- ✅ Proyectos pequeños/medianos (como BarrioFarma)
- ✅ Cuando quieres YAML puro sin templates
- ✅ Cuando usas GitOps (ArgoCD, Flux)
- ✅ Cuando prefieres simplicidad sobre features avanzadas

---

## 📊 Comparación Rápida

| Característica | Raw kubectl | Helm | Kustomize |
|----------------|-------------|------|-----------|
| **Complejidad** | Baja | Alta | Media |
| **Instalación** | No requiere | Requiere `helm` | Nativo (kubectl) |
| **Templates** | No | Sí (Go) | No (YAML puro) |
| **GitOps** | Manual | Bueno | Excelente |
| **Variantes** | Duplicar archivos | Values files | Overlays |
| **Gestión imágenes** | Manual | Values | Nativo |
| **Debugging** | Fácil | Difícil | Fácil |
| **Curva aprendizaje** | Baja | Alta | Media |
| **Ecosistema** | N/A | Muy grande | Creciendo |

---

## 🎯 Decisión para BarrioFarma

### Por qué Kustomize es la mejor opción aquí:

1. **Simplicidad:**
   - BarrioFarma no necesita la complejidad de Helm
   - YAML puro es más fácil de mantener
   - El equipo puede entender los manifests fácilmente

2. **GitOps:**
   - Usamos ArgoCD (soporte nativo para Kustomize)
   - Cambios en Git se reflejan automáticamente
   - No requiere configuración adicional

3. **Gestión de ambientes:**
   - Fácil crear overlays para dev/staging/production
   - Un solo base, múltiples variantes
   - Mantenimiento más simple

4. **CI/CD:**
   - Actualizar imagen es solo cambiar `newTag` en kustomization.yaml
   - GitHub Actions puede hacerlo fácilmente
   - No requiere templates complejos

5. **Nativo:**
   - No requiere instalar herramientas adicionales
   - Funciona con kubectl directamente
   - Menos dependencias = menos problemas

---

## 🔄 Migración a Helm (Si fuera necesario)

Si en el futuro necesitas migrar a Helm, es relativamente fácil:

1. Los manifests YAML pueden convertirse a templates Helm
2. Los valores pueden moverse a `values.yaml`
3. Helm puede usar los mismos manifests como base

**Pero por ahora, Kustomize es suficiente y más simple.**

---

## 📚 Referencias

- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [Helm vs Kustomize](https://www.weave.works/blog/helm-vs-kustomize)
- [ArgoCD Kustomize Support](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)

---

## ✅ Conclusión

**Kustomize fue elegido porque:**
- ✅ Es nativo de Kubernetes (no requiere instalación)
- ✅ Es simple y fácil de entender (YAML puro)
- ✅ Funciona perfectamente con ArgoCD (GitOps)
- ✅ Facilita gestión de variantes (dev/staging/prod)
- ✅ Es suficiente para las necesidades de BarrioFarma

**No elegimos Helm porque:**
- ❌ Es más complejo de lo necesario para este proyecto
- ❌ Requiere aprender sintaxis de templates
- ❌ Agrega overhead sin beneficios claros aquí

**No elegimos raw kubectl porque:**
- ❌ Es más tedioso (muchos comandos)
- ❌ No facilita gestión de variantes
- ❌ Actualizar imágenes requiere editar múltiples archivos

