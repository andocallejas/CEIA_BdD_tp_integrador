-- Consulta 3 — Promedio y máximo de vibración por motor y día, en un rango.
-- Agregación clásica: agrupa las mediciones de vibración por dispositivo y día.
SELECT d.nombre AS dispositivo,
       m.timestamp_medicion::date AS dia,
       round(avg(m.valor), 2) AS vib_promedio,
       max(m.valor) AS vib_maxima
FROM plata.medicion m
JOIN plata.sensor s ON s.id_sensor = m.id_sensor
JOIN plata.tipo_variable tv ON tv.id_tipo_variable = s.id_tipo_variable
JOIN plata.dispositivo d ON d.id_dispositivo = s.id_dispositivo
WHERE tv.nombre = 'vibracion'
  AND m.timestamp_medicion >= '2026-08-15'
  AND m.timestamp_medicion <  '2026-08-21'
GROUP BY d.nombre, dia
ORDER BY d.nombre, dia;
