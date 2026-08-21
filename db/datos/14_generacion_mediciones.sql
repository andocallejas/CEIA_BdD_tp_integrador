-- =====================================================
-- 14 - Generación de mediciones
-- =====================================================
-- 10 días (2026-08-10 a 2026-08-20), una lectura cada 15 min,
-- sólo para sensores activos de dispositivos operativos (así
-- los equipos en mantenimiento o de baja no generan datos).
-- Valor = base por variable + ruido. El motor 1 recibe además
-- una rampa creciente de vibración sobre el final, que cruza su
-- umbral (7.5) y hace que el trigger genere eventos.
-- Al insertar en plata.medicion, el trigger tg_detectar_evento
-- crea los eventos solo.

INSERT INTO plata.medicion (id_sensor, timestamp_medicion, valor, calidad)
SELECT
    s.id_sensor,
    t.ts,
    CASE
        WHEN s.id_sensor = 1 AND t.ts >= '2026-08-18' THEN
            3.0 + 6.5 * (EXTRACT(EPOCH FROM (t.ts - TIMESTAMP '2026-08-18'))
                         / EXTRACT(EPOCH FROM (TIMESTAMP '2026-08-20' - TIMESTAMP '2026-08-18')))
            + (random() - 0.5) * 0.4
        ELSE b.val + (random() - 0.5) * b.ruido
    END,
    'válida'
FROM plata.sensor s
JOIN plata.dispositivo d
     ON d.id_dispositivo = s.id_dispositivo AND d.estado = 'operativo'
JOIN (VALUES
        (1, 3.0, 0.6), (2, 70.0, 4.0), (3, 12.0, 2.0), (4, 4.8, 0.4),
        (5, 15.0, 2.0), (6, 1.4, 0.3), (7, 180.0, 30.0), (8, 380.0, 10.0)
     ) AS b(tv, val, ruido) ON b.tv = s.id_tipo_variable
CROSS JOIN generate_series(
        TIMESTAMP '2026-08-10' AT TIME ZONE 'UTC',
        TIMESTAMP '2026-08-20' AT TIME ZONE 'UTC',
        interval '15 minutes') AS t(ts)
WHERE s.estado = 'activo';

-- Una lectura de mala calidad: dispara un evento de dato
-- apuntado al sensor 3 (corriente del motor 1).
INSERT INTO plata.medicion (id_sensor, timestamp_medicion, valor, calidad)
VALUES (3, '2026-08-19 12:07:30', 0.0, 'sospechosa');
