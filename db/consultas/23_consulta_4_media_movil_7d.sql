-- Consulta 4 — Media móvil de 7 días (función de ventana).
-- Sobre el promedio diario de un sensor, promedia cada día con los 6
-- anteriores (ventana deslizante de 7 filas). Suaviza la tendencia.
SELECT id_sensor,
       dia,
       promedio,
       round(avg(promedio) OVER (
           PARTITION BY id_sensor
           ORDER BY dia
           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 3) AS media_movil_7d
FROM oro.agregado_diario
WHERE id_sensor = 1
ORDER BY dia;
