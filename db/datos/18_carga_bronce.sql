-- =====================================================
-- 18 - Carga de ejemplo de la capa bronce
-- =====================================================
-- Muestra el dato crudo tal como llega. La fila con
-- error_validacion NO se promueve a plata; procesado = false
-- indica que todavía no se procesó.

INSERT INTO bronce.medicion_cruda (payload, timestamp_recepcion, procesado, error_validacion) VALUES
    ('{"sensor":"MOT-N-01-VIB","ts":"2026-08-19T09:58:20Z","v":9.40}', '2026-08-19 09:58:22', true,  NULL),
    ('{"sensor":"MOT-N-01-TMP","ts":"2026-08-19T09:58:20Z","v":74.10}','2026-08-19 09:58:22', true,  NULL),
    ('{"sensor":"MOT-N-01-VIB","ts":"2026-08-19T09:58:30Z","v":null}', '2026-08-19 09:58:32', true,  'Valor nulo en campo v'),
    ('{"sensor":"BOM-N-01-PRE","ts":"2026-08-19T09:58:30Z","v":4.85}', '2026-08-19 09:58:33', false, NULL);

INSERT INTO bronce.configuracion_cruda (payload, timestamp_recepcion, procesado) VALUES
    ('{"dispositivo":"MOT-N-01","vibracion":{"umbral_alerta":7.5,"umbral_critico":12.0},"temperatura":{"umbral_alerta":80.0}}', '2026-06-15 10:30:00', true);
