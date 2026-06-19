-- ============================================================================
-- Script para crear usuario de monitoreo para MariaDB Exporter
-- ============================================================================
-- Este usuario tiene permisos limitados solo para métricas de lectura
-- Ejecutar dentro del contenedor db después de que MariaDB esté listo
-- ============================================================================

-- Crear usuario 'exporter' con contraseña 'bfdb123'
-- MAX_USER_CONNECTIONS limita conexiones simultáneas del exporter
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY 'bfdb123' WITH MAX_USER_CONNECTIONS 3;

-- Otorgar permisos necesarios para métricas:
-- - PROCESS: Para ver procesos y queries activas
-- - REPLICATION CLIENT: Para métricas de replicación (si aplica)
-- - SELECT: Para métricas de estado y variables del sistema
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';

-- Aplicar cambios
FLUSH PRIVILEGES;

-- Verificar que el usuario fue creado
SELECT User, Host FROM mysql.user WHERE User = 'exporter';

