# 2. Relevamiento de datos necesarios

## 2.1 Introducción

En esta sección se retoma la info descripta en _1.5 Información que necesita gestionar_ y se la clasifica según las categorías propuestas por la consigna, con el objetivo de identificar qué tipo de dato es cada uno y qué implicancias tiene sobre su almacenamiento, acceso y tratamiento.

Vale aclarar que estas categorías no son mutuamente excluyentes: un mismo dato puede pertenecer a más de una a la vez. Por ejemplo, el registro de un usuario es a la vez estructurado y sensible; o una alerta abierta es estructurada y operacional. La clasificación simplemente busca asociar los datos a las dimensiones mencionadas en la consigna.

Nota: los ejemplos que se presentan en esta sección son mínimos y preliminares. Su objetivo es ilustrar aproximadamente la naturaleza de cada tipo de dato identificado, y no validar el modelo completo. Las entidades, relaciones, cardinalidades, tablas y consultas se realizarán progresivamente en las secciones correspondientes al modelo lógico, la implementación mínima y las consultas representativas, donde se presentará un conjunto de datos de ejemplo más completo.

## 2.2 Clasificación de los datos

| Tipo | Ejemplos | Capa (Medallion) |
|---|---|---|
| Estructurados | dispositivos, sensores, ubicaciones, mediciones, alertas, órdenes de trabajo | plata / oro |
| Semiestructurados | payload crudo de ingesta (JSONB), configuración de sensor (JSONB: umbrales, calibración) | bronce / plata |
| No estructurados | observaciones de texto libre cargadas por el técnico en cada intervención | plata |
| Operacionales | alertas abiertas o en revisión, órdenes de trabajo en curso | plata |
| Analíticos | features calculadas por ventana, predicciones de falla, métricas de modelos | oro |
| Sensibles | datos personales de usuarios y técnicos (nombre, email, etc. asociados a una intervención) | plata |
| Auditoría / trazabilidad | log de cambios de estado de alertas, histórico de configuración de dispositivo | plata |

## 2.3 Ejemplos representativos

### a) Datos estructurados

**`dispositivo`**

| id_dispositivo | nombre | tipo | id_ubicacion |
|---|---|---|---|
| 101 | Motor-A1 | motor_electrico | 5 |

**`sensor`**

| id_sensor | id_dispositivo | tipo_variable | unidad |
|---|---|---|---|
| 501 | 101 | vibracion | mm/s |

**`medicion`**

| id_sensor | timestamp | valor |
|---|---|---|
| 501 | 2026-08-10 08:00:00 | 2.3 |
| 501 | 2026-08-10 08:00:10 | 2.4 |
| 501 | 2026-08-10 08:00:20 | 5.8 |

### b) Datos semiestructurados

Payload crudo tal como llega a la capa bronce:

```json
{
  "device_id": "101",
  "sensor_id": "501",
  "ts": "2026-08-10T08:00:20Z",
  "vibration_mm_s": 5.8,
  "firmware": "v2.1.3"
}
```

### c) Datos no estructurados

Campo de texto libre dentro de `intervencion`:

**`intervencion`**

| id_intervencion | id_orden_trabajo | id_tecnico | observaciones |
|---|---|---|---|
| 301 | 201 | 42 | "Se detectó desalineación en el eje del motor. Vibración fuera de rango en dirección radial. Se realizó ajuste y se recomienda seguimiento en 7 días." |
| 302 | 201 | 42 | "Segunda visita: vibración estabilizada tras ajuste previo. Se cierra intervención." |

### d) Datos operacionales

**`alerta`**

| id_alerta | id_evento | severidad | estado | timestamp_apertura |
|---|---|---|---|---|
| 401 | 601 | alta | abierta | 2026-08-10 08:00:20 |
| 402 | 602 | media | en_revision | 2026-08-10 09:15:00 |

**`orden_trabajo`** (vista operacional, solo estado en curso)

| id_orden_trabajo | id_alerta | id_dispositivo | estado |
|---|---|---|---|
| 201 | 401 | 101 | en_curso |

### e) Datos analíticos

Feature/predicción calculada en la capa oro:

| id_dispositivo | ventana | vibracion_media | vibracion_max | prob_falla_7d |
|---|---|---|---|---|
| 101 | 2026-08-10 (diaria) | 3.1 | 5.8 | 0.62 |

### f) Datos sensibles

**`usuario`**

| id_usuario | nombre | rol | email | id_planta |
|---|---|---|---|---|
| 42 | J. Pérez | tecnico_mantenimiento | jperez@planta.com | 5 |

### g) Datos de auditoría o trazabilidad

**`log_cambio_estado_alerta`**

| id_log | id_alerta | estado_anterior | estado_nuevo | id_usuario | timestamp |
|---|---|---|---|---|---|
| 701 | 401 | abierta | en_revision | 42 | 2026-08-10 08:45:00 |
