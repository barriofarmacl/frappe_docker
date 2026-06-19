# Informe de resultados - Hybrid PoC (POC-001)

**Issue:** [whiteboard #46](https://github.com/barriofarmacl/whiteboard/issues/46)  
**Fecha:** Pendiente de cierre  
**Estado:** Pendiente de ejecucion de pruebas

---

## Resumen

El PoC se considerara exitoso cuando todas las pruebas P1-P4 (y opcionalmente P5) pasen y la latencia a Cloud SQL este dentro del umbral acordado (< 200 ms para PoC). Resultados y recomendacion se actualizaran tras la ejecucion.

## Resultados de pruebas

Definicion de pruebas: [HYBRID_POC_SCOPE.md](HYBRID_POC_SCOPE.md).

| ID | Prueba | Resultado | Metricas / Notas |
|----|--------|-----------|-------------------|
| P1 | Conectividad Cloud SQL | Pendiente | Latencia (ms): - |
| P2 | Creacion de sitio | Pendiente | Tiempo aprox: - |
| P3 | Acceso UI | Pendiente | HTTP 200: - |
| P4 | Login | Pendiente | - |
| P5 | Transaccion basica (opcional) | Pendiente | - |

**Entorno de ejecucion (cuando se complete):** Imagen, compose file, region Cloud SQL, fecha.

## Recomendacion (go/no-go)

- **Recomendacion:** Pendiente (completar tras ejecutar pruebas).
- **Opciones:** Go / No-go / Go con condiciones (ej. restringir `authorized_networks` y validar Auth Proxy antes de siguiente fase).

## Proximos pasos sugeridos

Segun [HYBRID_POC_README.md](../HYBRID_POC_README.md#siguiente-paso-produccion):

1. **Cloud SQL Auth Proxy** en lugar de IP publica.
2. **VPN site-to-site** para multiples sedes si aplica.
3. **Backups automaticos** con retencion adecuada.
4. **Monitoreo** con Cloud Monitoring y Grafana.
5. **Alta disponibilidad** con Cloud SQL HA si se lleva a produccion.

## Lecciones aprendidas

*(Completar tras la validacion; ver tambien seccion en [HYBRID_POC_README.md](../HYBRID_POC_README.md#lecciones-aprendidas).)*

- **Que funciono bien:** A completar (ej. integracion Cloud SQL + Compose, script de certificados, Redis local vs BD en cloud).
- **Problemas encontrados:** A completar (ej. autorizacion de IP, compatibilidad MySQL 8.0 vs MariaDB, tiempos de creacion de sitio).
- **Recomendaciones para produccion:** Restringir `authorized_networks`, usar Cloud SQL Auth Proxy, Secret Manager, backups, monitoreo.
