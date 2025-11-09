-- setup_workers.sql
-- Script para configurar los workers de Citus

-- Crear la extensión Citus en cada worker
CREATE EXTENSION IF NOT EXISTS citus;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verificar que las extensiones están creadas
SELECT extname FROM pg_extension WHERE extname IN ('citus', 'uuid-ossp');
