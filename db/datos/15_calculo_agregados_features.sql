-- =====================================================
-- 15 - Cálculo de agregados y features (desde plata)
-- =====================================================
-- Se calculan con INSERT ... SELECT sobre plata.medicion.
-- Si se pierden, se recalculan (son datos derivados).

-- Agregado horario por sensor.
INSERT INTO oro.agregado_horario (id_sensor, hora, promedio, minimo, maximo, desvio, cantidad_lecturas)
SELECT id_sensor, date_trunc('hour', timestamp_medicion),
       avg(valor), min(valor), max(valor), coalesce(stddev_pop(valor), 0), count(*)
FROM plata.medicion
GROUP BY id_sensor, date_trunc('hour', timestamp_medicion);

-- Agregado diario por sensor.
INSERT INTO oro.agregado_diario (id_sensor, dia, promedio, minimo, maximo, desvio, cantidad_lecturas)
SELECT id_sensor, timestamp_medicion::date,
       avg(valor), min(valor), max(valor), coalesce(stddev_pop(valor), 0), count(*)
FROM plata.medicion
GROUP BY id_sensor, timestamp_medicion::date;

-- Features de motores: una fila por (dispositivo, día) a modo
-- ilustrativo. Agregación condicional sobre los tres sensores
-- del motor (vibración, temperatura, corriente) más el conteo
-- de eventos del día. fallo_en_horizonte queda NULL en las
-- ventanas recientes (aún no maduró el horizonte de 72 h).
WITH med AS (
    SELECT d.id_dispositivo,
           m.timestamp_medicion::date AS dia,
           avg(m.valor) FILTER (WHERE tv.nombre = 'vibracion')            AS vib_media,
           max(m.valor) FILTER (WHERE tv.nombre = 'vibracion')            AS vib_max,
           coalesce(stddev_pop(m.valor) FILTER (WHERE tv.nombre = 'vibracion'), 0) AS vib_desvio,
           avg(m.valor) FILTER (WHERE tv.nombre = 'temperatura')          AS temp_media,
           max(m.valor) FILTER (WHERE tv.nombre = 'temperatura')          AS temp_max,
           avg(m.valor) FILTER (WHERE tv.nombre = 'corriente')            AS corr_media
    FROM plata.dispositivo d
    JOIN plata.sensor s        ON s.id_dispositivo = d.id_dispositivo
    JOIN plata.tipo_variable tv ON tv.id_tipo_variable = s.id_tipo_variable
    JOIN plata.medicion m      ON m.id_sensor = s.id_sensor
    WHERE d.id_tipo_dispositivo = 1
    GROUP BY d.id_dispositivo, m.timestamp_medicion::date
),
ev AS (
    SELECT se.id_dispositivo, e.timestamp_medicion::date AS dia, count(*) AS cant
    FROM plata.evento e
    JOIN plata.sensor se ON se.id_sensor = e.id_sensor
    GROUP BY se.id_dispositivo, e.timestamp_medicion::date
)
INSERT INTO oro.feature_motor_ventana
    (id_dispositivo, ventana_hasta, ventana_desde, vib_media, vib_max, vib_desvio,
     vib_tendencia, temp_media, temp_max, corr_media, cant_eventos, horas_operacion,
     fallo_en_horizonte, timestamp_calculo)
SELECT med.id_dispositivo,
       (med.dia + 1)::timestamptz,
       med.dia::timestamptz,
       med.vib_media, med.vib_max, med.vib_desvio,
       0,
       med.temp_media, med.temp_max, med.corr_media,
       coalesce(ev.cant, 0),
       24.0,
       CASE WHEN med.dia < DATE '2026-08-18' THEN false ELSE NULL END,
       now()
FROM med
LEFT JOIN ev ON ev.id_dispositivo = med.id_dispositivo AND ev.dia = med.dia;

-- La ventana previa a la falla del motor 1 se marca como
-- fallo_en_horizonte = true (hubo intervención correctiva dentro
-- del horizonte de 72 h).
UPDATE oro.feature_motor_ventana
   SET fallo_en_horizonte = true
 WHERE id_dispositivo = 1 AND ventana_hasta = DATE '2026-08-18';

-- feature_bomba_ventana, feature_cinta_ventana y
-- feature_tablero_ventana se calcularían igual, con las
-- variables de cada tipo. Se omiten por brevedad.
