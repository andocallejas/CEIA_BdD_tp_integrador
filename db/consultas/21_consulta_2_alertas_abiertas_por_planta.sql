-- Consulta 2 — Alertas abiertas por planta, con severidad y antigüedad.
-- La planta de cada dispositivo se resuelve subiendo la jerarquía de
-- ubicaciones (línea -> área -> planta) con un CTE recursivo. Es la
-- consulta que mostrará el aislamiento por RLS una vez aplicado (Act. 11).
WITH RECURSIVE anc AS (
    SELECT id_ubicacion AS origen, id_ubicacion, nombre, nivel, id_ubicacion_padre
    FROM plata.ubicacion
    UNION ALL
    SELECT a.origen, u.id_ubicacion, u.nombre, u.nivel, u.id_ubicacion_padre
    FROM anc a
    JOIN plata.ubicacion u ON u.id_ubicacion = a.id_ubicacion_padre
),
planta AS (
    SELECT origen AS id_ubicacion, nombre AS planta
    FROM anc WHERE nivel = 'planta'
)
SELECT p.planta,
       d.nombre AS dispositivo,
       al.severidad,
       al.estado,
       al.timestamp_apertura,
       date_trunc('minute', now() - al.timestamp_apertura) AS antiguedad
FROM plata.alerta al
JOIN plata.dispositivo d ON d.id_dispositivo = al.id_dispositivo
JOIN planta p ON p.id_ubicacion = d.id_ubicacion
WHERE al.estado <> 'cerrada'
ORDER BY p.planta,
         CASE al.severidad WHEN 'alta' THEN 1 WHEN 'media' THEN 2 ELSE 3 END;
