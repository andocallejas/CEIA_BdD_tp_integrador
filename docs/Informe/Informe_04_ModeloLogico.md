# 4. Modelo lógico relacional

## 4.1 Descripción general

El modelo lógico pasa de las 14 entidades presentadas en el modelo conceptual a **22 tablas relacionales**, repartidas en la arquitectura Medallion: `bronce` (2), `plata` (13) y `oro` (7).

Este aumento en la cantidad de elementos se da por:

- Algunos atributos del modelo conceptual como `tipo_dispositivo`, `tipo_variable` y `unidad` ahora son tablas propias.
- Aparecen ahora las tablas de ingesta de datos crudos, no presentes en el conceptual.
- Se agregan dos tablas analíticas a modo de ejemplo (aparte de las asociadas a la predicción): `agregado_horario` y `agregado_diario`.
- Las dos relaciones N:M del conceptual no se convierten en tablas puente. Sino que se resuelven guardando el criterio que selecciona las mediciones (rango temporal y filtros) en lugar de enumerarlas fila por fila.


### Volúmenes y retención estimados

Se realiza una breve estimación de volúmenes de datos que surge de contemplar 2 plantas × 10 dispositivos por planta (3 motores, 3 bombas, 2 cintas transportadoras, 2 tableros eléctricos) = 52 sensores en total, con frecuencias de muestreo que podrían ir de 10 a 60 segundos según el tipo, lo que da unas 161.000 lecturas diarias.

Esto derivaría en aproximadamente 59 millones de registros de mediciones al año.
Por lo tanto se plantea:
- En la capa plata, sólo se retiene un año ventana de mediciones.
- Se retienen todos los datos históricos de eventos, alertas e intervenciones porque se contempla serán de unas decenas de miles al año.
- La capa analítica en oro, se retiene probablemente por algunos años, ya que realiza agrupaciones reduciendo notablemente el volumen y permitiendo hacer análisis interanual y demás.
- Las tablas de entrenamiento y predicciones se retienen probablemente por algunos años.
- Las tablas tipo catálogos se retienen completas.


### Nota sobre el alcance del modelo

Se considera que la base registra hechos; se reserva para capa de aplicaciones cuestiones como el gobierno de los procesos con estado. Ejemplo: el modelo almacena que una alerta se abrió, que una orden de trabajo existe y que una intervención se registró, pero no las transiciones ni las reglas que las producen. Las agrupaciones alertas del mismo dispositivo, asignaciones de técnicos, escalar una alerta o cerrar una orden se contemplan dentro de aplicaciones fuera del alcance de este proyecto.

Adicionalmente, el sistema se plantea **en régimen**, con aproximadamente 18 meses de operación previa: ya existe historia suficiente de mediciones e intervenciones para haber podido entrenar modelos, y entonces el ciclo de predicción estar activo.

---

## 4.2 Capa bronce

Recibe el dato tal como llega. Las tablas no tienen claves foráneas. El payload se almacena como `jsonb` (no `json`) para poder indexar y consultar claves internas sin parsear el documento completo.

Se separan dos tablas porque los patrones de llegada son considerablemente distintos: las mediciones son de ocurrencia constante, mientras que los cambios de configuración de los sensores son mucho más esporádicos y manuales.

### `bronce.medicion_cruda`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_medicion_cruda` | `bigserial` | Identificador interno del lote recibido | PK |
| `payload` | `jsonb` | Contenido del mensaje tal como llegó  | |
| `timestamp_recepcion` | `timestamptz` | Momento de llegada a la base | |
| `procesado` | `boolean` | Indica si la fila ya fue promovida a la capa plata | |
| `error_validacion` | `text` | Motivo del rechazo si no superó la validación; `NULL` si fue válida | |


### `bronce.configuracion_cruda`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_configuracion_cruda` | `bigserial` | Identificador interno del mensaje recibido | PK |
| `payload` | `jsonb` | Configuración de sensor tal como llegó (umbrales, calibración) | |
| `timestamp_recepcion` | `timestamptz` | Momento de llegada a la base | |
| `procesado` | `boolean` | Indica si la fila ya fue promovida a la capa plata | |


---

## 4.3 Capa plata

Es la capa normalizada del modelo. Se busca asegurar la integridad referencial y las restricciones del dominio. Todas las tablas están en 3FN.

### Catálogos

#### `plata.unidad`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_unidad` | `serial` | Identificador de la unidad de medida | PK |
| `simbolo` | `varchar(10)` | Símbolo de la unidad (mm/s, °C, A, bar) | |
| `nombre` | `varchar(50)` | Nombre completo de la unidad | |

#### `plata.tipo_variable`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_tipo_variable` | `serial` | Identificador del tipo de variable medida | PK |
| `nombre` | `varchar(50)` | Variable física (vibración, temperatura, corriente, presión, caudal, velocidad, consumo, tensión) | |
| `id_unidad` | `integer` | Unidad en que se expresa esta variable | FK → `unidad.id_unidad` |


#### `plata.tipo_dispositivo`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_tipo_dispositivo` | `serial` | Identificador del tipo de equipo | PK |
| `nombre` | `varchar(50)` | Tipo de equipo (motor eléctrico, bomba centrífuga, cinta transportadora, tablero eléctrico) | |
| `descripcion` | `text` | Descripción del tipo de equipo | |

El catálogo podría contener más tipos que los cuatro que se toman de ejemplo para todo el trabajo.

### Activos

#### `plata.ubicacion`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_ubicacion` | `serial` | Identificador de la ubicación | PK |
| `nombre` | `varchar(100)` | Nombre de la planta, área o línea | |
| `nivel` | `varchar(20)` | Nivel jerárquico: planta, área o línea | |
| `id_ubicacion_padre` | `integer` | Ubicación contenedora; `NULL` en el nivel planta | FK → `ubicacion.id_ubicacion` |

La tabla contiene jerarquía autoreferencial. Se puede recorrer hacia arriba permitiendo encontrar finalmente a qué planta pertenece cualquier nivel inferior. Esto será necesario para el aislamiento de información por RLS.

#### `plata.dispositivo`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_dispositivo` | `serial` | Identificador del equipo | PK |
| `nombre` | `varchar(100)` | Identificación del equipo en planta | |
| `id_tipo_dispositivo` | `integer` | Tipo de equipo | FK → `tipo_dispositivo.id_tipo_dispositivo` |
| `id_ubicacion` | `integer` | Ubicación física (típicamente una línea) | FK → `ubicacion.id_ubicacion` |
| `estado` | `varchar(20)` | Situación del equipo: operativo, en mantenimiento o dado de baja | |
| `fecha_alta` | `date` | Fecha de incorporación al sistema | |

El campo `estado` evita que un equipo detenido de forma planificada genere eventos de falta de reporte.

#### `plata.sensor`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_sensor` | `serial` | Identificador del sensor | PK |
| `id_dispositivo` | `integer` | Equipo al que está montado | FK → `dispositivo.id_dispositivo` |
| `id_tipo_variable` | `integer` | Variable que mide  | FK → `tipo_variable.id_tipo_variable` |
| `nombre` | `varchar(100)` | Identificación del sensor | |
| `estado` | `varchar(20)` | Activo o fuera de servicio | |

#### `plata.configuracion_dispositivo`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_configuracion` | `serial` | Identificador de la versión de configuración | PK |
| `id_dispositivo` | `integer` | Equipo configurado | FK → `dispositivo.id_dispositivo` |
| `parametros` | `jsonb` | Parámetros de operación configurados y valores | |
| `valido_desde` | `timestamptz` | Inicio de vigencia de esta configuración | |
| `valido_hasta` | `timestamptz` | Fin de vigencia; `NULL` en la configuración vigente | |

El campo parámetros contiene los umbrales utlizados por el trigger para crear un evento por superación de valor umbral. El trigger se aplica recién en esta etapa y no en bronce porque aquí los datos están validados, evitando disparos de alertas por mediciones corruptas.

No se sobrescriben las versiones anteriores de configuración. Esto porque una alerta pasada debe poder interpretarse con el umbral vigente en su momento, no con el actual, dado que podría prestarse a confusión.

### Telemetría

#### `plata.medicion`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_sensor` | `integer` | Sensor que generó la medición | PK, FK → `sensor.id_sensor` |
| `timestamp_medicion` | `timestamptz` | Momento de la medición | PK |
| `valor` | `numeric(12,4)` | Valor medido, en la unidad del tipo de variable | |
| `calidad` | `varchar(20)` | Resultado de la validación: válida, fuera de rango o sospechosa | |

Tabla con clave primaria compuesta. Estará particionada por rango mensual sobre `timestamp_medicion`, con índice BRIN sobre esa columna (ver Actividad 12). Se utiliza formato largo: una fila por lectura, no una columna por variable, para incorporar nuevos sensores sin rediseñar el modelo.

El campo `calidad` también dispara eventos: una medición marcada como fuera de rango o sospechosa porque viene vacía genera un evento pero apuntado al sensor, no al dispositivo.

#### `plata.evento`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_evento` | `bigserial` | Identificador del evento | PK |
| `id_sensor` | `integer` | Sensor de la medición que lo disparó | FK → `sensor.id_sensor` |
| `timestamp_medicion` | `timestamptz` | Momento de la medición que lo disparó | |
| `tipo_evento` | `varchar(30)` | Umbral superado, valor fuera de rango o ausencia de reporte | |
| `descripcion` | `text` | Descripción legible del evento | |
| `valor_medido` | `numeric(12,4)` | Copia del valor que disparó el evento | |
| `umbral_vigente` | `numeric(12,4)` | Copia del umbral aplicado en ese momento | |
| `timestamp_deteccion` | `timestamptz` | Momento en que el trigger registró el evento | |

`id_sensor` y `timestamp_medicion` identifican la medición de origen, pero **no se declara clave foránea hacia `medicion`**. Esto dado que las mediciones se borran al año por su alto volumen y los eventos deben sobrevivir, porque alimentan órdenes de trabajo que se conservan mucho más tiempo. Por el mismo motivo se copian `valor_medido` y `umbral_vigente`, de modo que el evento siga siendo interpretable una vez eliminada la medición que le dio origen.

Los eventos se detectan mediante un trigger sobre la capa plata y no sobre bronce, para que la detección corra sobre datos ya validados. Caso contrario podría dispararse un evento por una medición fuera de rango o inexistente para revisar el dispositivo contralo cuando en realidad lo que hay que revisar es el sensor.

#### `plata.alerta`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_alerta` | `bigserial` | Identificador de la alerta | PK |
| `id_dispositivo` | `integer` | Equipo afectado | FK → `dispositivo.id_dispositivo` |
| `id_sensor` | `integer` | Sensor afectado, solo en alertas de instrumentación; `NULL` en el resto | FK → `sensor.id_sensor` |
| `id_evento` | `bigint` | Evento que la originó; `NULL` en alertas predictivas | FK → `evento.id_evento` |
| `id_prediccion` | `bigint` | Predicción que la originó; `NULL` en alertas por evento | FK → `oro.prediccion.id_prediccion` |
| `origen` | `varchar(20)` | Umbral o predictivo | |
| `severidad` | `varchar(20)` | Nivel de criticidad | |
| `estado` | `varchar(20)` | Abierta, en revisión, cerrada | |
| `timestamp_apertura` | `timestamptz` | Momento de creación de la alerta | |
| `timestamp_cierre` | `timestamptz` | Momento de cierre; `NULL` mientras está abierta | |

Restricción `CHECK`: exactamente uno entre `id_evento` e `id_prediccion` debe estar presente. Cada alerta tiene un único origen, aunque un mismo dispositivo puede tener varias alertas abiertas simultáneamente, incluso de orígenes distintos.

`id_prediccion` es la única clave foránea que apunta de plata hacia oro; todas las demás dependencias entre capas van en sentido contrario.

### Gestión

#### `plata.usuario`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_usuario` | `serial` | Identificador del usuario de aplicación | PK |
| `nombre` | `varchar(100)` | Nombre del usuario | |
| `email` | `varchar(100)` | Correo de contacto | |
| `rol_negocio` | `varchar(30)` | Rol (operario, técnico, supervisor, científico de datos, administrador) | |
| `id_ubicacion` | `integer` | Ámbito de alcance del usuario | FK → `ubicacion.id_ubicacion` |

Los usuarios de aplicación no son roles de PostgreSQL: la aplicación se conecta con un rol de servicio y comunica la identidad por variable de sesión, que las políticas RLS luego consultan (ver Actividad 11).

#### `plata.orden_trabajo`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_orden_trabajo` | `serial` | Identificador de la orden | PK |
| `id_alerta` | `bigint` | Alerta que la originó | FK → `alerta.id_alerta` |
| `tipo` | `varchar(30)` | Correctiva, preventiva o de instrumentación | |
| `estado` | `varchar(20)` | Situación de la orden | |
| `fecha_apertura` | `date` | Fecha de emisión | |
| `fecha_cierre` | `date` | Fecha de cierre; `NULL` mientras está en curso | |

La orden no almacena el equipo ni el sensor objetivo: ambos se obtienen de la alerta que la originó, evitando una dependencia transitiva.

#### `plata.intervencion`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_intervencion` | `serial` | Identificador de la intervención | PK |
| `id_orden_trabajo` | `integer` | Orden a la que pertenece | FK → `orden_trabajo.id_orden_trabajo` |
| `id_usuario` | `integer` | Técnico que la realizó | FK → `usuario.id_usuario` |
| `fecha` | `date` | Fecha de ejecución | |
| `observaciones` | `text` | Descripción en lenguaje natural de lo realizado y observado | |
| `embedding` | `vector(384)` | Representación vectorial de las observaciones, para búsqueda por similitud | |

Toda intervención pertenece a una orden de trabajo. El campo `embedding` (extensión pgvector) permite buscar intervenciones pasadas con descripciones parecidas; se desarrolla en la Actividad 9. El rol científico de datos no accede a `id_usuario`, por tratarse de un dato personal innecesario para el análisis.

---

## 4.4 Capa oro

Esta capa contiene una capa de consumo analítico, desnormalizada y optimizada para lectura. No recibe escrituras directas de la operación: se recalcula a partir de plata.

Luego, convive en esta capa un bloque asociado a la predicción (`modelo`, `corrida_entrenamiento`, `metrica`, `prediccion`) que sí está normalizado, por ser metadatos de bajo volumen y no datos analíticos agregados y donde la redundancia introduciría anomalías de actualización.

### Agregados analíticos

#### `oro.agregado_horario`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_sensor` | `integer` | Sensor agregado | PK, FK → `plata.sensor.id_sensor` |
| `hora` | `timestamptz` | Hora truncada del período agregado | PK |
| `promedio` | `numeric(12,4)` | Valor promedio en la hora | |
| `minimo` | `numeric(12,4)` | Valor mínimo en la hora | |
| `maximo` | `numeric(12,4)` | Valor máximo en la hora | |
| `desvio` | `numeric(12,4)` | Desvío estándar en la hora | |
| `cantidad_lecturas` | `integer` | Lecturas efectivamente registradas | |

#### `oro.agregado_diario`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_sensor` | `integer` | Sensor agregado | PK, FK → `plata.sensor.id_sensor` |
| `dia` | `date` | Día del período agregado | PK |
| `promedio` | `numeric(12,4)` | Valor promedio en el día | |
| `minimo` | `numeric(12,4)` | Valor mínimo en el día | |
| `maximo` | `numeric(12,4)` | Valor máximo en el día | |
| `desvio` | `numeric(12,4)` | Desvío estándar en el día | |
| `cantidad_lecturas` | `integer` | Lecturas efectivamente registradas | |

Ambos agregados sostienen los tableros de supervisión y el análisis histórico. Se conservan más allá del año de retención del detalle en plata, lo que permite análisis interanual sin sostener la serie completa de mediciones en plata.

### Features para el modelo predictivo

#### `oro.feature_motor_ventana`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_dispositivo` | `integer` | Dispositivo en cuestión| PK, FK → `plata.dispositivo.id_dispositivo` |
| `ventana_hasta` | `timestamptz` | Fin de la ventana temporal resumida | PK |
| `ventana_desde` | `timestamptz` | Inicio de la ventana temporal resumida | |
| `vib_media` | `numeric(12,4)` | Vibración promedio en la ventana | |
| `vib_max` | `numeric(12,4)` | Vibración máxima en la ventana | |
| `vib_desvio` | `numeric(12,4)` | Desvío de la vibración en la ventana | |
| `vib_tendencia` | `numeric(12,4)` | Pendiente de la vibración: captura si viene creciendo | |
| `temp_media` | `numeric(12,4)` | Temperatura promedio en la ventana | |
| `temp_max` | `numeric(12,4)` | Temperatura máxima en la ventana | |
| `corr_media` | `numeric(12,4)` | Corriente promedio en la ventana | |
| `cant_eventos` | `integer` | Eventos registrados en la ventana | |
| `horas_operacion` | `numeric(6,2)` | Horas efectivas de operación en la ventana | |
| `fallo_en_horizonte` | `boolean` | Etiqueta de entrenamiento: si hubo intervención correctiva dentro del horizonte posterior. `NULL` mientras el horizonte no transcurrió | |
| `timestamp_calculo` | `timestamptz` | Momento en que se calculó la fila | |

Una fila por dispositivo y ventana. La ventana es de **24 horas y se recalcula cada hora**, de modo que la tabla crece unas 175 mil filas al año, frente a los ~59 millones de `medicion`.

Esta única tabla alimenta tanto el entrenamiento como la predicción, lo que garantiza que las features se calculen de forma idéntica en ambos casos. La diferencia está en qué filas usa cada uno: las anteriores al horizonte de predicción ya tienen `fallo_en_horizonte` cargado y sirven para entrenar; las más recientes lo tienen en `NULL` y son sobre las que se predice.

`fallo_en_horizonte` se almacena como columna en lugar de calcularse en cada entrenamiento.

`oro.feature_bomba_ventana`, `oro.feature_cinta_ventana` y `oro.feature_tablero_ventana` son estructuras análogas, con las columnas correspondientes a sus propios sensores:

| Tabla | Columnas específicas |
|---|---|
| `feature_bomba_ventana` | presión (media, máx, desvío, tendencia), caudal (media, desvío), temperatura (media, máx) |
| `feature_cinta_ventana` | velocidad (media, desvío, tendencia), corriente (media, máx) |
| `feature_tablero_ventana` | consumo (media, máx, tendencia), tensión (media, desvío) |

Se mantienen tablas separadas por tipo de dispositivo porque las variables medidas no son comparables entre tipos: una tabla única dejaría la mayoría de las columnas en `NULL` para cada fila, y un valor nulo en una feature no es neutro para un modelo de aprendizaje automático.

### Trazabilidad del modelo predictivo

#### `oro.modelo`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_modelo` | `serial` | Identificador del modelo | PK |
| `nombre` | `varchar(100)` | Nombre del modelo | |
| `version` | `varchar(20)` | Versión | |
| `id_tipo_dispositivo` | `integer` | Tipo de equipo al que aplica | FK → `plata.tipo_dispositivo.id_tipo_dispositivo` |
| `horizonte_h` | `integer` | Horizonte de predicción en horas | |
| `estado` | `varchar(20)` | Activo o retirado | |

Existe un modelo por tipo de dispositivo, ya que la evolución de un motor hacia su deterioro no es comparable por ejemplo con la de un tablero eléctrico. Los modelos retirados se conservan para poder interpretar predicciones históricas.

#### `oro.corrida_entrenamiento`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_corrida` | `bigserial` | Identificador de la corrida | PK |
| `id_modelo` | `integer` | Modelo entrenado | FK → `modelo.id_modelo` |
| `fecha` | `timestamptz` | Momento del entrenamiento | |
| `rango_desde` | `timestamptz` | Inicio del período de datos utilizado | |
| `rango_hasta` | `timestamptz` | Fin del período de datos utilizado | |
| `criterio_seleccion` | `jsonb` | Filtros aplicados para seleccionar las filas de features | |
| `hiperparametros` | `jsonb` | Configuración del algoritmo, en formato flexible | |
| `uri_artefacto` | `text` | Ruta al modelo entrenado, almacenado fuera de la base | |

`rango_desde`, `rango_hasta` y `criterio_seleccion` reemplazan la tabla puente que exigiría la relación N:M del modelo conceptual: la corrida queda reproducible sin enumerar las mediciones que participaron.

El uso de `jsonb` para los hiperparámetros mantiene el modelo independiente del algoritmo concreto que se aplique.

#### `oro.metrica`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_metrica` | `bigserial` | Identificador de la métrica | PK |
| `id_corrida` | `bigint` | Corrida que la produjo | FK → `corrida_entrenamiento.id_corrida` |
| `nombre` | `varchar(50)` | Nombre de la métrica | |
| `particion` | `varchar(20)` | Conjunto sobre el que se calculó: entrenamiento, validación o test | |
| `valor` | `numeric(12,6)` | Valor obtenido | |

Formato largo: una fila por métrica en lugar de una columna por métrica. Permite registrar cualquier indicador sin modificar el esquema, sea cual sea el tipo de modelo aplicado.

#### `oro.prediccion`

| Campo | Tipo | Descripción | Clave |
|---|---|---|---|
| `id_prediccion` | `bigserial` | Identificador de la predicción | PK |
| `id_dispositivo` | `integer` | Equipo evaluado | FK → `plata.dispositivo.id_dispositivo` |
| `id_modelo` | `integer` | Modelo que la generó | FK → `modelo.id_modelo` |
| `timestamp_prediccion` | `timestamptz` | Momento en que se ejecutó la predicción | |
| `ventana_desde` | `timestamptz` | Inicio de la ventana de features utilizada | |
| `ventana_hasta` | `timestamptz` | Fin de la ventana de features utilizada | |
| `horizonte_h` | `integer` | Horas hacia adelante que cubre la predicción | |
| `score` | `numeric(5,4)` | Probabilidad estimada de falla | |
| `umbral_aplicado` | `numeric(5,4)` | Umbral vigente al momento de la predicción | |

La predicción se ejecuta cada hora por dispositivo, sobre las filas de features más recientes. Un trigger genera una alerta de origen predictivo cuando `score` supera `umbral_aplicado`, generando una alerta → orden de trabajo. El trigger sólo crea la alerta: su gestión posterior corresponde a la aplicación.

Guardar `umbral_aplicado` junto al `score` permite que una predicción antigua siga siendo interpretable aunque el criterio de alerta cambie después.

`id_dispositivo` y `ventana_hasta` identifican la fila de features utilizada, pero **no se declara clave foránea**, porque la tabla de destino depende del tipo de dispositivo. El vínculo se resuelve por `JOIN` contra la tabla de features correspondiente.

Un `score` numérico acompañado de su umbral es la salida natural de prácticamente cualquier clasificador, de modo que el esquema no queda atado a una técnica concreta de aprendizaje automático.

---

## 4.5 Diagrama

El diagrama entidad-relación del modelo lógico, con todas las tablas, claves y relaciones, se adjunta como `docs/modelo_logico.png`. Se versiona junto con su fuente editable.

