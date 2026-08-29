-- =====================================================
-- 14 - Generación de mediciones
-- =====================================================
-- Dos tramos:
--  A) Backfill histórico masivo (jun–ago) con el trigger
--     DESACTIVADO: carga de volumen para la consulta 6, sin
--     generar eventos (patrón habitual de backfill).
--  B) Ventana reciente con el trigger ACTIVO: dispara los
--     eventos. El motor 1 recibe una rampa de vibración que
--     cruza su umbral, más una lectura de mala calidad.
-- Sólo sensores activos de dispositivos operativos.

-- A) Backfill histórico (trigger off)
ALTER TABLE plata.medicion DISABLE TRIGGER tg_detectar_evento;

INSERT INTO plata.medicion (id_sensor, timestamp_medicion, valor, calidad)
SELECT s.id_sensor, t.ts, b.val + (random() - 0.5) * b.ruido, 'válida'
FROM plata.sensor s
JOIN plata.dispositivo d ON d.id_dispositivo = s.id_dispositivo AND d.estado = 'operativo'
JOIN (VALUES
        (1, 3.0, 0.6), (2, 70.0, 4.0), (3, 12.0, 2.0), (4, 4.8, 0.4),
        (5, 15.0, 2.0), (6, 1.4, 0.3), (7, 180.0, 30.0), (8, 380.0, 10.0)
     ) AS b(tv, val, ruido) ON b.tv = s.id_tipo_variable
CROSS JOIN generate_series(
        TIMESTAMP '2026-06-01' AT TIME ZONE 'UTC',
        TIMESTAMP '2026-08-17 23:55' AT TIME ZONE 'UTC',
        interval '5 minutes') AS t(ts)
WHERE s.estado = 'activo';

ALTER TABLE plata.medicion ENABLE TRIGGER tg_detectar_evento;

-- B) Ventana reciente (trigger on). Rampa de vibración en el motor 1.
INSERT INTO plata.medicion (id_sensor, timestamp_medicion, valor, calidad)
SELECT
    s.id_sensor, t.ts,
    CASE
        WHEN s.id_sensor = 1 AND t.ts >= '2026-08-18' THEN
            3.0 + 6.5 * (EXTRACT(EPOCH FROM (t.ts - TIMESTAMP '2026-08-18'))
                         / EXTRACT(EPOCH FROM (TIMESTAMP '2026-08-20' - TIMESTAMP '2026-08-18')))
            + (random() - 0.5) * 0.4
        ELSE b.val + (random() - 0.5) * b.ruido
    END,
    'válida'
FROM plata.sensor s
JOIN plata.dispositivo d ON d.id_dispositivo = s.id_dispositivo AND d.estado = 'operativo'
JOIN (VALUES
        (1, 3.0, 0.6), (2, 70.0, 4.0), (3, 12.0, 2.0), (4, 4.8, 0.4),
        (5, 15.0, 2.0), (6, 1.4, 0.3), (7, 180.0, 30.0), (8, 380.0, 10.0)
     ) AS b(tv, val, ruido) ON b.tv = s.id_tipo_variable
CROSS JOIN generate_series(
        TIMESTAMP '2026-08-18' AT TIME ZONE 'UTC',
        TIMESTAMP '2026-08-20' AT TIME ZONE 'UTC',
        interval '15 minutes') AS t(ts)
WHERE s.estado = 'activo';

-- Lectura de mala calidad: dispara un evento de dato en el sensor 3.
INSERT INTO plata.medicion (id_sensor, timestamp_medicion, valor, calidad)
VALUES (3, '2026-08-19 12:07:30', 0.0, 'sospechosa');

-- Hueco de conectividad: el sensor 5 deja de reportar unas horas.
DELETE FROM plata.medicion
WHERE id_sensor = 5
  AND timestamp_medicion >= '2026-08-19 02:00' AND timestamp_medicion < '2026-08-19 05:00';

-- El evento de ausencia lo registra el job de monitoreo (no un trigger de INSERT).
INSERT INTO plata.evento (id_sensor, timestamp_medicion, tipo_evento, descripcion, valor_medido, umbral_vigente, timestamp_deteccion)
VALUES (5, '2026-08-19 02:00', 'ausencia de reporte', 'Sin lecturas durante más de 15 minutos', NULL, NULL, '2026-08-19 05:00');
