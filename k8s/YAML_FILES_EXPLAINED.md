# 📋 Explicación de Archivos YAML en k8s/

Este documento explica cada archivo YAML en el directorio `k8s/`, su propósito, si es necesario, y cuándo se usa.

## 🎯 Archivos Esenciales (Requeridos para Despliegue Básico)

### 1. `namespace.yaml` ✅ **ESENCIAL**
**Propósito:** Crea el namespace `barriofarma` donde se desplegarán todos los recursos.

**¿Es necesario?** SÍ - Sin esto, no puedes desplegar nada.

**Cuándo se usa:** Siempre, antes que cualquier otro recurso.

```yaml
kind: Namespace
```

---

### 2. `configmap.yaml` ✅ **ESENCIAL**
**Propósito:** Configuración de la aplicación (DB host, Redis URLs, variables de entorno).

**¿Es necesario?** SÍ - Los pods necesitan esta configuración para funcionar.

**Cuándo se usa:** Siempre, antes de los deployments.

**Nota:** Debe actualizarse con IPs reales de Cloud SQL y Memorystore después de `terraform apply`.

---

### 3. `secret.yaml` ✅ **ESENCIAL**
**Propósito:** Credenciales sensibles (passwords de DB, API keys).

**¿Es necesario?** SÍ - Los pods necesitan credenciales para conectarse a DB.

**Cuándo se usa:** Siempre, antes de los deployments.

**⚠️ Importante:** Actualizar con valores reales antes de desplegar a producción.

---

### 4. `pvc.yaml` ✅ **ESENCIAL**
**Propósito:** Persistent Volume Claims para almacenar datos (sites y logs).

**¿Es necesario?** SÍ - Sin esto, los datos se perderían al reiniciar pods.

**Cuándo se usa:** Siempre, antes de los deployments que necesitan almacenamiento.

---

### 5. `deployment.yaml` ✅ **ESENCIAL**
**Propósito:** Deployment del backend (Gunicorn).

**¿Es necesario?** SÍ - Es el componente principal de la aplicación.

**Cuándo se usa:** Siempre.

---

### 6. `service.yaml` ✅ **ESENCIAL**
**Propósito:** Services de Kubernetes para exponer los deployments internamente.

**¿Es necesario?** SÍ - Sin esto, los pods no pueden comunicarse entre sí.

**Cuándo se usa:** Siempre, después de los deployments.

**Contiene:** Services para backend, frontend y websocket.

---

## 🔧 Archivos de Despliegue (Necesarios para Stack Completo)

### 7. `deployment-frontend.yaml` ⚠️ **RECOMENDADO**
**Propósito:** Deployment del frontend (Nginx reverse proxy).

**¿Es necesario?** RECOMENDADO - Sin esto, no hay acceso web a la aplicación.

**Cuándo se usa:** Para despliegue completo. Puedes omitirlo si solo usas backend API.

---

### 8. `deployment-websocket.yaml` ⚠️ **RECOMENDADO**
**Propósito:** Deployment del websocket (SocketIO para actualizaciones en tiempo real).

**¿Es necesario?** RECOMENDADO - Frappe/ERPNext usa websockets para notificaciones.

**Cuándo se usa:** Para funcionalidad completa. Puedes omitirlo si no necesitas websockets.

---

### 9. `deployment-scheduler.yaml` ⚠️ **RECOMENDADO**
**Propósito:** Deployment del scheduler (ejecuta tareas programadas).

**¿Es necesario?** RECOMENDADO - Sin esto, las tareas programadas no se ejecutan.

**Cuándo se usa:** Para funcionalidad completa. Puedes omitirlo si no usas scheduled jobs.

---

### 10. `deployment-queue-short.yaml` ⚠️ **RECOMENDADO**
**Propósito:** Workers para procesar queues cortas (tareas rápidas).

**¿Es necesario?** RECOMENDADO - Sin esto, las tareas en queue no se procesan.

**Cuándo se usa:** Para funcionalidad completa. Puedes omitirlo si no usas background jobs.

---

### 11. `deployment-queue-long.yaml` ⚠️ **RECOMENDADO**
**Propósito:** Workers para procesar queues largas (tareas pesadas como reportes).

**¿Es necesario?** RECOMENDADO - Sin esto, las tareas largas no se procesan.

**Cuándo se usa:** Para funcionalidad completa. Puedes omitirlo si no generas reportes pesados.

---

## 🚀 Archivos de Inicialización (Solo Primera Vez)

### 12. `job-configurator.yaml` ⚠️ **SOLO PRIMERA VEZ**
**Propósito:** Job que inicializa `common_site_config.json` con configuración de DB y Redis.

**¿Es necesario?** SOLO LA PRIMERA VEZ - Después de ejecutarse exitosamente, no es necesario.

**Cuándo se usa:** 
- Primera vez que despliegas
- Si necesitas recrear la configuración desde cero

**Nota:** Es un Job, se ejecuta una vez y completa. Se elimina automáticamente después de 24 horas.

---

### 13. `job-create-site.yaml` ⚠️ **SOLO PRIMERA VEZ**
**Propósito:** Job que crea el sitio inicial `frontend` con ERPNext y BarrioFarma App.

**¿Es necesario?** SOLO LA PRIMERA VEZ - Después de crear el sitio, no es necesario.

**Cuándo se usa:**
- Primera vez que despliegas
- Si necesitas recrear el sitio desde cero

**Nota:** Es un Job, se ejecuta una vez y completa. Se elimina automáticamente después de 24 horas.

**⚠️ Importante:** Debe ejecutarse DESPUÉS de `job-configurator.yaml`.

---

## 🌐 Archivos de Red y Acceso Externo

### 14. `ingress.yaml` ⚠️ **OPCIONAL**
**Propósito:** Ingress para exponer la aplicación externamente con TLS.

**¿Es necesario?** OPCIONAL - Solo si necesitas acceso desde internet.

**Cuándo se usa:**
- Para producción/staging con dominio público
- Si necesitas TLS/HTTPS

**Alternativas:**
- Usar `kubectl port-forward` para desarrollo local
- Usar LoadBalancer Service directamente (más simple pero sin TLS automático)

---

## 📊 Archivos de Observabilidad

### 15. `servicemonitor.yaml` ⚠️ **OPCIONAL**
**Propósito:** ServiceMonitor para que Prometheus scrape métricas del backend.

**¿Es necesario?** OPCIONAL - Solo si usas Prometheus Operator.

**Cuándo se usa:**
- Si tienes Prometheus Operator instalado
- Si quieres métricas de la aplicación en Prometheus

**Alternativas:**
- Scraping manual de Prometheus
- Usar annotations en el deployment (ya están configuradas)

---

## 🔄 Archivos de Autoscaling

### 16. `hpa-backend.yaml` ⚠️ **OPCIONAL**
**Propósito:** Horizontal Pod Autoscaler para escalar backend automáticamente.

**¿Es necesario?** OPCIONAL - Solo si quieres autoscaling automático.

**Cuándo se usa:**
- En producción con carga variable
- Cuando quieres escalar automáticamente según CPU/memoria

**Nota:** Está comentado en `kustomization.yaml`. Descomentar cuando esté listo.

---

### 17. `hpa-frontend.yaml` ⚠️ **OPCIONAL**
**Propósito:** HPA para escalar frontend automáticamente.

**¿Es necesario?** OPCIONAL - Similar a `hpa-backend.yaml`.

---

### 18. `hpa-queue-short.yaml` ⚠️ **OPCIONAL**
**Propósito:** HPA para escalar queue workers automáticamente.

**¿Es necesario?** OPCIONAL - Útil si tienes carga variable de background jobs.

---

## 🎛️ Archivos de Configuración y Gestión

### 19. `kustomization.yaml` ✅ **ESENCIAL**
**Propósito:** Configuración de Kustomize para gestionar todos los recursos juntos.

**¿Es necesario?** SÍ - Si usas `kubectl apply -k .` o ArgoCD.

**Cuándo se usa:** Siempre, define qué recursos se despliegan y en qué orden.

**Alternativas:**
- Aplicar archivos individualmente con `kubectl apply -f archivo.yaml`
- Pero es más tedioso y propenso a errores

---

## 📚 Archivos de Documentación y Ejemplos

### 20. `argocd-application.yaml` ⚠️ **OPCIONAL**
**Propósito:** Application manifest de ArgoCD para GitOps.

**¿Es necesario?** OPCIONAL - Solo si usas ArgoCD.

**Cuándo se usa:**
- Si despliegas con ArgoCD
- Para staging/producción con GitOps

**Alternativas:**
- Desplegar manualmente con `kubectl apply -k .`
- Usar otros tools de GitOps

---

### 21. `argocd-application-dev.yaml` ⚠️ **OPCIONAL**
**Propósito:** Application manifest de ArgoCD para ambiente dev.

**¿Es necesario?** OPCIONAL - Similar a `argocd-application.yaml` pero para dev.

---

### 22. `argocd-install.yaml` ⚠️ **OPCIONAL**
**Propósito:** Instalación de ArgoCD (si decides instalarlo desde aquí).

**¿Es necesario?** OPCIONAL - Generalmente ArgoCD se instala de otra forma.

**Cuándo se usa:** Si quieres instalar ArgoCD directamente desde este repo.

**Recomendación:** Usar el método oficial de instalación de ArgoCD.

---

### 23. `configmap-gcp.example.yaml` 📝 **EJEMPLO**
**Propósito:** Ejemplo de ConfigMap con IPs de GCP.

**¿Es necesario?** NO - Es solo un ejemplo/documentación.

**Cuándo se usa:** Como referencia para actualizar `configmap.yaml` con IPs reales.

---

### 24. `deployment-gcp.example.yaml` 📝 **EJEMPLO**
**Propósito:** Ejemplo de Deployment con Cloud SQL Proxy.

**¿Es necesario?** NO - Es solo un ejemplo/documentación.

**Cuándo se usa:** Como referencia si decides usar Cloud SQL Proxy en lugar de IP privada directa.

---

## 📊 Resumen por Categoría

### ✅ Esenciales (6 archivos)
1. `namespace.yaml`
2. `configmap.yaml`
3. `secret.yaml`
4. `pvc.yaml`
5. `deployment.yaml` (backend)
6. `service.yaml`
7. `kustomization.yaml`

**Total mínimo:** Con estos 7 archivos puedes desplegar el backend básico.

---

### ⚠️ Recomendados para Stack Completo (5 archivos)
8. `deployment-frontend.yaml`
9. `deployment-websocket.yaml`
10. `deployment-scheduler.yaml`
11. `deployment-queue-short.yaml`
12. `deployment-queue-long.yaml`

**Total recomendado:** 12 archivos esenciales + recomendados = stack completo funcional.

---

### 🚀 Inicialización (2 archivos - solo primera vez)
13. `job-configurator.yaml`
14. `job-create-site.yaml`

**Nota:** Estos Jobs se ejecutan una vez y luego puedes eliminarlos del kustomization.yaml si quieres.

---

### 🌐 Opcionales según Necesidad (8 archivos)
15. `ingress.yaml` - Si necesitas acceso externo con TLS
16. `servicemonitor.yaml` - Si usas Prometheus Operator
17. `hpa-backend.yaml` - Si quieres autoscaling
18. `hpa-frontend.yaml` - Si quieres autoscaling
19. `hpa-queue-short.yaml` - Si quieres autoscaling
20. `argocd-application.yaml` - Si usas ArgoCD
21. `argocd-application-dev.yaml` - Si usas ArgoCD
22. `argocd-install.yaml` - Si instalas ArgoCD desde aquí

---

### 📝 Ejemplos/Documentación (2 archivos)
23. `configmap-gcp.example.yaml` - Ejemplo
24. `deployment-gcp.example.yaml` - Ejemplo

---

## 🎯 Escenarios de Uso

### Escenario 1: Despliegue Mínimo (Solo Backend API)
**Archivos necesarios:**
- `namespace.yaml`
- `configmap.yaml`
- `secret.yaml`
- `pvc.yaml`
- `deployment.yaml`
- `service.yaml`
- `kustomization.yaml` (ajustado)

**Total: 7 archivos**

---

### Escenario 2: Despliegue Completo (Producción)
**Archivos necesarios:**
- Todos los esenciales (7)
- Todos los recomendados (5)
- Jobs de inicialización (2) - solo primera vez
- `ingress.yaml` - para acceso externo
- `servicemonitor.yaml` - para métricas
- `kustomization.yaml` completo

**Total: 15 archivos activos** (después de primera vez, puedes remover los Jobs)

---

### Escenario 3: Despliegue con GitOps (ArgoCD)
**Archivos necesarios:**
- Todos del Escenario 2
- `argocd-application.yaml` o `argocd-application-dev.yaml`

**Total: 16 archivos**

---

### Escenario 4: Despliegue con Autoscaling
**Archivos necesarios:**
- Todos del Escenario 2
- `hpa-backend.yaml`
- `hpa-frontend.yaml`
- `hpa-queue-short.yaml`
- Descomentar en `kustomization.yaml`

**Total: 18 archivos**

---

## 🔄 Flujo de Despliegue Típico

### Primera Vez
```
1. namespace.yaml
2. configmap.yaml (actualizado con IPs)
3. secret.yaml (actualizado con credenciales)
4. pvc.yaml
5. job-configurator.yaml → Ejecuta y completa
6. job-create-site.yaml → Ejecuta y completa
7. deployment.yaml (backend)
8. deployment-frontend.yaml
9. deployment-websocket.yaml
10. deployment-scheduler.yaml
11. deployment-queue-short.yaml
12. deployment-queue-long.yaml
13. service.yaml
14. ingress.yaml (si es necesario)
15. servicemonitor.yaml (si es necesario)
```

### Despliegues Subsecuentes
```
1-4. Igual que primera vez
5-6. Jobs NO se ejecutan (ya completaron antes)
7-15. Deployments y Services se actualizan normalmente
```

**Nota:** Después de la primera vez, puedes remover los Jobs de `kustomization.yaml` si quieres.

---

## 💡 Recomendaciones

### Para Desarrollo Local
- Usar todos los esenciales + recomendados
- Omitir `ingress.yaml` (usar `kubectl port-forward`)
- Omitir HPA (no necesario en dev)

### Para Staging
- Usar todos los esenciales + recomendados
- Incluir `ingress.yaml` con dominio de staging
- Incluir `servicemonitor.yaml` para métricas
- Considerar HPA si hay carga variable

### Para Producción
- Usar todos los esenciales + recomendados
- Incluir `ingress.yaml` con TLS
- Incluir `servicemonitor.yaml`
- Incluir HPA para autoscaling
- Usar ArgoCD con `argocd-application.yaml`
- Remover Jobs después de primera ejecución exitosa

---

## 🗑️ Archivos que Puedes Eliminar

### Si NO usas ArgoCD:
- `argocd-application.yaml`
- `argocd-application-dev.yaml`
- `argocd-install.yaml`

### Si NO usas Prometheus Operator:
- `servicemonitor.yaml` (pero las annotations en deployments siguen funcionando)

### Si NO quieres autoscaling:
- `hpa-backend.yaml`
- `hpa-frontend.yaml`
- `hpa-queue-short.yaml`

### Después de primera ejecución exitosa:
- `job-configurator.yaml` (puedes removerlo de kustomization.yaml)
- `job-create-site.yaml` (puedes removerlo de kustomization.yaml)

### Siempre puedes eliminar:
- `configmap-gcp.example.yaml` (solo ejemplo)
- `deployment-gcp.example.yaml` (solo ejemplo)

---

## ✅ Checklist de Archivos por Escenario

### Mínimo Viable
- [ ] namespace.yaml
- [ ] configmap.yaml
- [ ] secret.yaml
- [ ] pvc.yaml
- [ ] deployment.yaml
- [ ] service.yaml
- [ ] kustomization.yaml

### Completo Básico
- [ ] Todos los mínimos
- [ ] deployment-frontend.yaml
- [ ] deployment-websocket.yaml
- [ ] deployment-scheduler.yaml
- [ ] deployment-queue-short.yaml
- [ ] deployment-queue-long.yaml
- [ ] job-configurator.yaml (primera vez)
- [ ] job-create-site.yaml (primera vez)

### Producción Completo
- [ ] Todos los básicos
- [ ] ingress.yaml
- [ ] servicemonitor.yaml
- [ ] hpa-backend.yaml (opcional)
- [ ] hpa-frontend.yaml (opcional)
- [ ] hpa-queue-short.yaml (opcional)
- [ ] argocd-application.yaml (si usas ArgoCD)

---

## 📚 Referencias

- [Kubernetes Resources](https://kubernetes.io/docs/concepts/overview/working-with-objects/kubernetes-objects/)
- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

