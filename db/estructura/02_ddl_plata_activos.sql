-- =====================================================
-- 02 - Capa plata: activos
-- =====================================================
-- Ubicaciones, dispositivos, sensores y la configuracion
-- historizada de cada dispositivo. Dependen de los
-- catalogos (script 01), por eso van despues.
-- =====================================================

-- Ubicacion: jerarquia autoreferencial planta > area > linea.
-- id_ubicacion_padre apunta a otra fila de la MISMA tabla
-- (NULL en el nivel planta). Recorriendo hacia arriba se
-- llega siempre a la planta, base del aislamiento por RLS.
CREATE TABLE plata.ubicacion (
    id_ubicacion        serial       PRIMARY KEY,
    nombre              varchar(100) NOT NULL,
    nivel               varchar(20)  NOT NULL
        CHECK (nivel IN ('planta', 'area', 'linea')),
    id_ubicacion_padre  integer
        REFERENCES plata.ubicacion (id_ubicacion)
);

-- Dispositivo: el equipo fisico (motor, bomba, etc.).
-- El estado evita que un equipo detenido de forma
-- planificada genere eventos de falta de reporte.
CREATE TABLE plata.dispositivo (
    id_dispositivo       serial       PRIMARY KEY,
    nombre               varchar(100) NOT NULL,
    id_tipo_dispositivo  integer      NOT NULL
        REFERENCES plata.tipo_dispositivo (id_tipo_dispositivo),
    id_ubicacion         integer      NOT NULL
        REFERENCES plata.ubicacion (id_ubicacion),
    estado               varchar(20)  NOT NULL
        CHECK (estado IN ('operativo', 'en mantenimiento', 'dado de baja')),
    fecha_alta           date
);

-- Sensor: instrumento montado sobre un dispositivo.
-- Un sensor mide UNA sola variable (id_tipo_variable).
CREATE TABLE plata.sensor (
    id_sensor         serial       PRIMARY KEY,
    id_dispositivo    integer      NOT NULL
        REFERENCES plata.dispositivo (id_dispositivo),
    id_tipo_variable  integer      NOT NULL
        REFERENCES plata.tipo_variable (id_tipo_variable),
    nombre            varchar(100) NOT NULL,
    estado            varchar(20)  NOT NULL
        CHECK (estado IN ('activo', 'fuera de servicio'))
);

-- Configuracion historizada del dispositivo.
-- No se pisa la version anterior: cada cambio de umbrales
-- inserta una fila nueva con su ventana de vigencia
-- (valido_desde / valido_hasta). valido_hasta NULL = vigente.
-- Los umbrales viven dentro de `parametros` como JSONB,
-- lo que permite distintos umbrales segun el tipo de equipo
-- sin cambiar el esquema.
CREATE TABLE plata.configuracion_dispositivo (
    id_configuracion  serial       PRIMARY KEY,
    id_dispositivo    integer      NOT NULL
        REFERENCES plata.dispositivo (id_dispositivo),
    parametros        jsonb        NOT NULL,
    valido_desde      timestamptz  NOT NULL,
    valido_hasta      timestamptz
);

-- Regla de integridad: a lo sumo UNA configuracion vigente
-- por dispositivo. Un indice unico parcial (solo sobre las
-- filas con valido_hasta IS NULL) lo garantiza a nivel de
-- base: permite muchas versiones historicas pero una sola
-- abierta por equipo.
CREATE UNIQUE INDEX uq_config_vigente
    ON plata.configuracion_dispositivo (id_dispositivo)
    WHERE valido_hasta IS NULL;
