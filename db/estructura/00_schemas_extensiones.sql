-- =====================================================
-- TP Integrador BDIA - Caso 3: Monitoreo IoT predictivo
-- 00 - Schemas y extensiones
-- =====================================================
-- Arquitectura Medallion: cada capa de madurez del dato
-- es un schema separado dentro de la MISMA base de datos.
--   bronce -> dato crudo, tal como llega, sin validar
--   plata  -> dato validado y normalizado (3FN)
--   oro    -> dato analitico, desnormalizado para lectura
-- =====================================================

-- La extension pgvector agrega el tipo de dato `vector`,
-- necesario para el campo intervencion.embedding (Actividad 9).
CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS bronce;
CREATE SCHEMA IF NOT EXISTS plata;
CREATE SCHEMA IF NOT EXISTS oro;
