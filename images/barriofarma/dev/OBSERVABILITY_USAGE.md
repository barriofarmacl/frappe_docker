# 📊 Guía de Uso - Observabilidad en BarrioFarma

## PASO 3.5: Structured Logging

### 🎯 ¿Qué agrega este paso?

Se agrega un módulo de **logging estructurado en JSON** con:
- ✅ Formato JSON para Grafana Loki
- ✅ Integración con OpenTelemetry (trace_id, span_id)
- ✅ Compatible con logging existente de Frappe
- ⚠️ **NO activado por defecto** (opt-in)

### 📍 Ubicación del Módulo

```
/home/frappe/frappe-bench/apps/frappe/frappe/utils/observability_logging.py
```

### 💡 Uso Básico

#### 1. Importar el módulo en tu código Python

```python
from frappe.utils.observability_logging import get_structured_logger

# Crear un logger estructurado
logger = get_structured_logger("barriofarma.mi_modulo")

# Usar como logger normal
logger.info("Usuario autenticado exitosamente")
logger.warning("Inventario bajo", extra={"extra_fields": {"producto_id": "PROD001", "stock": 5}})
logger.error("Error al procesar pago")
```

#### 2. Output en JSON

```json
{
  "timestamp": "2025-10-22T18:45:23.123456Z",
  "level": "INFO",
  "logger": "barriofarma.mi_modulo",
  "message": "Usuario autenticado exitosamente",
  "module": "authentication",
  "function": "login",
  "line": 42,
  "trace_id": "0af7651916cd43dd8448eb211c80319c",
  "span_id": "b7ad6b7169203331"
}
```

### 🔧 Configuración Avanzada

#### Configurar nivel de logging

```python
from frappe.utils.observability_logging import configure_structured_logging

logger = configure_structured_logging(
    level="DEBUG",  # DEBUG, INFO, WARNING, ERROR, CRITICAL
    logger_name="barriofarma.orders",
    enable_console=True
)
```

#### Agregar contexto personalizado

```python
logger.info(
    "Pedido creado",
    extra={
        "extra_fields": {
            "order_id": "ORD-2025-001",
            "customer_id": "CUST-123",
            "total": 15000.50,
            "items": 3
        }
    }
)
```

### 🎨 Integración con Frappe

#### En un DocType

```python
import frappe
from frappe.utils.observability_logging import get_structured_logger

class PedidoVenta(Document):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.logger = get_structured_logger(f"barriofarma.{self.doctype}")
    
    def on_submit(self):
        self.logger.info(
            "Pedido confirmado",
            extra={
                "extra_fields": {
                    "pedido_id": self.name,
                    "cliente": self.customer,
                    "total": self.grand_total
                }
            }
        )
```

#### En un API endpoint

```python
import frappe
from frappe.utils.observability_logging import get_structured_logger

logger = get_structured_logger("barriofarma.api")

@frappe.whitelist()
def validar_stock(producto_id):
    logger.info(
        "Validando stock",
        extra={"extra_fields": {"producto_id": producto_id}}
    )
    
    try:
        # ... lógica de validación ...
        return {"disponible": True}
    except Exception as e:
        logger.exception(
            "Error validando stock",
            extra={"extra_fields": {"producto_id": producto_id}}
        )
        frappe.throw("Error al validar stock")
```

### 📊 Visualización en Grafana Loki

#### Query LogQL básica

```logql
{logger="barriofarma.orders"} | json
```

#### Filtrar por nivel

```logql
{logger=~"barriofarma.*"} | json | level="ERROR"
```

#### Buscar por trace_id

```logql
{logger=~"barriofarma.*"} | json | trace_id="0af7651916cd43dd8448eb211c80319c"
```

#### Métricas de errores

```logql
sum(rate({logger=~"barriofarma.*"} | json | level="ERROR" [5m])) by (module)
```

### ⚠️ Importante

1. **NO reemplaza el logging de Frappe:** Convive con el sistema existente
2. **Opt-in:** Solo se activa donde lo uses explícitamente
3. **Performance:** Overhead mínimo, solo cuando se usa
4. **Producción:** Configurar nivel WARNING o ERROR para reducir volumen

### 🧪 Testing del Módulo

```bash
# Dentro del contenedor
docker-compose exec backend bash

# Ejecutar test del módulo
python /home/frappe/frappe-bench/apps/frappe/frappe/utils/observability_logging.py
```

### 📚 Referencias

- [OpenTelemetry Python Logging](https://opentelemetry.io/docs/instrumentation/python/logging/)
- [Grafana Loki LogQL](https://grafana.com/docs/loki/latest/logql/)
- [Python JSON Logging Best Practices](https://docs.python.org/3/howto/logging-cookbook.html)

---

## PASO 3.6: Prometheus Metrics

### 🎯 ¿Qué agrega este paso?

Se agrega un módulo de **métricas para Prometheus** con:
- ✅ RED Method (Rate, Errors, Duration) para métricas técnicas
- ✅ Métricas de negocio específicas de BarrioFarma
- ✅ Decoradores para instrumentación automática
- ✅ Endpoint `/metrics` para scraping de Prometheus
- ⚠️ **NO activado por defecto** (opt-in)

### 📍 Ubicación del Módulo

```
/home/frappe/frappe-bench/apps/frappe/frappe/utils/observability_metrics.py
```

### 💡 Uso Básico

#### 1. Importar y usar métricas en tu código

```python
from frappe.utils.observability_metrics import (
    record_sale,
    update_inventory_level,
    record_prescription_processed,
    track_request_metrics
)

# Registrar una venta
record_sale("mostrador", "sucursal_centro", 15000.50)

# Actualizar nivel de inventario
update_inventory_level("PROD001", "bodega_principal", 150)

# Registrar procesamiento de receta
record_prescription_processed("aprobada")
```

#### 2. Usar decoradores para instrumentación automática

```python
from frappe.utils.observability_metrics import track_request_metrics, track_business_operation

@track_request_metrics("api.crear_pedido")
def crear_pedido():
    # ... lógica del endpoint
    return {"status": "ok"}

@track_business_operation("pedido")
def procesar_pedido(pedido_id):
    # ... lógica de procesamiento
    return {"status": "ok"}
```

### 📊 Métricas Disponibles

#### Métricas Técnicas (RED Method)

```python
# Rate: Requests per second
http_requests_total{method="POST", endpoint="api.crear_pedido", status_code="200"}

# Errors: Error rate
http_request_errors_total{method="POST", endpoint="api.crear_pedido", error_type="ValueError"}

# Duration: Request latency (histogram)
http_request_duration_seconds{method="POST", endpoint="api.crear_pedido"}
```

#### Métricas de Negocio

```python
# Ventas
barriofarma_sales_total{tipo_venta="mostrador", sucursal="sucursal_centro"}
barriofarma_sales_amount_total{tipo_venta="mostrador", sucursal="sucursal_centro"}

# Inventario
barriofarma_inventory_stock_level{producto_id="PROD001", bodega="bodega_principal"}
barriofarma_inventory_low_stock_alerts_total{producto_id="PROD002"}

# Pedidos
barriofarma_orders_created_total{estado="completado", tipo_cliente="standard"}
barriofarma_orders_processing_duration_seconds{estado="completado"}

# Clientes
barriofarma_customers_active_total{tipo_cliente="particular"}

# Recetas médicas
barriofarma_prescriptions_processed_total{estado_validacion="aprobada"}
```

### 🔧 Integración con Frappe

#### En un DocType

```python
import frappe
from frappe.utils.observability_metrics import record_sale, update_inventory_level

class VentaMostrador(Document):
    def on_submit(self):
        # Registrar la venta en métricas
        record_sale(
            tipo_venta="mostrador",
            sucursal=self.sucursal,
            monto=self.grand_total
        )
        
        # Actualizar inventario
        for item in self.items:
            stock_actual = frappe.db.get_value(
                "Bin",
                {"item_code": item.item_code, "warehouse": item.warehouse},
                "actual_qty"
            )
            update_inventory_level(
                producto_id=item.item_code,
                bodega=item.warehouse,
                stock_actual=stock_actual or 0
            )
```

#### En un API endpoint con decorador

```python
import frappe
from frappe.utils.observability_metrics import track_request_metrics

@frappe.whitelist()
@track_request_metrics("api.validar_receta")
def validar_receta(receta_id):
    """Valida una receta médica"""
    # ... lógica de validación
    return {"valida": True}
```

### 🌐 Exponer Endpoint /metrics

Para exponer las métricas a Prometheus, necesitas crear un endpoint en Frappe:

```python
# En barriofarma_app/barriofarma_app/api.py

import frappe
from frappe.utils.observability_metrics import get_metrics

@frappe.whitelist(allow_guest=True)
def prometheus_metrics():
    """
    Endpoint para Prometheus scraping
    GET /api/method/barriofarma_app.api.prometheus_metrics
    """
    metrics_output, content_type = get_metrics()
    
    frappe.local.response.http_status_code = 200
    frappe.local.response.mimetype = content_type
    frappe.local.response.message = metrics_output.decode('utf-8')
```

Luego accede a: `http://localhost:8080/api/method/barriofarma_app.api.prometheus_metrics`

### 📈 Configuración de Prometheus

Agrega este job a tu `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'barriofarma'
    scrape_interval: 15s
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/api/method/barriofarma_app.api.prometheus_metrics'
```

### 📊 Queries Útiles en Prometheus/Grafana

#### Rate de requests por endpoint

```promql
rate(http_requests_total[5m])
```

#### Error rate

```promql
rate(http_request_errors_total[5m]) / rate(http_requests_total[5m])
```

#### P99 de latencia

```promql
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

#### Ventas por hora

```promql
rate(barriofarma_sales_total[1h])
```

#### Monto total de ventas

```promql
sum(barriofarma_sales_amount_total)
```

#### Productos con stock bajo

```promql
barriofarma_inventory_stock_level < 10
```

### ⚠️ Importante

1. **NO reemplaza métricas de Frappe:** Convive con el sistema existente
2. **Opt-in:** Solo se activa donde lo uses explícitamente
3. **Performance:** Overhead mínimo (~μs por métrica)
4. **Cardinalidad:** Cuidado con labels de alta cardinalidad (IDs únicos)

### 🧪 Testing del Módulo

```bash
# Dentro del contenedor
docker-compose exec backend bash

# Ejecutar test del módulo
python /home/frappe/frappe-bench/apps/frappe/frappe/utils/observability_metrics.py
```

### 📚 Referencias

- [Prometheus Python Client](https://github.com/prometheus/client_python)
- [RED Method](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)

---

**Status:** ✅ Disponible (NO activado por defecto)  
**Versión:** 0.0.1-otel  
**Observabilidad completa:** ✅ OpenTelemetry + Structured Logging + Prometheus Metrics

