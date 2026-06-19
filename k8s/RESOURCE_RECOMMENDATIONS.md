# 💾 Recomendaciones de Recursos - BarrioFarma

## 📊 Análisis de Recursos por Componente

### Backend (Gunicorn)
**Uso típico:** Alto consumo de CPU y memoria
- Procesa requests HTTP
- Ejecuta lógica de negocio Python
- Maneja conexiones a DB y Redis
- Genera métricas Prometheus

**Recomendación:**
- Requests: `1Gi` memoria, `500m` CPU
- Limits: `4Gi` memoria, `2000m` CPU

### Frontend (Nginx)
**Uso típico:** Muy bajo consumo
- Solo reverse proxy
- Servir archivos estáticos
- Muy eficiente en recursos

**Recomendación:**
- Requests: `128Mi` memoria, `100m` CPU
- Limits: `256Mi` memoria, `500m` CPU

### WebSocket (SocketIO)
**Uso típico:** Moderado consumo de CPU
- Maneja conexiones persistentes
- Broadcasting de mensajes
- Node.js es eficiente pero necesita CPU para muchas conexiones

**Recomendación:**
- Requests: `256Mi` memoria, `200m` CPU
- Limits: `512Mi` memoria, `1000m` CPU

### Scheduler
**Uso típico:** Bajo consumo, picos ocasionales
- Ejecuta tareas programadas
- Mayormente idle, con picos cuando ejecuta jobs

**Recomendación:**
- Requests: `256Mi` memoria, `100m` CPU
- Limits: `512Mi` memoria, `500m` CPU

### Queue Short Workers
**Uso típico:** Moderado consumo
- Procesa tareas rápidas (< 1 minuto)
- Alto throughput
- Necesita recursos para procesar rápido

**Recomendación:**
- Requests: `512Mi` memoria, `250m` CPU
- Limits: `1Gi` memoria, `1000m` CPU

### Queue Long Workers
**Uso típico:** Alto consumo
- Procesa tareas pesadas (reportes, exports, etc.)
- Puede usar mucha memoria para procesar datos grandes
- Necesita más recursos

**Recomendación:**
- Requests: `1Gi` memoria, `500m` CPU
- Limits: `2Gi` memoria, `2000m` CPU

### Jobs

#### Configurator
**Uso típico:** Muy bajo, ejecuta una vez
- Solo escribe archivos de configuración
- Muy rápido

**Recomendación:**
- Requests: `256Mi` memoria, `100m` CPU
- Limits: `512Mi` memoria, `500m` CPU

#### Create Site
**Uso típico:** Alto consumo temporal
- Instala ERPNext y BarrioFarma App
- Ejecuta migraciones de DB
- Puede tardar 5-10 minutos

**Recomendación:**
- Requests: `1Gi` memoria, `500m` CPU
- Limits: `4Gi` memoria, `2000m` CPU

## 📈 Resumen de Ajustes

| Componente | Requests Actual | Requests Recomendado | Limits Actual | Limits Recomendado |
|------------|----------------|---------------------|---------------|-------------------|
| Backend | 512Mi/250m | **1Gi/500m** | 2Gi/1000m | **4Gi/2000m** |
| Frontend | 256Mi/100m | **128Mi/100m** | 512Mi/500m | **256Mi/500m** |
| WebSocket | 256Mi/100m | **256Mi/200m** | 512Mi/500m | **512Mi/1000m** |
| Scheduler | 256Mi/100m | **256Mi/100m** ✅ | 512Mi/500m | **512Mi/500m** ✅ |
| Queue Short | 256Mi/100m | **512Mi/250m** | 512Mi/500m | **1Gi/1000m** |
| Queue Long | 512Mi/250m | **1Gi/500m** | 1Gi/1000m | **2Gi/2000m** |
| Configurator | 256Mi/100m | **256Mi/100m** ✅ | 512Mi/500m | **512Mi/500m** ✅ |
| Create Site | 512Mi/250m | **1Gi/500m** | 2Gi/1000m | **4Gi/2000m** |

## 🎯 Justificación

### Aumentos de Recursos

**Backend (+100% memoria requests, +100% CPU requests):**
- Es el componente más crítico
- Maneja toda la lógica de negocio
- Necesita buffer para picos de carga
- Más CPU para procesar requests concurrentes

**Queue Short (+100% memoria, +150% CPU):**
- Procesa muchas tareas rápidas
- Más CPU = más throughput
- Más memoria para manejar múltiples tareas simultáneas

**Queue Long (+100% memoria, +100% CPU):**
- Procesa tareas pesadas (reportes, exports)
- Necesita más memoria para datasets grandes
- Más CPU para procesar más rápido

**Create Site (+100% memoria, +100% CPU):**
- Instalación inicial es pesada
- Ejecuta migraciones de DB
- Más recursos = instalación más rápida

**WebSocket (+100% CPU):**
- Maneja conexiones persistentes
- Broadcasting requiere CPU
- Node.js es eficiente en memoria pero necesita CPU

### Reducciones de Recursos

**Frontend (-50% memoria):**
- Nginx es muy eficiente
- Solo hace proxy, no procesa lógica
- 128Mi es suficiente para Nginx

## 🔄 Escalabilidad

### HPA (Horizontal Pod Autoscaler) Recomendado

```yaml
# Backend
minReplicas: 2
maxReplicas: 10
targetCPUUtilization: 70%
targetMemoryUtilization: 80%

# Frontend
minReplicas: 2
maxReplicas: 5
targetCPUUtilization: 70%

# Queue Short
minReplicas: 2
maxReplicas: 5
targetCPUUtilization: 70%
```

## 💰 Estimación de Costos

Con estos recursos y réplicas:
- **Total Requests:** ~5.5Gi memoria, ~2.2 CPU cores
- **Total Limits:** ~12Gi memoria, ~8 CPU cores
- **Por nodo GKE (e2-standard-4):** 4 vCPU, 16Gi RAM
- **Nodos necesarios:** 2-3 nodos (con overhead del sistema)

## 📝 Notas

- Estos valores son para **producción**
- Para **desarrollo/staging**, reducir a 50-70% de estos valores
- Monitorear con Prometheus y ajustar según métricas reales
- Considerar usar VPA (Vertical Pod Autoscaler) para ajuste automático

