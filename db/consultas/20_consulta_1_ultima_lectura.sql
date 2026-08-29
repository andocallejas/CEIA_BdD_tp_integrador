-- Consulta 1 — Última lectura de cada sensor de un dispositivo.
-- Usa DISTINCT ON: por cada id_sensor se queda con la primera fila
-- según el ORDER BY, es decir la de timestamp más reciente.
SELECT DISTINCT ON (s.id_sensor)
       s.id_sensor,
       s.nombre AS sensor,
       m.timestamp_medicion,
       m.valor
FROM plata.sensor s
JOIN plata.medicion m ON m.id_sensor = s.id_sensor
WHERE s.id_dispositivo = 1
ORDER BY s.id_sensor, m.timestamp_medicion DESC;
