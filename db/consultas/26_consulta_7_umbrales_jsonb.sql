-- Consulta 7 — Umbrales vigentes por dispositivo (lectura de JSONB).
-- Los umbrales viven dentro del campo `parametros` (JSONB), una clave
-- por variable. jsonb_each expande esas claves a filas (variable, valor),
-- y con ->> se leen los umbrales de cada sub-objeto. Sólo la config vigente.
SELECT d.nombre AS dispositivo,
       var.key   AS variable,
       (var.value ->> 'umbral_alerta')::numeric  AS umbral_alerta,
       (var.value ->> 'umbral_critico')::numeric AS umbral_critico,
       (var.value ->> 'umbral_min')::numeric     AS umbral_min
FROM plata.configuracion_dispositivo c
JOIN plata.dispositivo d ON d.id_dispositivo = c.id_dispositivo
CROSS JOIN LATERAL jsonb_each(c.parametros) AS var(key, value)
WHERE c.valido_hasta IS NULL
ORDER BY d.nombre, variable;
