# Anexo — Datos de ejemplo y guía de implementación (Actividad 7)

Documento de trabajo interno. Contiene un juego de datos de ejemplo coherente para las 22 tablas del modelo lógico y una guía de pasos sugerida para la implementación física. Los datos son mínimos y consistentes entre sí: sirven para validar el DDL, los triggers y las consultas de la Actividad 8 antes de generar volumen real.

Convenciones usadas:

- Los identificadores son secuenciales, como corresponde a columnas `serial` / `bigserial`.
- Dispositivos 1 a 10 en Planta Norte, 11 a 20 en Planta Sur.
- Sensores 1 a 26 en Planta Norte, 27 a 52 en Planta Sur.
- Las tablas largas (`dispositivo`, `sensor`, `medicion`) muestran una porción representativa; el patrón de generación se explica al pie.

---

## 1. Capa bronce

### `bronce.medicion_cruda`

| id_medicion_cruda | payload | timestamp_recepcion | procesado | error_validacion |
|---|---|---|---|---|
| 1 | `{"sensor":"MOT-N-01-VIB","ts":"2026-08-12T09:58:20Z","v":9.40}` | 2026-08-12 09:58:22 | true | *null* |
| 2 | `{"sensor":"MOT-N-01-TMP","ts":"2026-08-12T09:58:20Z","v":74.10}` | 2026-08-12 09:58:22 | true | *null* |
| 3 | `{"sensor":"MOT-N-01-VIB","ts":"2026-08-12T09:58:30Z","v":null}` | 2026-08-12 09:58:32 | true | Valor nulo en campo v |
| 4 | `{"sensor":"BOM-N-01-PRE","ts":"2026-08-12T09:58:30Z","v":4.85}` | 2026-08-12 09:58:33 | true | *null* |
| 5 | `{"sensor":"MOT-N-01-VIB","ts":"2026-08-12T09:58:40Z","v":9.62}` | 2026-08-12 09:58:41 | false | *null* |

La fila 3 ilustra un payload rechazado por validación: se conserva en bronce con el motivo, no se promueve a plata. La fila 5 todavía no fue procesada.

### `bronce.configuracion_cruda`

| id_configuracion_cruda | payload | timestamp_recepcion | procesado |
|---|---|---|---|
| 1 | `{"dispositivo":"MOT-N-01","vibracion":{"umbral_alerta":7.5,"umbral_critico":12.0},"temperatura":{"umbral_alerta":85.0},"corriente":{"umbral_alerta":18.0}}` | 2026-02-01 08:00:00 | true |
| 2 | `{"dispositivo":"MOT-N-01","vibracion":{"umbral_alerta":7.5,"umbral_critico":12.0},"temperatura":{"umbral_alerta":80.0},"corriente":{"umbral_alerta":18.0}}` | 2026-06-15 10:30:00 | true |
| 3 | `{"dispositivo":"BOM-N-01","presion":{"umbral_alerta":6.0},"caudal":{"umbral_min":12.0},"temperatura":{"umbral_alerta":70.0}}` | 2026-02-01 08:00:00 | true |

---

## 2. Capa plata — catálogos

### `plata.unidad`

| id_unidad | simbolo | nombre |
|---|---|---|
| 1 | mm/s | Milímetros por segundo |
| 2 | °C | Grados Celsius |
| 3 | A | Amperios |
| 4 | bar | Bar |
| 5 | m³/h | Metros cúbicos por hora |
| 6 | m/s | Metros por segundo |
| 7 | kWh | Kilovatio-hora |
| 8 | V | Voltios |

### `plata.tipo_variable`

| id_tipo_variable | nombre | id_unidad |
|---|---|---|
| 1 | vibracion | 1 |
| 2 | temperatura | 2 |
| 3 | corriente | 3 |
| 4 | presion | 4 |
| 5 | caudal | 5 |
| 6 | velocidad | 6 |
| 7 | consumo | 7 |
| 8 | tension | 8 |

### `plata.tipo_dispositivo`

| id_tipo_dispositivo | nombre | descripcion |
|---|---|---|
| 1 | Motor eléctrico | Motor de accionamiento de equipos rotativos |
| 2 | Bomba centrífuga | Bomba de impulsión de fluidos de proceso |
| 3 | Cinta transportadora | Transporte continuo de material a granel |
| 4 | Tablero eléctrico | Tablero de distribución y protección |
| 5 | Compresor de aire | Generación de aire comprimido de planta |
| 6 | Ventilador industrial | Extracción y ventilación forzada |

Los tipos 5 y 6 quedan en el catálogo sin instancias cargadas, para mostrar que el modelo admite más tipos de los que se poblan (decisión 14).

---

## 3. Capa plata — activos

### `plata.ubicacion`

| id_ubicacion | nombre | nivel | id_ubicacion_padre |
|---|---|---|---|
| 1 | Planta Norte | planta | *null* |
| 2 | Planta Sur | planta | *null* |
| 3 | Área Producción Norte | area | 1 |
| 4 | Área Servicios Norte | area | 1 |
| 5 | Área Producción Sur | area | 2 |
| 6 | Área Servicios Sur | area | 2 |
| 7 | Línea 1 Norte | linea | 3 |
| 8 | Línea 2 Norte | linea | 3 |
| 9 | Línea Servicios Norte | linea | 4 |
| 10 | Línea 1 Sur | linea | 5 |
| 11 | Línea 2 Sur | linea | 5 |
| 12 | Línea Servicios Sur | linea | 6 |

### `plata.dispositivo`

| id_dispositivo | nombre | id_tipo_dispositivo | id_ubicacion | estado | fecha_alta |
|---|---|---|---|---|---|
| 1 | MOT-N-01 | 1 | 7 | operativo | 2025-01-15 |
| 2 | MOT-N-02 | 1 | 7 | operativo | 2025-01-15 |
| 3 | MOT-N-03 | 1 | 8 | operativo | 2025-02-20 |
| 4 | BOM-N-01 | 2 | 7 | operativo | 2025-01-15 |
| 5 | BOM-N-02 | 2 | 8 | operativo | 2025-01-15 |
| 6 | BOM-N-03 | 2 | 9 | en mantenimiento | 2025-03-10 |
| 7 | CIN-N-01 | 3 | 7 | operativo | 2025-01-15 |
| 8 | CIN-N-02 | 3 | 8 | operativo | 2025-01-15 |
| 9 | TAB-N-01 | 4 | 9 | operativo | 2025-01-15 |
| 10 | TAB-N-02 | 4 | 9 | operativo | 2025-01-15 |
| 11 | MOT-S-01 | 1 | 10 | operativo | 2025-01-15 |
| 12 | MOT-S-02 | 1 | 10 | operativo | 2025-01-15 |
| 13 | MOT-S-03 | 1 | 11 | operativo | 2025-04-05 |
| 14 | BOM-S-01 | 2 | 10 | operativo | 2025-01-15 |
| 15 | BOM-S-02 | 2 | 11 | operativo | 2025-01-15 |
| 16 | BOM-S-03 | 2 | 12 | operativo | 2025-01-15 |
| 17 | CIN-S-01 | 3 | 10 | operativo | 2025-01-15 |
| 18 | CIN-S-02 | 3 | 11 | operativo | 2025-01-15 |
| 19 | TAB-S-01 | 4 | 12 | operativo | 2025-01-15 |
| 20 | TAB-S-02 | 4 | 12 | dado de baja | 2025-01-15 |

El dispositivo 6 en mantenimiento y el 20 dado de baja permiten probar que no generen eventos de falta de reporte.

### `plata.sensor`

Se muestran los 26 sensores de Planta Norte. Planta Sur replica el patrón con ids 27 a 52.

| id_sensor | id_dispositivo | id_tipo_variable | nombre | estado |
|---|---|---|---|---|
| 1 | 1 | 1 | MOT-N-01-VIB | activo |
| 2 | 1 | 2 | MOT-N-01-TMP | activo |
| 3 | 1 | 3 | MOT-N-01-COR | activo |
| 4 | 2 | 1 | MOT-N-02-VIB | activo |
| 5 | 2 | 2 | MOT-N-02-TMP | activo |
| 6 | 2 | 3 | MOT-N-02-COR | activo |
| 7 | 3 | 1 | MOT-N-03-VIB | activo |
| 8 | 3 | 2 | MOT-N-03-TMP | activo |
| 9 | 3 | 3 | MOT-N-03-COR | fuera de servicio |
| 10 | 4 | 4 | BOM-N-01-PRE | activo |
| 11 | 4 | 5 | BOM-N-01-CAU | activo |
| 12 | 4 | 2 | BOM-N-01-TMP | activo |
| 13 | 5 | 4 | BOM-N-02-PRE | activo |
| 14 | 5 | 5 | BOM-N-02-CAU | activo |
| 15 | 5 | 2 | BOM-N-02-TMP | activo |
| 16 | 6 | 4 | BOM-N-03-PRE | activo |
| 17 | 6 | 5 | BOM-N-03-CAU | activo |
| 18 | 6 | 2 | BOM-N-03-TMP | activo |
| 19 | 7 | 6 | CIN-N-01-VEL | activo |
| 20 | 7 | 3 | CIN-N-01-COR | activo |
| 21 | 8 | 6 | CIN-N-02-VEL | activo |
| 22 | 8 | 3 | CIN-N-02-COR | activo |
| 23 | 9 | 7 | TAB-N-01-CON | activo |
| 24 | 9 | 8 | TAB-N-01-TEN | activo |
| 25 | 10 | 7 | TAB-N-02-CON | activo |
| 26 | 10 | 8 | TAB-N-02-TEN | activo |

El sensor 9 fuera de servicio sirve para probar los eventos de calidad de dato (decisión 17).

### `plata.configuracion_dispositivo`

| id_configuracion | id_dispositivo | parametros | valido_desde | valido_hasta |
|---|---|---|---|---|
| 1 | 1 | `{"vibracion":{"umbral_alerta":7.5,"umbral_critico":12.0},"temperatura":{"umbral_alerta":85.0},"corriente":{"umbral_alerta":18.0}}` | 2025-01-15 00:00:00 | 2026-06-15 10:30:00 |
| 2 | 1 | `{"vibracion":{"umbral_alerta":7.5,"umbral_critico":12.0},"temperatura":{"umbral_alerta":80.0},"corriente":{"umbral_alerta":18.0}}` | 2026-06-15 10:30:00 | *null* |
| 3 | 4 | `{"presion":{"umbral_alerta":6.0},"caudal":{"umbral_min":12.0},"temperatura":{"umbral_alerta":70.0}}` | 2025-01-15 00:00:00 | *null* |
| 4 | 7 | `{"velocidad":{"umbral_min":0.8,"umbral_alerta":2.5},"corriente":{"umbral_alerta":15.0}}` | 2025-01-15 00:00:00 | *null* |
| 5 | 9 | `{"consumo":{"umbral_alerta":250.0},"tension":{"umbral_min":370.0,"umbral_alerta":400.0}}` | 2025-01-15 00:00:00 | *null* |

El dispositivo 1 tiene dos versiones de configuración: la histórica y la vigente. Permite probar que una alerta antigua se interprete con el umbral que regía en su momento.

---

## 4. Capa plata — telemetría

### `plata.medicion`

Muestra de lecturas del sensor 1 (vibración de MOT-N-01) en torno al evento, más lecturas de otros sensores en el mismo instante.

| id_sensor | timestamp_medicion | valor | calidad |
|---|---|---|---|
| 1 | 2026-08-12 09:57:50 | 5.8200 | válida |
| 1 | 2026-08-12 09:58:00 | 6.4100 | válida |
| 1 | 2026-08-12 09:58:10 | 7.1500 | válida |
| 1 | 2026-08-12 09:58:20 | 9.4000 | válida |
| 1 | 2026-08-12 09:58:30 | 9.6200 | válida |
| 1 | 2026-08-12 09:58:40 | 8.9100 | válida |
| 2 | 2026-08-12 09:58:20 | 74.1000 | válida |
| 2 | 2026-08-12 09:58:50 | 74.8000 | válida |
| 3 | 2026-08-12 09:58:20 | 13.2000 | válida |
| 9 | 2026-08-12 09:58:20 | 0.0000 | sospechosa |
| 10 | 2026-08-12 09:58:30 | 4.8500 | válida |
| 11 | 2026-08-12 09:58:30 | 18.3000 | válida |
| 19 | 2026-08-12 09:59:00 | 1.4200 | válida |
| 23 | 2026-08-12 09:59:00 | 187.5000 | válida |
| 24 | 2026-08-12 09:59:00 | 381.2000 | válida |

La lectura del sensor 1 a las 09:58:20 supera el umbral de 7,5 y dispara el evento. La del sensor 9 con calidad `sospechosa` dispara un evento de calidad de dato apuntado al sensor.

### `plata.evento`

| id_evento | id_sensor | timestamp_medicion | tipo_evento | descripcion | valor_medido | umbral_vigente | timestamp_deteccion |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 2026-08-12 09:58:20 | umbral superado | Vibración por encima del umbral de alerta | 9.4000 | 7.5000 | 2026-08-12 09:58:21 |
| 2 | 1 | 2026-08-12 09:58:30 | umbral superado | Vibración por encima del umbral de alerta | 9.6200 | 7.5000 | 2026-08-12 09:58:31 |
| 3 | 9 | 2026-08-12 09:58:20 | valor fuera de rango | Lectura de corriente en cero con equipo en marcha | 0.0000 | *null* | 2026-08-12 09:58:21 |
| 4 | 13 | 2026-08-10 14:22:00 | ausencia de reporte | Sin lecturas durante más de 15 minutos | *null* | *null* | 2026-08-10 14:37:00 |

### `plata.alerta`

| id_alerta | id_dispositivo | id_sensor | id_evento | id_prediccion | origen | severidad | estado | timestamp_apertura | timestamp_cierre |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | *null* | 1 | *null* | umbral | alta | cerrada | 2026-08-12 09:58:25 | 2026-08-13 16:40:00 |
| 2 | 1 | *null* | *null* | 1 | predictivo | alta | abierta | 2026-08-12 10:05:00 | *null* |
| 3 | 3 | 9 | 3 | *null* | umbral | media | abierta | 2026-08-12 09:58:25 | *null* |
| 4 | 5 | 13 | 4 | *null* | umbral | baja | cerrada | 2026-08-10 14:37:00 | 2026-08-11 09:15:00 |
| 5 | 14 | *null* | *null* | 2 | predictivo | media | abierta | 2026-08-12 10:05:00 | *null* |

Las alertas 1 y 2 son el caso de doble origen simultáneo sobre el mismo dispositivo (decisión 23). La 3 apunta al sensor, no al equipo.

---

## 5. Capa plata — gestión

### `plata.usuario`

| id_usuario | nombre | email | rol_negocio | id_ubicacion |
|---|---|---|---|---|
| 1 | Marcela Ferreyra | mferreyra@planta.example | operario | 7 |
| 2 | Diego Ocampo | docampo@planta.example | operario | 10 |
| 3 | Sergio Villalba | svillalba@planta.example | tecnico | 1 |
| 4 | Laura Benítez | lbenitez@planta.example | tecnico | 2 |
| 5 | Andrés Quiroga | aquiroga@planta.example | supervisor | 1 |
| 6 | Paula Ledesma | pledesma@planta.example | supervisor | 2 |
| 7 | Nicolás Arrieta | narrieta@planta.example | cientifico_datos | *null* |
| 8 | Verónica Sosa | vsosa@planta.example | administrador | *null* |

Los usuarios 7 y 8 tienen alcance sobre ambas plantas, por eso `id_ubicacion` en `NULL`. Sirve para probar el caso de política RLS sin restricción de planta.

### `plata.orden_trabajo`

| id_orden_trabajo | id_alerta | tipo | estado | fecha_apertura | fecha_cierre |
|---|---|---|---|---|---|
| 1 | 1 | correctiva | cerrada | 2026-08-12 | 2026-08-13 |
| 2 | 3 | instrumentacion | en curso | 2026-08-12 | *null* |
| 3 | 4 | instrumentacion | cerrada | 2026-08-10 | 2026-08-11 |
| 4 | 1 | preventiva | cerrada | 2026-08-12 | 2026-08-13 |
| 5 | 2 | correctiva | en curso | 2026-08-12 | *null* |

Las órdenes 1 y 4 derivan de la misma alerta, ilustrando la relación 1:N entre alerta y orden de trabajo.

### `plata.intervencion`

| id_intervencion | id_orden_trabajo | id_usuario | fecha | observaciones | embedding |
|---|---|---|---|---|---|
| 1 | 1 | 3 | 2026-08-13 | Se detecta desalineación en el acople del lado motriz. Se realinea y se ajusta la base. La vibración vuelve a valores normales. | *(vector 384)* |
| 2 | 1 | 3 | 2026-08-13 | Control posterior a las 4 horas. Vibración estable en 3,1 mm/s. Se cierra la orden. | *(vector 384)* |
| 3 | 3 | 3 | 2026-08-11 | Cable de señal del sensor de presión flojo en la bornera. Se reajusta y se verifica continuidad. | *(vector 384)* |
| 4 | 4 | 4 | 2026-08-13 | Lubricación de rodamientos según plan. Sin observaciones adicionales. | *(vector 384)* |

Los embeddings se generan en la Actividad 9. Para la carga inicial pueden quedar en `NULL` o completarse con vectores aleatorios normalizados.

---

## 6. Capa oro — agregados

### `oro.agregado_horario`

| id_sensor | hora | promedio | minimo | maximo | desvio | cantidad_lecturas |
|---|---|---|---|---|---|---|
| 1 | 2026-08-12 08:00 | 3.1200 | 2.4100 | 4.0500 | 0.3100 | 360 |
| 1 | 2026-08-12 09:00 | 5.8400 | 2.9800 | 9.6200 | 1.9700 | 358 |
| 1 | 2026-08-12 10:00 | 4.2200 | 3.1000 | 6.8000 | 0.8800 | 360 |
| 2 | 2026-08-12 09:00 | 71.3000 | 68.2000 | 74.8000 | 1.4200 | 120 |
| 10 | 2026-08-12 09:00 | 4.7900 | 4.6100 | 4.9800 | 0.0900 | 120 |

El desvío elevado del sensor 1 en la hora 09:00 refleja el episodio anómalo. `cantidad_lecturas` menor a la esperada indica huecos de conectividad.

### `oro.agregado_diario`

| id_sensor | dia | promedio | minimo | maximo | desvio | cantidad_lecturas |
|---|---|---|---|---|---|---|
| 1 | 2026-08-10 | 3.0500 | 2.2000 | 4.1000 | 0.3400 | 8640 |
| 1 | 2026-08-11 | 3.4800 | 2.3100 | 5.9000 | 0.6200 | 8638 |
| 1 | 2026-08-12 | 4.7000 | 2.4100 | 9.6200 | 1.5100 | 8621 |
| 2 | 2026-08-12 | 71.9000 | 66.4000 | 74.8000 | 1.8800 | 2880 |
| 10 | 2026-08-12 | 4.8100 | 4.5500 | 5.0200 | 0.1100 | 2880 |

La progresión del promedio del sensor 1 entre el 10 y el 12 de agosto es la tendencia que el modelo predictivo detecta. Conviene generar varios días previos para que la consulta 4 (media móvil de 7 días) tenga datos suficientes.

---

## 7. Capa oro — features

### `oro.feature_motor_ventana`

| id_dispositivo | ventana_hasta | ventana_desde | vib_media | vib_max | vib_desvio | vib_tendencia | temp_media | temp_max | corr_media | cant_eventos | horas_operacion | fallo_en_horizonte | timestamp_calculo |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2026-08-09 10:00 | 2026-08-08 10:00 | 3.0100 | 4.0500 | 0.3000 | 0.0100 | 68.2000 | 71.0000 | 12.1000 | 0 | 23.50 | false | 2026-08-09 10:02 |
| 1 | 2026-08-10 10:00 | 2026-08-09 10:00 | 3.1400 | 4.6000 | 0.3800 | 0.0900 | 69.8000 | 72.4000 | 12.4000 | 0 | 24.00 | false | 2026-08-10 10:02 |
| 1 | 2026-08-11 10:00 | 2026-08-10 10:00 | 3.8200 | 6.1000 | 0.7400 | 0.2200 | 71.5000 | 73.6000 | 12.6000 | 0 | 24.00 | true | 2026-08-11 10:02 |
| 1 | 2026-08-12 10:00 | 2026-08-11 10:00 | 4.7000 | 9.6200 | 1.5100 | 0.3100 | 74.1000 | 74.8000 | 13.2000 | 2 | 22.50 | *null* | 2026-08-12 10:02 |
| 2 | 2026-08-12 10:00 | 2026-08-11 10:00 | 2.8800 | 3.9000 | 0.2600 | 0.0200 | 66.4000 | 68.1000 | 11.8000 | 0 | 24.00 | *null* | 2026-08-12 10:02 |

Las tres primeras filas del dispositivo 1 están maduras (horizonte de 72 h ya transcurrido) y sirven para entrenar. La cuarta es la fila fresca sobre la que se predice. La fila del 11/08 tiene la etiqueta en `true` porque hubo una intervención correctiva dentro de las 72 horas siguientes.

Las tablas `feature_bomba_ventana`, `feature_cinta_ventana` y `feature_tablero_ventana` siguen el mismo patrón con las columnas de sus propios sensores.

---

## 8. Capa oro — trazabilidad

### `oro.modelo`

| id_modelo | nombre | version | id_tipo_dispositivo | horizonte_h | estado |
|---|---|---|---|---|---|
| 1 | pred_falla_motor | v1 | 1 | 72 | retirado |
| 2 | pred_falla_motor | v2 | 1 | 72 | activo |
| 3 | pred_falla_bomba | v1 | 2 | 72 | activo |
| 4 | pred_falla_cinta | v1 | 3 | 72 | activo |
| 5 | pred_falla_tablero | v1 | 4 | 72 | activo |

El modelo 1 retirado permite probar que predicciones antiguas sigan siendo interpretables.

### `oro.corrida_entrenamiento`

| id_corrida | id_modelo | fecha | rango_desde | rango_hasta | criterio_seleccion | hiperparametros | uri_artefacto |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 2026-03-01 02:00 | 2025-03-01 00:00 | 2026-03-01 00:00 | `{"tipo_dispositivo":1,"calidad":"valida","excluir_estado":["dado de baja"]}` | `{"n_estimators":200,"max_depth":8}` | s3://modelos/motor/v1/model.pkl |
| 2 | 2 | 2026-07-01 02:00 | 2025-07-01 00:00 | 2026-07-01 00:00 | `{"tipo_dispositivo":1,"calidad":"valida","excluir_estado":["dado de baja"]}` | `{"n_estimators":300,"max_depth":10}` | s3://modelos/motor/v2/model.pkl |
| 3 | 3 | 2026-07-01 02:30 | 2025-07-01 00:00 | 2026-07-01 00:00 | `{"tipo_dispositivo":2,"calidad":"valida"}` | `{"n_estimators":300,"max_depth":10}` | s3://modelos/bomba/v1/model.pkl |

### `oro.metrica`

| id_metrica | id_corrida | nombre | particion | valor |
|---|---|---|---|---|
| 1 | 1 | auc | validacion | 0.874000 |
| 2 | 1 | f1 | validacion | 0.712000 |
| 3 | 1 | auc | test | 0.851000 |
| 4 | 2 | auc | entrenamiento | 0.945000 |
| 5 | 2 | auc | validacion | 0.912000 |
| 6 | 2 | f1 | validacion | 0.783000 |
| 7 | 2 | auc | test | 0.897000 |
| 8 | 3 | auc | validacion | 0.868000 |

El formato largo permite que cada corrida registre distintos indicadores sin modificar el esquema.

### `oro.prediccion`

| id_prediccion | id_dispositivo | id_modelo | timestamp_prediccion | ventana_desde | ventana_hasta | horizonte_h | score | umbral_aplicado |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 2 | 2026-08-12 10:05 | 2026-08-11 10:00 | 2026-08-12 10:00 | 72 | 0.8300 | 0.7000 |
| 2 | 14 | 3 | 2026-08-12 10:05 | 2026-08-11 10:00 | 2026-08-12 10:00 | 72 | 0.7400 | 0.7000 |
| 3 | 2 | 2 | 2026-08-12 10:05 | 2026-08-11 10:00 | 2026-08-12 10:00 | 72 | 0.1200 | 0.7000 |
| 4 | 1 | 2 | 2026-08-12 09:05 | 2026-08-11 09:00 | 2026-08-12 09:00 | 72 | 0.6100 | 0.7000 |
| 5 | 1 | 1 | 2026-06-20 10:05 | 2026-06-19 10:00 | 2026-06-20 10:00 | 72 | 0.3400 | 0.7000 |

Las predicciones 1 y 2 superan el umbral y disparan las alertas 2 y 5. La 3 no supera el umbral y no genera nada. La 5 fue generada por el modelo retirado.

---

## 9. Guía de implementación sugerida

### Paso 1 — Levantar PostgreSQL con pgvector

Conviene usar la imagen oficial de pgvector, que ya trae la extensión compilada:

```yaml
# docker-compose.yml
services:
  db:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_PASSWORD: bdia
      POSTGRES_DB: tp_bdia
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./sql:/sql
volumes:
  pgdata:
```

Montar la carpeta `sql/` permite ejecutar los scripts desde adentro del contenedor sin copiarlos cada vez.

### Paso 2 — Schemas y extensiones

```sql
CREATE SCHEMA bronce;
CREATE SCHEMA plata;
CREATE SCHEMA oro;
CREATE EXTENSION IF NOT EXISTS vector;
```

### Paso 3 — Crear tablas, respetando el orden de dependencias

El orden importa por las claves foráneas. Hay un punto no evidente: `plata.alerta` referencia a `oro.prediccion`, que a su vez referencia a `plata.dispositivo`. No es un ciclo, pero obliga a este orden:

1. Catálogos de plata (`unidad`, `tipo_variable`, `tipo_dispositivo`)
2. Activos de plata (`ubicacion`, `dispositivo`, `sensor`, `configuracion_dispositivo`)
3. `plata.medicion` y `plata.evento`
4. `oro.modelo` y `oro.prediccion`
5. `plata.alerta` (recién ahora puede declararse la FK hacia `oro.prediccion`)
6. Resto de plata (`usuario`, `orden_trabajo`, `intervencion`)
7. Resto de oro (agregados, features, `corrida_entrenamiento`, `metrica`)
8. Tablas de bronce (sin dependencias, pueden ir en cualquier momento)

Alternativa si el orden resulta incómodo: crear `plata.alerta` sin esa FK y agregarla al final con `ALTER TABLE ... ADD CONSTRAINT`.

### Paso 4 — Particionado de `medicion`

`medicion` se declara particionada por rango sobre `timestamp_medicion`. Hay que crear las particiones **antes** de insertar, o el `INSERT` falla por no encontrar partición destino.

```sql
CREATE TABLE plata.medicion (...) PARTITION BY RANGE (timestamp_medicion);

CREATE TABLE plata.medicion_2026_08 PARTITION OF plata.medicion
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
```

Conviene generar las particiones de los meses que se van a cargar con un bloque `DO` en lugar de escribirlas a mano.

### Paso 5 — Restricciones que no son claves

- `CHECK` en `alerta`: exactamente uno entre `id_evento` e `id_prediccion` presente.
- `CHECK` en `alerta.origen`: coherente con la FK poblada.
- `CHECK` en `ubicacion.nivel`: valores admitidos planta, area, linea.
- `CHECK` en `prediccion.score` y `umbral_aplicado`: entre 0 y 1.
- `UNIQUE` en `configuracion_dispositivo`: a lo sumo una fila vigente por dispositivo (índice parcial sobre `valido_hasta IS NULL`).

### Paso 6 — Índices

- BRIN sobre `medicion(timestamp_medicion)` en cada partición.
- B-tree sobre `alerta(id_dispositivo, estado)` para la consulta 2.
- B-tree sobre `evento(id_sensor, timestamp_medicion)`.
- Índice sobre `feature_motor_ventana(fallo_en_horizonte)` filtrado por `NOT NULL`, para el entrenamiento.
- El índice vectorial (HNSW o IVFFlat) sobre `intervencion.embedding` queda para la Actividad 9.

### Paso 7 — Triggers

Dos triggers, ambos `AFTER INSERT`:

1. Sobre `plata.medicion`: compara contra el umbral de la configuración vigente del dispositivo y, si corresponde, inserta en `plata.evento` copiando `valor_medido` y `umbral_vigente`.
2. Sobre `oro.prediccion`: si `score > umbral_aplicado`, inserta en `plata.alerta` con `origen = 'predictivo'`. Cruza schemas, así que el rol que ejecuta necesita permisos en ambos.

En los dos casos, el trigger sólo registra el hecho. La gestión posterior de la alerta corresponde a la aplicación.

### Paso 8 — Carga de datos

Sugerencia de orden de trabajo:

1. Cargar catálogos, activos y configuración a mano con los `INSERT` derivados de este anexo. Son pocas filas y conviene que sean exactas.
2. Generar las mediciones con un script (Python con `psycopg` o SQL con `generate_series`). Para 1 o 2 semanas de datos alcanza con `generate_series` sobre el rango temporal cruzado con la tabla de sensores, aplicando la frecuencia de cada tipo.
3. Introducir deliberadamente algunas anomalías: una rampa creciente de vibración en algún motor que termine en superación de umbral, un hueco de conectividad de 20 minutos, y algunas lecturas fuera de rango. Sin anomalías, las consultas 2, 3 y 5 devuelven vacío.
4. Dejar que los triggers generen los eventos y las alertas, en lugar de insertarlos a mano. Es la forma de verificar que funcionan.
5. Calcular agregados y features con `INSERT ... SELECT` desde plata.
6. Cargar el bloque de trazabilidad a mano, es poca cantidad.

Para las mediciones, un patrón que funciona bien es valor base por tipo de variable más ruido aleatorio, más un término de tendencia sólo en los dispositivos que se quiere que fallen.

### Paso 9 — Verificación contra las consultas de la Actividad 8

Antes de dar por cerrada la carga, conviene correr las seis consultas y confirmar que devuelven resultados no triviales:

| # | Consulta | Qué requiere de los datos |
|---|---|---|
| 1 | Última lectura de cada sensor de un dispositivo | Que todos los sensores del dispositivo tengan lecturas recientes |
| 2 | Alertas abiertas por planta, con severidad y antigüedad | Alertas abiertas en ambas plantas, con severidades distintas |
| 3 | Promedio y máximo de vibración por dispositivo y día | Varios días de mediciones y más de un motor, para que comparar tenga sentido |
| 4 | Media móvil de 7 días | Al menos 10 días de agregados diarios continuos |
| 5 | Ranking de dispositivos por intervenciones correctivas | Varias órdenes correctivas repartidas de forma desigual entre dispositivos |
| 6 | `EXPLAIN` comparando plata contra oro | Volumen suficiente en `medicion` para que la diferencia sea visible; con pocas filas el planificador elige seq scan en ambos casos y la comparación no muestra nada |

La consulta 6 es la que más volumen necesita. Si el tiempo de generación lo permite, conviene cargar bastante más de dos semanas sólo para poder mostrar esa comparación.

### Paso 10 — Orden de scripts sugerido en el repositorio

```
sql/
  00_schemas_extensiones.sql
  01_ddl_plata_catalogos.sql
  02_ddl_plata_activos.sql
  03_ddl_plata_telemetria.sql
  04_ddl_oro_prediccion.sql
  05_ddl_plata_alerta.sql
  06_ddl_plata_gestion.sql
  07_ddl_oro_analitica.sql
  08_ddl_bronce.sql
  09_particiones.sql
  10_indices.sql
  11_triggers.sql
  12_carga_catalogos.sql
  13_carga_activos.sql
  14_generacion_mediciones.sql
  15_calculo_agregados_features.sql
  16_carga_trazabilidad.sql
```

Numerarlos permite ejecutarlos en orden con un solo comando y volver a levantar la base desde cero cuando haga falta.