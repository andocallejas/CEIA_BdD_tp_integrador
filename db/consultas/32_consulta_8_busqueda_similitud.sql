-- Consulta 8 — Búsqueda de intervenciones similares.
-- Dada una intervención, encuentra las más parecidas por su observación
-- (vecinos más cercanos según distancia coseno, operador <=>). Con los
-- embeddings de ejemplo el orden no es semántico; con embeddings reales
-- devolvería intervenciones con síntomas parecidos.
SELECT i2.id_intervencion,
       i2.observaciones,
       (ref.embedding <=> i2.embedding) AS distancia
FROM plata.intervencion ref
JOIN plata.intervencion i2 ON i2.id_intervencion <> ref.id_intervencion
WHERE ref.id_intervencion = 1
ORDER BY ref.embedding <=> i2.embedding
LIMIT 5;
