-- Consulta 5 — Ranking de dispositivos por intervenciones correctivas.
-- Usa una subconsulta correlacionada que, por cada dispositivo, cuenta
-- sus intervenciones sobre órdenes de tipo correctiva (siguiendo la
-- cadena intervencion -> orden_trabajo -> alerta -> dispositivo).
SELECT d.id_dispositivo,
       d.nombre,
       (SELECT count(*)
          FROM plata.intervencion i
          JOIN plata.orden_trabajo ot ON ot.id_orden_trabajo = i.id_orden_trabajo
          JOIN plata.alerta a        ON a.id_alerta = ot.id_alerta
         WHERE ot.tipo = 'correctiva'
           AND a.id_dispositivo = d.id_dispositivo) AS intervenciones_correctivas
FROM plata.dispositivo d
ORDER BY intervenciones_correctivas DESC, d.id_dispositivo
LIMIT 10;
