"""
Structured Logging for Frappe/ERPNext with OpenTelemetry Context
Paso 3.5 - Observability Integration

Este módulo proporciona logging estructurado en formato JSON con:
- Trace context de OpenTelemetry (trace_id, span_id)
- Campos estándar para Grafana Loki
- Compatible con el logging existente de Frappe
"""

import logging
import json
import sys
from datetime import datetime
from typing import Any, Dict

try:
    from opentelemetry import trace
    OTEL_AVAILABLE = True
except ImportError:
    OTEL_AVAILABLE = False


class StructuredFormatter(logging.Formatter):
    """
    Formateador JSON con contexto de OpenTelemetry
    """
    
    def format(self, record: logging.LogRecord) -> str:
        """
        Formatea el log record como JSON estructurado
        """
        log_data: Dict[str, Any] = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # Agregar trace context si OpenTelemetry está disponible
        if OTEL_AVAILABLE:
            span = trace.get_current_span()
            if span and span.get_span_context().is_valid:
                ctx = span.get_span_context()
                log_data["trace_id"] = format(ctx.trace_id, "032x")
                log_data["span_id"] = format(ctx.span_id, "016x")
                log_data["trace_flags"] = ctx.trace_flags
        
        # Agregar exception info si existe
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        
        # Agregar campos extra del record
        if hasattr(record, "extra_fields"):
            log_data.update(record.extra_fields)
        
        return json.dumps(log_data, default=str, ensure_ascii=False)


def configure_structured_logging(
    level: str = "INFO",
    logger_name: str = None,
    enable_console: bool = True,
) -> logging.Logger:
    """
    Configura structured logging para un logger específico
    
    Args:
        level: Nivel de logging (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        logger_name: Nombre del logger (None = root logger)
        enable_console: Si True, envía logs a stdout
    
    Returns:
        Logger configurado
    """
    logger = logging.getLogger(logger_name)
    logger.setLevel(getattr(logging, level.upper()))
    
    # Limpiar handlers existentes para evitar duplicados
    logger.handlers.clear()
    
    if enable_console:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(StructuredFormatter())
        logger.addHandler(handler)
    
    return logger


def get_structured_logger(name: str) -> logging.Logger:
    """
    Obtiene un logger con structured logging configurado
    
    Args:
        name: Nombre del logger
    
    Returns:
        Logger configurado
    """
    return configure_structured_logging(logger_name=name)


# Ejemplo de uso:
if __name__ == "__main__":
    # Configurar logger
    logger = get_structured_logger("barriofarma.test")
    
    # Ejemplos de logs
    logger.info("Aplicación iniciada")
    logger.debug("Debug message", extra={"extra_fields": {"user_id": "123", "action": "login"}})
    logger.warning("Advertencia de ejemplo")
    logger.error("Error de ejemplo")
    
    try:
        1 / 0
    except Exception:
        logger.exception("Exception capturada")

