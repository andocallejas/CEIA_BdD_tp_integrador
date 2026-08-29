-- =====================================================
-- 40 - Seguridad: roles, RLS y ocultamiento de columnas
-- =====================================================
-- Se ejecuta aparte del run_all. Aísla los datos por planta y
-- oculta la identidad del técnico al científico de datos.

-- Roles (sin login): la app se conecta como app_servicio y pasa la
-- identidad del usuario final por variable de sesión app.usuario_id.
CREATE ROLE app_servicio NOLOGIN;
CREATE ROLE rol_cientifico NOLOGIN;

GRANT USAGE ON SCHEMA plata, oro TO app_servicio, rol_cientifico;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA plata TO app_servicio;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA plata TO app_servicio;
GRANT SELECT ON ALL TABLES IN SCHEMA oro TO app_servicio;

-- Funciones auxiliares para resolver la planta.
CREATE OR REPLACE FUNCTION plata.fn_planta_de_ubicacion(p_ubic integer)
RETURNS integer LANGUAGE sql STABLE AS $$
    WITH RECURSIVE anc AS (
        SELECT id_ubicacion, id_ubicacion_padre, nivel
        FROM plata.ubicacion WHERE id_ubicacion = p_ubic
        UNION ALL
        SELECT u.id_ubicacion, u.id_ubicacion_padre, u.nivel
        FROM plata.ubicacion u JOIN anc a ON u.id_ubicacion = a.id_ubicacion_padre
    )
    SELECT id_ubicacion FROM anc WHERE nivel = 'planta' LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION plata.fn_planta_de_dispositivo(p_disp integer)
RETURNS integer LANGUAGE sql STABLE AS $$
    SELECT plata.fn_planta_de_ubicacion(d.id_ubicacion)
    FROM plata.dispositivo d WHERE d.id_dispositivo = p_disp;
$$;

-- Datos del usuario actual, tomados de la variable de sesión.
CREATE OR REPLACE FUNCTION plata.fn_planta_usuario_actual()
RETURNS integer LANGUAGE sql STABLE AS $$
    SELECT plata.fn_planta_de_ubicacion(u.id_ubicacion)
    FROM plata.usuario u
    WHERE u.id_usuario = current_setting('app.usuario_id', true)::integer;
$$;

CREATE OR REPLACE FUNCTION plata.fn_usuario_es_global()
RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT coalesce(bool_or(u.id_ubicacion IS NULL), false)
    FROM plata.usuario u
    WHERE u.id_usuario = current_setting('app.usuario_id', true)::integer;
$$;

-- RLS sobre alerta: cada usuario ve las alertas de su planta; los
-- usuarios globales (científico, admin) ven todas.
ALTER TABLE plata.alerta ENABLE ROW LEVEL SECURITY;
CREATE POLICY alerta_por_planta ON plata.alerta
    FOR ALL TO app_servicio
    USING (
        plata.fn_usuario_es_global()
        OR plata.fn_planta_de_dispositivo(id_dispositivo) = plata.fn_planta_usuario_actual()
    )
    WITH CHECK (
        plata.fn_usuario_es_global()
        OR plata.fn_planta_de_dispositivo(id_dispositivo) = plata.fn_planta_usuario_actual()
    );

-- RLS sobre intervencion: misma regla, resolviendo la planta por la
-- cadena intervencion -> orden_trabajo -> alerta -> dispositivo. Es lo
-- que hace que la búsqueda vectorial no cruce plantas (decisión 10).
ALTER TABLE plata.intervencion ENABLE ROW LEVEL SECURITY;
CREATE POLICY intervencion_por_planta ON plata.intervencion
    FOR ALL TO app_servicio
    USING (
        plata.fn_usuario_es_global()
        OR plata.fn_planta_de_dispositivo(
               (SELECT a.id_dispositivo
                FROM plata.orden_trabajo ot
                JOIN plata.alerta a ON a.id_alerta = ot.id_alerta
                WHERE ot.id_orden_trabajo = intervencion.id_orden_trabajo)
           ) = plata.fn_planta_usuario_actual()
    );

-- Ocultamiento de la identidad del técnico al científico de datos.
-- Mecanismo elegido: vista en oro que no proyecta id_usuario.
CREATE OR REPLACE VIEW oro.v_intervencion AS
SELECT id_intervencion, id_orden_trabajo, fecha, observaciones, embedding
FROM plata.intervencion;

GRANT SELECT ON oro.v_intervencion TO rol_cientifico;

-- Alternativa (documentada): permiso a nivel de columna en vez de vista.
--   REVOKE SELECT ON plata.intervencion FROM rol_cientifico;
--   GRANT SELECT (id_intervencion, id_orden_trabajo, fecha, observaciones, embedding)
--       ON plata.intervencion TO rol_cientifico;
