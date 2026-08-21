-- =====================================================
-- 05 - Capa plata: alerta
-- =====================================================
-- Se crea despues de oro.prediccion (script 04) porque la
-- referencia. Es el punto de union de las dos vias de
-- deteccion: por umbral (via evento) o predictiva (via
-- prediccion).
--
-- Doble origen (decision 23):
-- - id_evento     -> alerta nacida de un umbral superado.
-- - id_prediccion -> alerta nacida de una prediccion de falla.
-- Cada alerta tiene UN solo origen. Un mismo dispositivo puede
-- tener varias alertas abiertas a la vez, incluso de origenes
-- distintos (un umbral y una prediccion son confirmacion
-- cruzada, no duplicacion).
--
-- id_dispositivo es redundante (derivable via evento->sensor o
-- via prediccion), pero se materializa a proposito: RLS evalua
-- fila por fila en cada consulta, y sin esta columna el camino
-- hasta la planta se bifurcaria segun el origen (decision 26).
CREATE TABLE plata.alerta (
    id_alerta            bigserial    PRIMARY KEY,
    id_dispositivo       integer      NOT NULL
        REFERENCES plata.dispositivo (id_dispositivo),
    id_sensor            integer
        REFERENCES plata.sensor (id_sensor),
    id_evento            bigint
        REFERENCES plata.evento (id_evento),
    id_prediccion        bigint
        REFERENCES oro.prediccion (id_prediccion),
    origen               varchar(20)  NOT NULL
        CHECK (origen IN ('umbral', 'predictivo')),
    severidad            varchar(20)  NOT NULL
        CHECK (severidad IN ('baja', 'media', 'alta')),
    estado               varchar(20)  NOT NULL
        CHECK (estado IN ('abierta', 'en revisión', 'cerrada')),
    timestamp_apertura   timestamptz  NOT NULL,
    timestamp_cierre     timestamptz,

    -- Exactamente UNO entre id_evento e id_prediccion presente.
    CONSTRAINT chk_origen_unico CHECK (
        (id_evento IS NOT NULL AND id_prediccion IS NULL)
     OR (id_evento IS NULL     AND id_prediccion IS NOT NULL)
    ),
    -- El campo 'origen' tiene que ser coherente con cual FK esta poblada.
    CONSTRAINT chk_origen_coherente CHECK (
        (origen = 'umbral'     AND id_evento     IS NOT NULL)
     OR (origen = 'predictivo' AND id_prediccion IS NOT NULL)
    )
);
