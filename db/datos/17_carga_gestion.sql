-- =====================================================
-- 17 - Carga de gestión (usuarios, alertas por umbral, órdenes, intervenciones)
-- =====================================================
-- Las alertas predictivas ya las creó el trigger (script 16).
-- Las alertas por umbral las genera la aplicación agrupando
-- eventos; acá se cargan a mano para el ejemplo. Las órdenes e
-- intervenciones dependen de esas alertas.

INSERT INTO plata.usuario (nombre, email, rol_negocio, id_ubicacion) VALUES
    ('Marcela Ferreyra', 'mferreyra@planta.example', 'operario',         7),
    ('Diego Ocampo',     'docampo@planta.example',   'operario',         10),
    ('Sergio Villalba',  'svillalba@planta.example', 'tecnico',          1),
    ('Laura Benítez',    'lbenitez@planta.example',  'tecnico',          2),
    ('Andrés Quiroga',   'aquiroga@planta.example',  'supervisor',       1),
    ('Paula Ledesma',    'pledesma@planta.example',  'supervisor',       2),
    ('Nicolás Arrieta',  'narrieta@planta.example',  'cientifico_datos', NULL),
    ('Verónica Sosa',    'vsosa@planta.example',     'administrador',    NULL);

-- Alerta por umbral del motor 1 (agrupa los eventos de la rampa).
INSERT INTO plata.alerta (id_dispositivo, id_evento, origen, severidad, estado, timestamp_apertura, timestamp_cierre)
SELECT 1, e.id_evento, 'umbral', 'alta', 'cerrada', e.timestamp_deteccion, e.timestamp_deteccion + interval '1 day'
FROM plata.evento e
WHERE e.tipo_evento = 'umbral superado'
ORDER BY e.id_evento LIMIT 1;

-- Alerta de instrumentación (apunta al sensor 3, no al equipo).
INSERT INTO plata.alerta (id_dispositivo, id_sensor, id_evento, origen, severidad, estado, timestamp_apertura)
SELECT 1, 3, e.id_evento, 'umbral', 'media', 'abierta', e.timestamp_deteccion
FROM plata.evento e
WHERE e.tipo_evento = 'valor fuera de rango' AND e.id_sensor = 3
ORDER BY e.id_evento LIMIT 1;

-- Órdenes de trabajo derivadas de esas alertas.
INSERT INTO plata.orden_trabajo (id_alerta, tipo, estado, fecha_apertura, fecha_cierre)
SELECT id_alerta, 'correctiva', 'cerrada', '2026-08-19', '2026-08-20'
FROM plata.alerta WHERE origen = 'umbral' AND id_sensor IS NULL ORDER BY id_alerta LIMIT 1;

INSERT INTO plata.orden_trabajo (id_alerta, tipo, estado, fecha_apertura)
SELECT id_alerta, 'instrumentacion', 'en curso', '2026-08-19'
FROM plata.alerta WHERE id_sensor = 3 ORDER BY id_alerta LIMIT 1;

-- Intervenciones (texto libre; el embedding se calcula en la Actividad 9).
INSERT INTO plata.intervencion (id_orden_trabajo, id_usuario, fecha, observaciones)
SELECT ot.id_orden_trabajo, 3, '2026-08-20',
       'Se detecta desalineación en el acople del lado motriz. Se realinea y se ajusta la base. La vibración vuelve a valores normales.'
FROM plata.orden_trabajo ot WHERE ot.tipo = 'correctiva' ORDER BY ot.id_orden_trabajo LIMIT 1;

INSERT INTO plata.intervencion (id_orden_trabajo, id_usuario, fecha, observaciones)
SELECT ot.id_orden_trabajo, 3, '2026-08-19',
       'Cable de señal del sensor de corriente flojo en la bornera. Se reajusta y se verifica continuidad.'
FROM plata.orden_trabajo ot WHERE ot.tipo = 'instrumentacion' ORDER BY ot.id_orden_trabajo LIMIT 1;
