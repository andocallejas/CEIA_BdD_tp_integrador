-- =====================================================
-- 07 - Capa oro: analitica (agregados, features, trazabilidad)
-- =====================================================
-- Completa la capa oro. modelo y prediccion ya se crearon
-- en el script 04. Aca van:
--   - Agregados: resumenes de la serie por hora y por dia.
--   - Features: formato "ancho" que consume el modelo de ML.
--   - Trazabilidad: corrida_entrenamiento y metrica.
-- Los agregados y features son DESNORMALIZADOS (datos
-- calculados desde plata); la trazabilidad es NORMALIZADA
-- (metadatos de bajo volumen). Ver Informe 05.
-- =====================================================

-- --- Agregados analiticos ---
-- Resumen por hora de cada sensor. PK (id_sensor, hora).
CREATE TABLE oro.agregado_horario (
    id_sensor          integer      NOT NULL
        REFERENCES plata.sensor (id_sensor),
    hora               timestamptz  NOT NULL,
    promedio           numeric(12,4),
    minimo             numeric(12,4),
    maximo             numeric(12,4),
    desvio             numeric(12,4),
    cantidad_lecturas  integer,
    PRIMARY KEY (id_sensor, hora)
);

-- Resumen por dia. Se retiene mas alla del anio de detalle de
-- plata, para analisis interanual sin la serie completa.
CREATE TABLE oro.agregado_diario (
    id_sensor          integer      NOT NULL
        REFERENCES plata.sensor (id_sensor),
    dia                date         NOT NULL,
    promedio           numeric(12,4),
    minimo             numeric(12,4),
    maximo             numeric(12,4),
    desvio             numeric(12,4),
    cantidad_lecturas  integer,
    PRIMARY KEY (id_sensor, dia)
);

-- --- Features para el modelo predictivo ---
-- Una tabla por TIPO de dispositivo: las variables medidas no
-- son comparables entre tipos, y una tabla unica dejaria la
-- mayoria de columnas en NULL (un NULL no es neutro para un
-- modelo). PK (id_dispositivo, ventana_hasta). Ventana de 24h
-- recalculada cada hora. fallo_en_horizonte: etiqueta de
-- entrenamiento, NULL hasta que transcurre el horizonte.

CREATE TABLE oro.feature_motor_ventana (
    id_dispositivo      integer      NOT NULL
        REFERENCES plata.dispositivo (id_dispositivo),
    ventana_hasta       timestamptz  NOT NULL,
    ventana_desde       timestamptz  NOT NULL,
    vib_media           numeric(12,4),
    vib_max             numeric(12,4),
    vib_desvio          numeric(12,4),
    vib_tendencia       numeric(12,4),
    temp_media          numeric(12,4),
    temp_max            numeric(12,4),
    corr_media          numeric(12,4),
    cant_eventos        integer,
    horas_operacion     numeric(6,2),
    fallo_en_horizonte  boolean,
    timestamp_calculo   timestamptz,
    PRIMARY KEY (id_dispositivo, ventana_hasta)
);

CREATE TABLE oro.feature_bomba_ventana (
    id_dispositivo      integer      NOT NULL
        REFERENCES plata.dispositivo (id_dispositivo),
    ventana_hasta       timestamptz  NOT NULL,
    ventana_desde       timestamptz  NOT NULL,
    pres_media          numeric(12,4),
    pres_max            numeric(12,4),
    pres_desvio         numeric(12,4),
    pres_tendencia      numeric(12,4),
    caud_media          numeric(12,4),
    caud_desvio         numeric(12,4),
    temp_media          numeric(12,4),
    temp_max            numeric(12,4),
    cant_eventos        integer,
    horas_operacion     numeric(6,2),
    fallo_en_horizonte  boolean,
    timestamp_calculo   timestamptz,
    PRIMARY KEY (id_dispositivo, ventana_hasta)
);

CREATE TABLE oro.feature_cinta_ventana (
    id_dispositivo      integer      NOT NULL
        REFERENCES plata.dispositivo (id_dispositivo),
    ventana_hasta       timestamptz  NOT NULL,
    ventana_desde       timestamptz  NOT NULL,
    vel_media           numeric(12,4),
    vel_desvio          numeric(12,4),
    vel_tendencia       numeric(12,4),
    corr_media          numeric(12,4),
    corr_max            numeric(12,4),
    cant_eventos        integer,
    horas_operacion     numeric(6,2),
    fallo_en_horizonte  boolean,
    timestamp_calculo   timestamptz,
    PRIMARY KEY (id_dispositivo, ventana_hasta)
);

CREATE TABLE oro.feature_tablero_ventana (
    id_dispositivo      integer      NOT NULL
        REFERENCES plata.dispositivo (id_dispositivo),
    ventana_hasta       timestamptz  NOT NULL,
    ventana_desde       timestamptz  NOT NULL,
    cons_media          numeric(12,4),
    cons_max            numeric(12,4),
    cons_tendencia      numeric(12,4),
    tens_media          numeric(12,4),
    tens_desvio         numeric(12,4),
    cant_eventos        integer,
    horas_operacion     numeric(6,2),
    fallo_en_horizonte  boolean,
    timestamp_calculo   timestamptz,
    PRIMARY KEY (id_dispositivo, ventana_hasta)
);

-- --- Trazabilidad del modelo predictivo (normalizada) ---
-- corrida_entrenamiento: rango_desde/hasta + criterio_seleccion
-- reemplazan la tabla puente de la N:M medicion-corrida
-- (relacion por comprension, ver Informe 05).
CREATE TABLE oro.corrida_entrenamiento (
    id_corrida          bigserial    PRIMARY KEY,
    id_modelo           integer      NOT NULL
        REFERENCES oro.modelo (id_modelo),
    fecha               timestamptz  NOT NULL,
    rango_desde         timestamptz,
    rango_hasta         timestamptz,
    criterio_seleccion  jsonb,
    hiperparametros     jsonb,
    uri_artefacto       text
);

-- metrica: formato largo (una fila por metrica). Admite
-- cualquier indicador sin cambiar el esquema.
CREATE TABLE oro.metrica (
    id_metrica  bigserial    PRIMARY KEY,
    id_corrida  bigint       NOT NULL
        REFERENCES oro.corrida_entrenamiento (id_corrida),
    nombre      varchar(50)  NOT NULL,
    particion   varchar(20)  NOT NULL
        CHECK (particion IN ('entrenamiento', 'validacion', 'test')),
    valor       numeric(12,6)
);
