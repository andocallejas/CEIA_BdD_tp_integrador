-- =====================================================
-- 13 - Carga de datos: activos
-- =====================================================
-- Ubicaciones, dispositivos, sensores y configuracion.
-- Ids autonumerados (serial): el ORDEN de los INSERT fija
-- los ids que el resto de los datos (mediciones, eventos)
-- da por sabidos. No cambiar el orden.
-- Reparto: dispositivos 1-10 en Planta Norte, 11-20 en Sur;
-- sensores 1-26 en Norte, 27-52 en Sur.
-- =====================================================

-- --- Ubicaciones: planta > area > linea (autoreferencial) ---
-- Primero las plantas (padre NULL), luego areas (padre=planta),
-- luego lineas (padre=area). El padre debe existir antes.
INSERT INTO plata.ubicacion (nombre, nivel, id_ubicacion_padre) VALUES
    ('Planta Norte',          'planta', NULL),  -- 1
    ('Planta Sur',            'planta', NULL),  -- 2
    ('Área Producción Norte', 'area',   1),     -- 3
    ('Área Servicios Norte',  'area',   1),     -- 4
    ('Área Producción Sur',   'area',   2),     -- 5
    ('Área Servicios Sur',    'area',   2),     -- 6
    ('Línea 1 Norte',         'linea',  3),     -- 7
    ('Línea 2 Norte',         'linea',  3),     -- 8
    ('Línea Servicios Norte', 'linea',  4),     -- 9
    ('Línea 1 Sur',           'linea',  5),     -- 10
    ('Línea 2 Sur',           'linea',  5),     -- 11
    ('Línea Servicios Sur',   'linea',  6);     -- 12

-- --- Dispositivos (id_tipo_dispositivo: 1=motor, 2=bomba, 3=cinta, 4=tablero) ---
INSERT INTO plata.dispositivo (nombre, id_tipo_dispositivo, id_ubicacion, estado, fecha_alta) VALUES
    ('MOT-N-01', 1, 7,  'operativo',        '2025-01-15'),  -- 1
    ('MOT-N-02', 1, 7,  'operativo',        '2025-01-15'),  -- 2
    ('MOT-N-03', 1, 8,  'operativo',        '2025-02-20'),  -- 3
    ('BOM-N-01', 2, 7,  'operativo',        '2025-01-15'),  -- 4
    ('BOM-N-02', 2, 8,  'operativo',        '2025-01-15'),  -- 5
    ('BOM-N-03', 2, 9,  'en mantenimiento', '2025-03-10'),  -- 6
    ('CIN-N-01', 3, 7,  'operativo',        '2025-01-15'),  -- 7
    ('CIN-N-02', 3, 8,  'operativo',        '2025-01-15'),  -- 8
    ('TAB-N-01', 4, 9,  'operativo',        '2025-01-15'),  -- 9
    ('TAB-N-02', 4, 9,  'operativo',        '2025-01-15'),  -- 10
    ('MOT-S-01', 1, 10, 'operativo',        '2025-01-15'),  -- 11
    ('MOT-S-02', 1, 10, 'operativo',        '2025-01-15'),  -- 12
    ('MOT-S-03', 1, 11, 'operativo',        '2025-04-05'),  -- 13
    ('BOM-S-01', 2, 10, 'operativo',        '2025-01-15'),  -- 14
    ('BOM-S-02', 2, 11, 'operativo',        '2025-01-15'),  -- 15
    ('BOM-S-03', 2, 12, 'operativo',        '2025-01-15'),  -- 16
    ('CIN-S-01', 3, 10, 'operativo',        '2025-01-15'),  -- 17
    ('CIN-S-02', 3, 11, 'operativo',        '2025-01-15'),  -- 18
    ('TAB-S-01', 4, 12, 'operativo',        '2025-01-15'),  -- 19
    ('TAB-S-02', 4, 12, 'dado de baja',     '2025-01-15');  -- 20

-- --- Sensores (id_tipo_variable: 1=vib,2=temp,3=corr,4=pres,5=caud,6=vel,7=cons,8=tens) ---
-- Patron por tipo: motor=VIB,TMP,COR | bomba=PRE,CAU,TMP | cinta=VEL,COR | tablero=CON,TEN
-- Planta Norte (sensores 1-26)
INSERT INTO plata.sensor (id_dispositivo, id_tipo_variable, nombre, estado) VALUES
    (1, 1, 'MOT-N-01-VIB', 'activo'),             -- 1
    (1, 2, 'MOT-N-01-TMP', 'activo'),             -- 2
    (1, 3, 'MOT-N-01-COR', 'activo'),             -- 3
    (2, 1, 'MOT-N-02-VIB', 'activo'),             -- 4
    (2, 2, 'MOT-N-02-TMP', 'activo'),             -- 5
    (2, 3, 'MOT-N-02-COR', 'activo'),             -- 6
    (3, 1, 'MOT-N-03-VIB', 'activo'),             -- 7
    (3, 2, 'MOT-N-03-TMP', 'activo'),             -- 8
    (3, 3, 'MOT-N-03-COR', 'fuera de servicio'),  -- 9
    (4, 4, 'BOM-N-01-PRE', 'activo'),             -- 10
    (4, 5, 'BOM-N-01-CAU', 'activo'),             -- 11
    (4, 2, 'BOM-N-01-TMP', 'activo'),             -- 12
    (5, 4, 'BOM-N-02-PRE', 'activo'),             -- 13
    (5, 5, 'BOM-N-02-CAU', 'activo'),             -- 14
    (5, 2, 'BOM-N-02-TMP', 'activo'),             -- 15
    (6, 4, 'BOM-N-03-PRE', 'activo'),             -- 16
    (6, 5, 'BOM-N-03-CAU', 'activo'),             -- 17
    (6, 2, 'BOM-N-03-TMP', 'activo'),             -- 18
    (7, 6, 'CIN-N-01-VEL', 'activo'),             -- 19
    (7, 3, 'CIN-N-01-COR', 'activo'),             -- 20
    (8, 6, 'CIN-N-02-VEL', 'activo'),             -- 21
    (8, 3, 'CIN-N-02-COR', 'activo'),             -- 22
    (9, 7, 'TAB-N-01-CON', 'activo'),             -- 23
    (9, 8, 'TAB-N-01-TEN', 'activo'),             -- 24
    (10, 7, 'TAB-N-02-CON', 'activo'),            -- 25
    (10, 8, 'TAB-N-02-TEN', 'activo');            -- 26
-- Planta Sur (sensores 27-52): mismo patron sobre dispositivos 11-20
INSERT INTO plata.sensor (id_dispositivo, id_tipo_variable, nombre, estado) VALUES
    (11, 1, 'MOT-S-01-VIB', 'activo'),            -- 27
    (11, 2, 'MOT-S-01-TMP', 'activo'),            -- 28
    (11, 3, 'MOT-S-01-COR', 'activo'),            -- 29
    (12, 1, 'MOT-S-02-VIB', 'activo'),            -- 30
    (12, 2, 'MOT-S-02-TMP', 'activo'),            -- 31
    (12, 3, 'MOT-S-02-COR', 'activo'),            -- 32
    (13, 1, 'MOT-S-03-VIB', 'activo'),            -- 33
    (13, 2, 'MOT-S-03-TMP', 'activo'),            -- 34
    (13, 3, 'MOT-S-03-COR', 'activo'),            -- 35
    (14, 4, 'BOM-S-01-PRE', 'activo'),            -- 36
    (14, 5, 'BOM-S-01-CAU', 'activo'),            -- 37
    (14, 2, 'BOM-S-01-TMP', 'activo'),            -- 38
    (15, 4, 'BOM-S-02-PRE', 'activo'),            -- 39
    (15, 5, 'BOM-S-02-CAU', 'activo'),            -- 40
    (15, 2, 'BOM-S-02-TMP', 'activo'),            -- 41
    (16, 4, 'BOM-S-03-PRE', 'activo'),            -- 42
    (16, 5, 'BOM-S-03-CAU', 'activo'),            -- 43
    (16, 2, 'BOM-S-03-TMP', 'activo'),            -- 44
    (17, 6, 'CIN-S-01-VEL', 'activo'),            -- 45
    (17, 3, 'CIN-S-01-COR', 'activo'),            -- 46
    (18, 6, 'CIN-S-02-VEL', 'activo'),            -- 47
    (18, 3, 'CIN-S-02-COR', 'activo'),            -- 48
    (19, 7, 'TAB-S-01-CON', 'activo'),            -- 49
    (19, 8, 'TAB-S-01-TEN', 'activo'),            -- 50
    (20, 7, 'TAB-S-02-CON', 'activo'),            -- 51
    (20, 8, 'TAB-S-02-TEN', 'activo');            -- 52

-- --- Configuracion de dispositivo (umbrales en JSONB) ---
-- El dispositivo 1 tiene dos versiones: la historica (cerrada
-- con valido_hasta) y la vigente (valido_hasta NULL). Permite
-- interpretar una alerta antigua con el umbral que regia entonces.
INSERT INTO plata.configuracion_dispositivo (id_dispositivo, parametros, valido_desde, valido_hasta) VALUES
    (1, '{"vibracion":{"umbral_alerta":7.5,"umbral_critico":12.0},"temperatura":{"umbral_alerta":85.0},"corriente":{"umbral_alerta":18.0}}',
        '2025-01-15 00:00:00', '2026-06-15 10:30:00'),
    (1, '{"vibracion":{"umbral_alerta":7.5,"umbral_critico":12.0},"temperatura":{"umbral_alerta":80.0},"corriente":{"umbral_alerta":18.0}}',
        '2026-06-15 10:30:00', NULL),
    (4, '{"presion":{"umbral_alerta":6.0},"caudal":{"umbral_min":12.0},"temperatura":{"umbral_alerta":70.0}}',
        '2025-01-15 00:00:00', NULL),
    (7, '{"velocidad":{"umbral_min":0.8,"umbral_alerta":2.5},"corriente":{"umbral_alerta":15.0}}',
        '2025-01-15 00:00:00', NULL),
    (9, '{"consumo":{"umbral_alerta":250.0},"tension":{"umbral_min":370.0,"umbral_alerta":400.0}}',
        '2025-01-15 00:00:00', NULL);
