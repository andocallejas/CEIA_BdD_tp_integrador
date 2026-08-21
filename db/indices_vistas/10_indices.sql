-- =====================================================
-- 10 - Índices
-- =====================================================

-- BRIN sobre el timestamp de medición: muy compacto para datos
-- ordenados por tiempo. Se propaga a todas las particiones.
CREATE INDEX idx_medicion_ts_brin
    ON plata.medicion USING brin (timestamp_medicion);

-- Alertas abiertas por dispositivo (consulta 2 de la Actividad 8).
CREATE INDEX idx_alerta_disp_estado
    ON plata.alerta (id_dispositivo, estado);

-- Eventos por sensor y momento de la medición de origen.
CREATE INDEX idx_evento_sensor_ts
    ON plata.evento (id_sensor, timestamp_medicion);

-- Filas maduras (etiquetadas) para el entrenamiento del modelo.
CREATE INDEX idx_feature_motor_entrenables
    ON oro.feature_motor_ventana (fallo_en_horizonte)
    WHERE fallo_en_horizonte IS NOT NULL;

-- El índice vectorial (HNSW) sobre intervencion.embedding se crea
-- en la Actividad 9, junto con el cálculo de los embeddings.
