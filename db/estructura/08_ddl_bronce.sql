-- =====================================================
-- 08 - Capa bronce: ingesta cruda
-- =====================================================
-- Recibe el dato tal como llega, sin validar. SIN claves
-- foraneas (en esta capa no se garantizan las referencias) y
-- SIN esquema declarado sobre el contenido: el payload va como
-- JSONB. No depende de nada, puede crearse en cualquier momento.
--
-- Dos tablas porque los patrones de llegada son muy distintos:
-- las mediciones llegan constantemente; los cambios de
-- configuracion son esporadicos y manuales.
-- =====================================================

-- Mediciones crudas tal como llegan del sensor.
CREATE TABLE bronce.medicion_cruda (
    id_medicion_cruda    bigserial    PRIMARY KEY,
    payload              jsonb        NOT NULL,
    timestamp_recepcion  timestamptz  NOT NULL,
    procesado            boolean      NOT NULL DEFAULT false,
    error_validacion     text
);

-- Configuracion de sensores cruda (umbrales, calibracion).
CREATE TABLE bronce.configuracion_cruda (
    id_configuracion_cruda  bigserial    PRIMARY KEY,
    payload                 jsonb        NOT NULL,
    timestamp_recepcion     timestamptz  NOT NULL,
    procesado               boolean      NOT NULL DEFAULT false
);
