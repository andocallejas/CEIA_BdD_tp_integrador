-- =====================================================
-- 01 - Capa plata: catalogos
-- =====================================================
-- Tablas de referencia, sin dependencias entre si salvo
-- tipo_variable -> unidad. Se crean primero porque el
-- resto del modelo las referencia.
-- =====================================================

-- Unidad de medida (mm/s, C, A, bar, ...).
-- La unidad cuelga del tipo de variable, no del sensor:
-- toda medicion de temperatura se expresa en la misma
-- unidad, sea cual sea el sensor (evita dependencia
-- transitiva y respeta la 3FN; ver Actividad 5).
CREATE TABLE plata.unidad (
    id_unidad   serial       PRIMARY KEY,
    simbolo     varchar(10)  NOT NULL,
    nombre      varchar(50)  NOT NULL
);

-- Tipo de variable fisica medida (vibracion, temperatura,
-- corriente, presion, caudal, velocidad, consumo, tension).
CREATE TABLE plata.tipo_variable (
    id_tipo_variable  serial       PRIMARY KEY,
    nombre            varchar(50)  NOT NULL,
    id_unidad         integer      NOT NULL
        REFERENCES plata.unidad (id_unidad)
);

-- Tipo de equipo (motor electrico, bomba centrifuga,
-- cinta transportadora, tablero electrico, ...).
-- El catalogo puede listar mas tipos de los que luego
-- se pueblan con datos (decision 14).
CREATE TABLE plata.tipo_dispositivo (
    id_tipo_dispositivo  serial       PRIMARY KEY,
    nombre               varchar(50)  NOT NULL,
    descripcion          text
);
