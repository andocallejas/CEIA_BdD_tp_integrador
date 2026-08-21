-- =====================================================
-- Script maestro: levanta toda la base en orden.
-- =====================================================
-- Uso con Docker (recomendado):
--   docker compose up -d
--   docker compose exec db psql -U postgres -d tp_bdia -f /db/run_all.sql
--
-- Uso con un PostgreSQL local (16 + pgvector):
--   psql -U postgres -d tp_bdia -f db/run_all.sql
--
-- \ir resuelve las rutas relativas a la ubicación de este archivo.
\set ON_ERROR_STOP on

-- Estructura
\ir estructura/00_schemas_extensiones.sql
\ir estructura/01_ddl_plata_catalogos.sql
\ir estructura/02_ddl_plata_activos.sql
\ir estructura/03_ddl_plata_telemetria.sql
\ir estructura/04_ddl_oro_prediccion.sql
\ir estructura/05_ddl_plata_alerta.sql
\ir estructura/06_ddl_plata_gestion.sql
\ir estructura/07_ddl_oro_analitica.sql
\ir estructura/08_ddl_bronce.sql
\ir estructura/11_triggers.sql

-- Particiones e índices
\ir indices_vistas/09_particiones.sql
\ir indices_vistas/10_indices.sql

-- Carga de datos
\ir datos/12_carga_catalogos.sql
\ir datos/13_carga_activos.sql
\ir datos/14_generacion_mediciones.sql
\ir datos/15_calculo_agregados_features.sql
\ir datos/16_carga_modelos_predicciones.sql
\ir datos/17_carga_gestion.sql
\ir datos/18_carga_bronce.sql
