"""
Prometheus Metrics for Frappe/ERPNext - RED Method + Business Metrics
Paso 3.6 - Observability Integration

Este módulo proporciona métricas para Prometheus siguiendo:
- RED Method (Rate, Errors, Duration) para métricas técnicas
- Métricas de negocio específicas de BarrioFarma
- Endpoint /metrics para Prometheus scraping
"""

from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
from prometheus_client import CollectorRegistry, CONTENT_TYPE_LATEST
import time
from functools import wraps
from typing import Callable, Any


# =============================================================================
# Métricas Técnicas - RED Method
# =============================================================================

# Rate: Requests per second
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code']
)

# Errors: Error rate
http_request_errors_total = Counter(
    'http_request_errors_total',
    'Total HTTP request errors',
    ['method', 'endpoint', 'error_type']
)

# Duration: Request latency
http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint'],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0)
)

# =============================================================================
# Métricas de Negocio - BarrioFarma
# =============================================================================

# Ventas
sales_total = Counter(
    'barriofarma_sales_total',
    'Total de ventas realizadas',
    ['tipo_venta', 'sucursal']
)

sales_amount_total = Counter(
    'barriofarma_sales_amount_total',
    'Monto total de ventas en pesos',
    ['tipo_venta', 'sucursal']
)

# Inventario
inventory_stock_level = Gauge(
    'barriofarma_inventory_stock_level',
    'Nivel de stock actual de productos',
    ['producto_id', 'bodega']
)

inventory_low_stock_alerts = Counter(
    'barriofarma_inventory_low_stock_alerts_total',
    'Total de alertas de stock bajo',
    ['producto_id']
)

# Pedidos
orders_created_total = Counter(
    'barriofarma_orders_created_total',
    'Total de pedidos creados',
    ['estado', 'tipo_cliente']
)

orders_processing_duration_seconds = Histogram(
    'barriofarma_orders_processing_duration_seconds',
    'Duración del procesamiento de pedidos',
    ['estado'],
    buckets=(1.0, 5.0, 10.0, 30.0, 60.0, 120.0, 300.0)
)

# Clientes
customers_active_total = Gauge(
    'barriofarma_customers_active_total',
    'Total de clientes activos',
    ['tipo_cliente']
)

# Recetas médicas
prescriptions_processed_total = Counter(
    'barriofarma_prescriptions_processed_total',
    'Total de recetas médicas procesadas',
    ['estado_validacion']
)


# =============================================================================
# Decoradores para Instrumentación Automática
# =============================================================================

def track_request_metrics(endpoint: str):
    """
    Decorador para trackear métricas HTTP automáticamente
    
    Args:
        endpoint: Nombre del endpoint (ej: "api.crear_pedido")
    
    Example:
        @track_request_metrics("api.crear_pedido")
        def crear_pedido():
            # ... lógica del endpoint
            return {"status": "ok"}
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            method = "POST"  # Por defecto, ajustar según necesidad
            start_time = time.time()
            status_code = "200"
            
            try:
                result = func(*args, **kwargs)
                http_requests_total.labels(
                    method=method,
                    endpoint=endpoint,
                    status_code=status_code
                ).inc()
                return result
            
            except Exception as e:
                status_code = "500"
                error_type = type(e).__name__
                http_request_errors_total.labels(
                    method=method,
                    endpoint=endpoint,
                    error_type=error_type
                ).inc()
                raise
            
            finally:
                duration = time.time() - start_time
                http_request_duration_seconds.labels(
                    method=method,
                    endpoint=endpoint
                ).observe(duration)
        
        return wrapper
    return decorator


def track_business_operation(operation_type: str):
    """
    Decorador para trackear operaciones de negocio
    
    Args:
        operation_type: Tipo de operación (pedido, venta, receta, etc)
    
    Example:
        @track_business_operation("pedido")
        def procesar_pedido(pedido_id):
            # ... lógica de procesamiento
            return {"status": "ok"}
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            start_time = time.time()
            
            try:
                result = func(*args, **kwargs)
                
                # Registrar métrica según tipo de operación
                if operation_type == "pedido":
                    orders_created_total.labels(
                        estado="completado",
                        tipo_cliente="standard"
                    ).inc()
                
                return result
            
            finally:
                duration = time.time() - start_time
                if operation_type == "pedido":
                    orders_processing_duration_seconds.labels(
                        estado="completado"
                    ).observe(duration)
        
        return wrapper
    return decorator


# =============================================================================
# Funciones Helper para Métricas Manuales
# =============================================================================

def record_sale(tipo_venta: str, sucursal: str, monto: float):
    """
    Registra una venta
    
    Args:
        tipo_venta: Tipo de venta (mostrador, domicilio, receta)
        sucursal: Nombre de la sucursal
        monto: Monto de la venta en pesos
    """
    sales_total.labels(tipo_venta=tipo_venta, sucursal=sucursal).inc()
    sales_amount_total.labels(tipo_venta=tipo_venta, sucursal=sucursal).inc(monto)


def update_inventory_level(producto_id: str, bodega: str, stock_actual: int):
    """
    Actualiza el nivel de stock de un producto
    
    Args:
        producto_id: ID del producto
        bodega: Nombre de la bodega
        stock_actual: Stock actual del producto
    """
    inventory_stock_level.labels(producto_id=producto_id, bodega=bodega).set(stock_actual)


def record_low_stock_alert(producto_id: str):
    """
    Registra una alerta de stock bajo
    
    Args:
        producto_id: ID del producto con stock bajo
    """
    inventory_low_stock_alerts.labels(producto_id=producto_id).inc()


def record_prescription_processed(estado_validacion: str):
    """
    Registra el procesamiento de una receta médica
    
    Args:
        estado_validacion: Estado de validación (aprobada, rechazada, pendiente)
    """
    prescriptions_processed_total.labels(estado_validacion=estado_validacion).inc()


def update_active_customers(tipo_cliente: str, count: int):
    """
    Actualiza el contador de clientes activos
    
    Args:
        tipo_cliente: Tipo de cliente (particular, corporativo)
        count: Número de clientes activos
    """
    customers_active_total.labels(tipo_cliente=tipo_cliente).set(count)


# =============================================================================
# Endpoint para Prometheus
# =============================================================================

def get_metrics() -> tuple:
    """
    Genera las métricas en formato Prometheus
    
    Returns:
        Tuple con (content, content_type) para responder HTTP request
    """
    return generate_latest(REGISTRY), CONTENT_TYPE_LATEST


# =============================================================================
# Testing y Ejemplos
# =============================================================================

if __name__ == "__main__":
    print("=== Testing Prometheus Metrics ===\n")
    
    # Simular algunas métricas
    print("1. Registrando ventas...")
    record_sale("mostrador", "sucursal_centro", 15000.50)
    record_sale("domicilio", "sucursal_centro", 8500.00)
    record_sale("receta", "sucursal_norte", 12300.75)
    
    print("2. Actualizando inventario...")
    update_inventory_level("PROD001", "bodega_principal", 150)
    update_inventory_level("PROD002", "bodega_principal", 5)
    record_low_stock_alert("PROD002")
    
    print("3. Registrando recetas...")
    record_prescription_processed("aprobada")
    record_prescription_processed("aprobada")
    record_prescription_processed("rechazada")
    
    print("4. Actualizando clientes activos...")
    update_active_customers("particular", 1250)
    update_active_customers("corporativo", 45)
    
    print("\n=== Métricas en formato Prometheus ===\n")
    metrics_output, _ = get_metrics()
    print(metrics_output.decode('utf-8'))

