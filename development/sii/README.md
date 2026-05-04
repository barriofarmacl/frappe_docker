# Tooling SII (certificación boleta electrónica)

Scripts auxiliares para generar y validar XML de **Envío de boletas** y **Consumo de folios (RCOF)** fuera del flujo Frappe, útiles para certificación SII y para replicar el proceso con otro contribuyente.

## Requisitos

- Python 3 con las mismas dependencias que `pagosbf` (`lxml`, `signxml`, `cryptography`, etc.), típicamente el venv de `frappe-bench/env`.
- Rutas de certificado y lógica de firma alineadas a lo documentado en `pagosbf` (`tests/certification/E2E_MANUAL.md`).

## Scripts (referencia)

- `build_envio_be_certificacion.py`: construye el envío del set de certificación.
- `build_rcof_certificacion.py`: construye el RCOF a partir de un envío firmado.
- `validate_envio_boleta_xsd.py`: validación contra XSD local (si se mantiene copia bajo `schema_envio_bol/`, preferir no duplicar XSD ya versionados en `pagosbf/public/xsd`).

## Qué no debe versionarse

Ver `.gitignore` en este directorio: CAF (`Folios*.xml`), sets con RUT en nombre, llaves, salidas `out_*`, XML firmados de ejecución local y capturas con timestamp.

El archivo **`Set Prueba BE.txt`** puede mantenerse como referencia genérica del set de pruebas del SII si no contiene datos sensibles del contribuyente.

## Relación con el fork

Este árbol está **allowlisteado** desde el `.gitignore` raíz de `frappe_docker` (`!development/sii/`). Los cambios se guardan en la rama de trabajo BarrioFarma del fork (p. ej. `barriofarma/develop`), no en `frappe-bench/` (las apps `pagosbf` y `barriofarma_app` tienen su propio remoto).
