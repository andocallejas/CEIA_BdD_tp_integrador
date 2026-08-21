-- =====================================================
-- 12 - Carga de datos: catalogos
-- =====================================================
-- Pocas filas, se cargan a mano para que sean exactas.
-- Los ids resultan secuenciales (columnas serial).
-- =====================================================

INSERT INTO plata.unidad (simbolo, nombre) VALUES
    ('mm/s', 'Milímetros por segundo'),
    ('°C',   'Grados Celsius'),
    ('A',    'Amperios'),
    ('bar',  'Bar'),
    ('m³/h', 'Metros cúbicos por hora'),
    ('m/s',  'Metros por segundo'),
    ('kWh',  'Kilovatio-hora'),
    ('V',    'Voltios');

INSERT INTO plata.tipo_variable (nombre, id_unidad) VALUES
    ('vibracion',   1),
    ('temperatura', 2),
    ('corriente',   3),
    ('presion',     4),
    ('caudal',      5),
    ('velocidad',   6),
    ('consumo',     7),
    ('tension',     8);

INSERT INTO plata.tipo_dispositivo (nombre, descripcion) VALUES
    ('Motor eléctrico',      'Motor de accionamiento de equipos rotativos'),
    ('Bomba centrífuga',     'Bomba de impulsión de fluidos de proceso'),
    ('Cinta transportadora', 'Transporte continuo de material a granel'),
    ('Tablero eléctrico',    'Tablero de distribución y protección'),
    ('Compresor de aire',    'Generación de aire comprimido de planta'),
    ('Ventilador industrial','Extracción y ventilación forzada');
