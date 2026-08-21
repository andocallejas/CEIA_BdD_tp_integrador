-- =====================================================
-- 03 - Capa plata: telemetria
-- =====================================================
-- medicion y evento
-- Dependen de sensor (script 02).
-- =====================================================

-- Medicion: una fila por lectura de sensor (formato "largo").
-- - PK compuesta (id_sensor, timestamp_medicion): identifica
--   univocamente cada lectura.
-- - PARTITION BY RANGE sobre el timestamp: la tabla se parte
--   fisicamente en subtablas por mes. Postgres
--   exige que la columna de particion forme parte de la PK,
--   por eso timestamp_medicion esta en la clave.
-- - ~59M filas/anio: el particionado permite consultar y
--   purgar por rango temporal sin tocar toda la tabla.
CREATE TABLE plata.medicion (
    id_sensor           integer      NOT NULL
        REFERENCES plata.sensor (id_sensor),
    timestamp_medicion  timestamptz  NOT NULL,
    valor               numeric(12,4),
    calidad             varchar(20)  NOT NULL
        CHECK (calidad IN ('válida', 'fuera de rango', 'sospechosa')),
    PRIMARY KEY (id_sensor, timestamp_medicion)
) PARTITION BY RANGE (timestamp_medicion);

-- Evento: se genera (trigger) cuando una medicion supera
-- un umbral, viene fuera de rango, o falta reporte.
-- Decision de diseño: NO tiene FK hacia medicion. id_sensor +
-- timestamp_medicion identifican la medicion de origen, pero
-- sin clave foranea, para poder BORRAR mediciones viejas (se
-- purgan al año) sin perder los eventos, que se conservan
-- mucho mas tiempo. Por el mismo motivo se COPIAN valor_medido
-- y umbral_vigente: asi el evento sigue siendo interpretable
-- aunque su medicion ya no exista.
CREATE TABLE plata.evento (
    id_evento            bigserial    PRIMARY KEY,
    id_sensor            integer      NOT NULL
        REFERENCES plata.sensor (id_sensor),
    timestamp_medicion   timestamptz  NOT NULL,
    tipo_evento          varchar(30)  NOT NULL
        CHECK (tipo_evento IN ('umbral superado', 'valor fuera de rango', 'ausencia de reporte')),
    descripcion          text,
    valor_medido         numeric(12,4),
    umbral_vigente       numeric(12,4),
    timestamp_deteccion  timestamptz  NOT NULL
);
