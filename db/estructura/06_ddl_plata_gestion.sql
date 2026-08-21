-- =====================================================
-- 06 - Capa plata: gestion
-- =====================================================
-- usuario, orden_trabajo e intervencion. Cierran la cadena
-- del dominio: alerta -> orden_trabajo -> intervencion.
-- =====================================================

-- Usuario de la app
-- se conecta con un rol de servicio y pasa la identidad por
-- variable de sesion, que RLS luego consulta.
-- id_ubicacion NULL = alcance sobre todas las plantas
-- (cientifico de datos, administrador).
CREATE TABLE plata.usuario (
    id_usuario    serial       PRIMARY KEY,
    nombre        varchar(100) NOT NULL,
    email         varchar(100),
    rol_negocio   varchar(30)  NOT NULL
        CHECK (rol_negocio IN ('operario', 'tecnico', 'supervisor', 'cientifico_datos', 'administrador')),
    id_ubicacion  integer
        REFERENCES plata.ubicacion (id_ubicacion)
);

-- Orden de trabajo. Deriva de una alerta. NO guarda el
-- dispositivo ni el sensor objetivo: se obtienen de la alerta
-- que la origino (evita dependencia transitiva). Una alerta
-- puede derivar en varias ordenes (relacion 1:N).
CREATE TABLE plata.orden_trabajo (
    id_orden_trabajo  serial       PRIMARY KEY,
    id_alerta         bigint       NOT NULL
        REFERENCES plata.alerta (id_alerta),
    tipo              varchar(30)  NOT NULL
        CHECK (tipo IN ('correctiva', 'preventiva', 'instrumentacion')),
    estado            varchar(20)  NOT NULL
        CHECK (estado IN ('abierta', 'en curso', 'cerrada')),
    fecha_apertura    date,
    fecha_cierre      date
);

-- Intervencion: el trabajo concreto que hizo un tecnico.
-- - observaciones: texto libre en lenguaje natural (dato NO
--   estructurado).
-- - embedding: representacion vectorial de esas observaciones,
--   tipo `vector(384)` de pgvector, para buscar intervenciones
--   pasadas con sintomas parecidos. 384 = dimension
--   de un modelo de embeddings liviano (all-MiniLM-L6-v2);
--   ajustable si se cambia de modelo.
-- - id_usuario: dato personal; el rol cientifico de datos NO lo
--   ve.
CREATE TABLE plata.intervencion (
    id_intervencion   serial       PRIMARY KEY,
    id_orden_trabajo  integer      NOT NULL
        REFERENCES plata.orden_trabajo (id_orden_trabajo),
    id_usuario        integer      NOT NULL
        REFERENCES plata.usuario (id_usuario),
    fecha             date,
    observaciones     text,
    embedding         vector(384)
);
