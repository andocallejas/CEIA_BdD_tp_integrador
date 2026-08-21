-- =====================================================
-- 11 - Triggers
-- =====================================================
-- La base sólo registra hechos (eventos, alertas). La gestión
-- posterior (agrupar, asignar, cerrar) vive en la aplicación.

-- 1) medición -> evento. AFTER INSERT sobre plata.medicion.
-- Corre sobre datos ya validados (plata, no bronce). Si la
-- lectura viene con mala calidad, genera un evento de dato
-- apuntado al sensor; si supera el umbral vigente de su
-- variable, genera un evento de umbral. Copia valor y umbral
-- para que el evento sobreviva al borrado anual de mediciones.
CREATE OR REPLACE FUNCTION plata.fn_detectar_evento()
RETURNS trigger AS $$
DECLARE
    v_variable    text;
    v_dispositivo integer;
    v_params      jsonb;
    v_umbral      numeric;
BEGIN
    SELECT tv.nombre, s.id_dispositivo
      INTO v_variable, v_dispositivo
      FROM plata.sensor s
      JOIN plata.tipo_variable tv ON tv.id_tipo_variable = s.id_tipo_variable
     WHERE s.id_sensor = NEW.id_sensor;

    IF NEW.calidad IN ('fuera de rango', 'sospechosa') THEN
        INSERT INTO plata.evento
            (id_sensor, timestamp_medicion, tipo_evento, descripcion,
             valor_medido, umbral_vigente, timestamp_deteccion)
        VALUES
            (NEW.id_sensor, NEW.timestamp_medicion, 'valor fuera de rango',
             'Lectura de ' || v_variable || ' marcada como ' || NEW.calidad,
             NEW.valor, NULL, NEW.timestamp_medicion + interval '1 second');
        RETURN NEW;
    END IF;

    SELECT parametros INTO v_params
      FROM plata.configuracion_dispositivo
     WHERE id_dispositivo = v_dispositivo AND valido_hasta IS NULL;

    v_umbral := (v_params -> v_variable ->> 'umbral_alerta')::numeric;

    IF v_umbral IS NOT NULL AND NEW.valor > v_umbral THEN
        INSERT INTO plata.evento
            (id_sensor, timestamp_medicion, tipo_evento, descripcion,
             valor_medido, umbral_vigente, timestamp_deteccion)
        VALUES
            (NEW.id_sensor, NEW.timestamp_medicion, 'umbral superado',
             v_variable || ' por encima del umbral de alerta',
             NEW.valor, v_umbral, NEW.timestamp_medicion + interval '1 second');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_detectar_evento
    AFTER INSERT ON plata.medicion
    FOR EACH ROW EXECUTE FUNCTION plata.fn_detectar_evento();

-- 2) predicción -> alerta. AFTER INSERT sobre oro.prediccion.
-- Si el score supera el umbral, abre una alerta predictiva.
-- Cruza schemas (vive en oro y escribe en plata): el rol que
-- ejecuta necesita permisos en ambos (ver Actividad 11).
CREATE OR REPLACE FUNCTION oro.fn_generar_alerta_predictiva()
RETURNS trigger AS $$
BEGIN
    IF NEW.score > NEW.umbral_aplicado THEN
        INSERT INTO plata.alerta
            (id_dispositivo, id_prediccion, origen, severidad, estado, timestamp_apertura)
        VALUES
            (NEW.id_dispositivo, NEW.id_prediccion, 'predictivo',
             CASE WHEN NEW.score >= 0.80 THEN 'alta'
                  WHEN NEW.score >= 0.70 THEN 'media'
                  ELSE 'baja' END,
             'abierta', NEW.timestamp_prediccion);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_generar_alerta_predictiva
    AFTER INSERT ON oro.prediccion
    FOR EACH ROW EXECUTE FUNCTION oro.fn_generar_alerta_predictiva();
