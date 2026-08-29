-- Consulta 6 — Comparación de rendimiento: plata vs oro.
-- El mismo resultado (promedio diario de vibración del sensor 1) se
-- obtiene de dos formas: agregando las mediciones crudas de plata, o
-- leyendo el agregado ya calculado en oro. El EXPLAIN muestra el costo
-- distinto: oro evita recorrer y agrupar la serie completa.

-- A) Desde plata: agrega sobre las mediciones.
EXPLAIN (ANALYZE, BUFFERS)
SELECT m.timestamp_medicion::date AS dia, avg(m.valor)
FROM plata.medicion m
WHERE m.id_sensor = 1
GROUP BY dia;

-- B) Desde oro: lee el agregado precalculado.
EXPLAIN (ANALYZE, BUFFERS)
SELECT dia, promedio
FROM oro.agregado_diario
WHERE id_sensor = 1;
