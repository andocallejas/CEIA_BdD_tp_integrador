-- Embeddings de ejemplo (opción conceptual): vectores aleatorios de 384
-- dimensiones. En producción se calculan con un modelo (ej. all-MiniLM-L6-v2)
-- a partir de intervencion.observaciones. Acá solo dejan el esquema y la
-- búsqueda operativos.
UPDATE plata.intervencion i
SET embedding = t.vec
FROM (
    SELECT id_intervencion, array_agg(random())::vector AS vec
    FROM plata.intervencion CROSS JOIN generate_series(1, 384)
    GROUP BY id_intervencion
) t
WHERE t.id_intervencion = i.id_intervencion;
