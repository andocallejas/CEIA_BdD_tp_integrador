-- =====================================================
-- 04 - Capa oro: modelo y prediccion
-- =====================================================
-- Solo las dos tablas de oro que 'plata.alerta' necesita
-- referenciar. El resto de oro (agregados, features,
-- corrida, metrica) se crea en el script 07.
--
-- Por que aca y no mas tarde: plata.alerta tiene una FK
-- hacia oro.prediccion (unica dependencia de plata hacia
-- oro en todo el modelo). Para poder declarar esa FK,
-- oro.prediccion tiene que existir antes que plata.alerta.
-- =====================================================

-- Modelo predictivo. Existe un modelo por tipo de dispositivo
-- (la evolucion de un motor no es comparable con la de un
-- tablero). Los modelos 'retirado' se conservan para poder
-- interpretar predicciones historicas.
CREATE TABLE oro.modelo (
    id_modelo            serial       PRIMARY KEY,
    nombre               varchar(100) NOT NULL,
    version              varchar(20)  NOT NULL,
    id_tipo_dispositivo  integer      NOT NULL
        REFERENCES plata.tipo_dispositivo (id_tipo_dispositivo),
    horizonte_h          integer      NOT NULL,
    estado               varchar(20)  NOT NULL
        CHECK (estado IN ('activo', 'retirado'))
);

-- Prediccion horaria por dispositivo. Un trigger (script 11)
-- crea una alerta cuando score > umbral_aplicado.
-- - score y umbral son probabilidades: CHECK 0..1.
-- - Se guarda umbral_aplicado junto al score para que una
--   prediccion vieja siga siendo interpretable si el umbral
--   cambia despues.
-- - id_dispositivo + ventana_hasta identifican la fila de
--   features usada, pero SIN FK: la tabla de features destino
--   depende del tipo de dispositivo (feature_motor_ventana,
--   feature_bomba_ventana, ...), no es una sola.
CREATE TABLE oro.prediccion (
    id_prediccion         bigserial    PRIMARY KEY,
    id_dispositivo        integer      NOT NULL
        REFERENCES plata.dispositivo (id_dispositivo),
    id_modelo             integer      NOT NULL
        REFERENCES oro.modelo (id_modelo),
    timestamp_prediccion  timestamptz  NOT NULL,
    ventana_desde         timestamptz  NOT NULL,
    ventana_hasta         timestamptz  NOT NULL,
    horizonte_h           integer      NOT NULL,
    score                 numeric(5,4) NOT NULL CHECK (score >= 0 AND score <= 1),
    umbral_aplicado       numeric(5,4) NOT NULL CHECK (umbral_aplicado >= 0 AND umbral_aplicado <= 1)
);
