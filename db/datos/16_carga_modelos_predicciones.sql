-- =====================================================
-- 16 - Trazabilidad del modelo y predicciones
-- =====================================================
-- Bajo volumen: se carga a mano. Al insertar predicciones que
-- superan el umbral, el trigger tg_generar_alerta_predictiva
-- crea las alertas predictivas solo.

INSERT INTO oro.modelo (nombre, version, id_tipo_dispositivo, horizonte_h, estado) VALUES
    ('pred_falla_motor',   'v1', 1, 72, 'retirado'),
    ('pred_falla_motor',   'v2', 1, 72, 'activo'),
    ('pred_falla_bomba',   'v1', 2, 72, 'activo'),
    ('pred_falla_cinta',   'v1', 3, 72, 'activo'),
    ('pred_falla_tablero', 'v1', 4, 72, 'activo');

INSERT INTO oro.corrida_entrenamiento
    (id_modelo, fecha, rango_desde, rango_hasta, criterio_seleccion, hiperparametros, uri_artefacto) VALUES
    (1, '2026-03-01 02:00', '2025-03-01', '2026-03-01',
     '{"tipo_dispositivo":1,"calidad":"valida","excluir_estado":["dado de baja"]}',
     '{"n_estimators":200,"max_depth":8}',  's3://modelos/motor/v1/model.pkl'),
    (2, '2026-07-01 02:00', '2025-07-01', '2026-07-01',
     '{"tipo_dispositivo":1,"calidad":"valida","excluir_estado":["dado de baja"]}',
     '{"n_estimators":300,"max_depth":10}', 's3://modelos/motor/v2/model.pkl'),
    (3, '2026-07-01 02:30', '2025-07-01', '2026-07-01',
     '{"tipo_dispositivo":2,"calidad":"valida"}',
     '{"n_estimators":300,"max_depth":10}', 's3://modelos/bomba/v1/model.pkl');

INSERT INTO oro.metrica (id_corrida, nombre, particion, valor) VALUES
    (1, 'auc', 'validacion', 0.874000),
    (1, 'f1',  'validacion', 0.712000),
    (1, 'auc', 'test',       0.851000),
    (2, 'auc', 'entrenamiento', 0.945000),
    (2, 'auc', 'validacion', 0.912000),
    (2, 'f1',  'validacion', 0.783000),
    (2, 'auc', 'test',       0.897000),
    (3, 'auc', 'validacion', 0.868000);

-- Predicciones. Las que superan 0.70 generan alerta (trigger).
INSERT INTO oro.prediccion
    (id_dispositivo, id_modelo, timestamp_prediccion, ventana_desde, ventana_hasta, horizonte_h, score, umbral_aplicado) VALUES
    (1,  2, '2026-08-18 10:05', '2026-08-17 10:00', '2026-08-18 10:00', 72, 0.8300, 0.7000), -- alerta alta
    (14, 3, '2026-08-18 10:05', '2026-08-17 10:00', '2026-08-18 10:00', 72, 0.7400, 0.7000), -- alerta media
    (2,  2, '2026-08-18 10:05', '2026-08-17 10:00', '2026-08-18 10:00', 72, 0.1200, 0.7000), -- no genera
    (1,  1, '2026-06-20 10:05', '2026-06-19 10:00', '2026-06-20 10:00', 72, 0.3400, 0.7000); -- modelo retirado, no genera
