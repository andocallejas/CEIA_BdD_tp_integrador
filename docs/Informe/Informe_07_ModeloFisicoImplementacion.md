# 7. Modelo físico e implementación

## 7.1 Descripción general

Esta sección documenta la implementación física del modelo lógico sobre PostgreSQL. Se pasa de las 22 tablas descriptas en la Actividad 4 al DDL concreto (tipos de dato, claves, restricciones), el particionado de la serie temporal, los índices, los triggers que generan eventos y alertas, y una carga de datos de ejemplo coherente que permite validar todo el circuito.

La implementación se probó de punta a punta reconstruyendo la base desde cero sobre **PostgreSQL 16 con la extensión pgvector 0.6.0** (la elegida en la Actividad 6). Todos los scripts corren en orden sin errores y la carga de ejemplo deja la base en un estado consistente sobre el que se ejecutan las consultas de la Actividad 8.

## 7.2 Organización de los scripts

El código se versiona en la carpeta `db/` del repositorio, dividido en subcarpetas por función, con un prefijo numérico que fija el orden de ejecución de punta a punta:

| Carpeta              | Scripts     | Contenido                                                                                   |
| -------------------- | ----------- | ------------------------------------------------------------------------------------------- |
| `db/estructura/`     | 00 – 08, 11 | Schemas, extensión, DDL de las 22 tablas y triggers                                         |
| `db/indices_vistas/` | 09, 10      | Particiones de `medicion` e índices                                                         |
| `db/datos/`          | 12 – 18     | Carga de catálogos, activos, mediciones, agregados/features, trazabilidad, gestión y bronce |

Numerarlos permite levantar la base entera desde cero con un solo comando y volver a hacerlo cuantas veces haga falta.

## 7.3 Orden de creación y dependencias

El orden de creación no es libre: lo imponen las claves foráneas. Una tabla no puede referenciar a otra que todavía no existe. El orden adoptado es:

1. Schemas y extensión (`00`).
2. Catálogos de plata (`01`): no dependen de nada.
3. Activos de plata (`02`): dependen de los catálogos.
4. Telemetría de plata (`03`): `medicion` y `evento`, dependen de `sensor`.
5. Predicción de oro (`04`): `modelo` y `prediccion`.
6. Alerta de plata (`05`).
7. Gestión de plata (`06`): `usuario`, `orden_trabajo`, `intervencion`.
8. Resto de oro (`07`) y bronce (`08`).

El punto no evidente está entre los pasos 4, 5 y 6. `plata.alerta` tiene una clave foránea hacia `oro.prediccion` —la única dependencia de plata hacia oro en todo el modelo—, así que `oro.prediccion` debe crearse **antes** que `plata.alerta`. No es un ciclo, pero obliga a intercalar la creación de esas dos tablas de oro en medio de la capa plata.

## 7.4 Particionado de `medicion`

`medicion` se declara `PARTITION BY RANGE (timestamp_medicion)`: en lugar de una sola tabla, PostgreSQL la divide físicamente en subtablas por rango de fecha. Se crea una partición por mes (`medicion_2026_01` … `medicion_2026_12`) con un bloque `DO` que las genera en un bucle, en vez de escribir doce `CREATE TABLE` a mano (`09_particiones.sql`).

Dos consecuencias prácticas:

- PostgreSQL exige que la columna de particionado forme parte de la clave primaria; por eso la PK es compuesta `(id_sensor, timestamp_medicion)`.
- Cada `INSERT` se enruta automáticamente a la partición cuyo rango contiene su timestamp. Si esa partición no existe, el `INSERT` falla. Por eso las particiones se crean **antes** de cargar datos.

El particionado es lo que hace viable el volumen estimado (del orden de 59 millones de filas al año, ver Actividad 12): una consulta acotada a un rango de fechas sólo lee las particiones involucradas, y la purga del año vencido se resuelve descartando particiones enteras en vez de un `DELETE` masivo. La justificación de rendimiento se desarrolla en la Actividad 12.

## 7.5 Restricciones e índices

Además de las claves, el esquema declara restricciones que hacen cumplir reglas del dominio a nivel de base:

- `CHECK` de dominio cerrado en varios campos de texto (`ubicacion.nivel`, `dispositivo.estado`, `alerta.estado`, `metrica.particion`, etc.): la base rechaza valores fuera del conjunto admitido.
- `CHECK` de rango en `prediccion.score` y `umbral_aplicado` (deben estar entre 0 y 1).
- Doble `CHECK` en `alerta` que garantiza el origen único: exactamente una de `id_evento` / `id_prediccion` presente, y coherencia con el campo `origen`.
- Índice único parcial en `configuracion_dispositivo`: a lo sumo una configuración vigente (`valido_hasta IS NULL`) por dispositivo, permitiendo muchas versiones históricas.

Los índices (`10_indices.sql`) responden a los patrones de consulta:

- **BRIN** sobre `medicion(timestamp_medicion)`: mucho más compacto que un B-tree para datos naturalmente ordenados por tiempo. Se propaga a todas las particiones.
- **B-tree** sobre `alerta(id_dispositivo, estado)` para la consulta de alertas abiertas por planta, y sobre `evento(id_sensor, timestamp_medicion)`.
- Índice **parcial** sobre `feature_motor_ventana(fallo_en_horizonte)` filtrado por `NOT NULL`, que aísla las filas maduras (etiquetadas) usadas para entrenar.

El índice vectorial (HNSW) sobre `intervencion.embedding` se crea en la Actividad 9, junto con el cálculo de los embeddings.

## 7.6 Triggers: detección de eventos y alertas

La base sólo registra hechos; la gestión posterior (agrupar, asignar, escalar, cerrar) vive en la aplicación. Coherente con eso, se implementan dos triggers `AFTER INSERT` (`11_triggers.sql`):

1. **`medicion` → `evento`.** Al insertar una medición en plata, el trigger compara el valor contra el umbral de la configuración vigente del dispositivo (leído del campo JSONB `parametros`) y, si lo supera, inserta un evento de tipo `umbral superado`. Si la lectura viene con mala calidad (`fuera de rango` o `sospechosa`), inserta en cambio un evento de dato apuntado al sensor, no al equipo (distingue una falla de instrumentación de una falla real). En ambos casos copia `valor_medido` y `umbral_vigente`, para que el evento siga siendo interpretable aunque su medición se purgue al año. El trigger corre sobre plata y no sobre bronce, para que la detección opere siempre sobre datos ya validados.

2. **`prediccion` → `alerta`.** Al insertar una predicción en oro, si el `score` supera el `umbral_aplicado`, el trigger abre una alerta de origen predictivo. Este trigger vive en oro y escribe en plata: cruza schemas, algo a considerar en los permisos (Actividad 11).

Las alertas por umbral no las crea un trigger sino la aplicación, agrupando los eventos de un mismo problema (un episodio anómalo genera muchos eventos, pero una sola alerta). En la carga de ejemplo se cargan a mano para representar ese paso.

## 7.7 Carga de datos de ejemplo

La carga sigue el criterio de la guía de implementación: lo que es catálogo o de bajo volumen se carga a mano para que sea exacto, y las mediciones se generan con un script.

- **Catálogos y activos** (`12`, `13`): las 8 unidades, 8 tipos de variable y 6 tipos de dispositivo; las 12 ubicaciones, 20 dispositivos, 52 sensores y 5 configuraciones. El orden de los `INSERT` fija los identificadores `serial` de los que dependen el resto de los datos.
- **Mediciones** (`14`): 10 días de datos, una lectura cada 15 minutos, sólo para sensores activos de dispositivos operativos (los equipos en mantenimiento o de baja no generan datos). El valor es un valor base por tipo de variable más ruido. El motor 1 recibe además una rampa creciente de vibración que cruza su umbral, lo que hace que el trigger genere eventos reales. Se incluye una lectura de mala calidad para ejercitar el evento de instrumentación.
- **Agregados y features** (`15`): se calculan con `INSERT ... SELECT` sobre las mediciones. Al ser datos derivados, si se pierden se recalculan.
- **Trazabilidad y predicciones** (`16`): modelos, corridas, métricas y predicciones. Las predicciones que superan el umbral disparan las alertas predictivas vía trigger.
- **Gestión** (`17`): usuarios, las alertas por umbral, y las órdenes de trabajo e intervenciones derivadas.
- **Bronce** (`18`): una muestra del dato crudo, incluida una fila rechazada por validación (que no se promueve a plata).

Se introdujeron deliberadamente algunos casos de borde —un dispositivo en mantenimiento, uno dado de baja, un sensor fuera de servicio, una configuración historizada con dos versiones— para que las consultas de la Actividad 8 y las reglas del modelo tengan situaciones no triviales que ejercitar.

## 7.8 Verificación

La reconstrucción completa desde cero produce un estado consistente. Los conteos resultantes de la carga de ejemplo:

| Entidad                                     | Filas  |
| ------------------------------------------- | ------ |
| `medicion`                                  | 44.207 |
| `evento` (generados por trigger)            | 553    |
| `alerta` por umbral                         | 2      |
| `alerta` predictiva (generadas por trigger) | 2      |
| `orden_trabajo`                             | 2      |
| `intervencion`                              | 2      |
| `agregado_diario`                           | 506    |
| `feature_motor_ventana`                     | 66     |
| `prediccion`                                | 4      |

Los dos triggers quedan verificados por la propia carga: los 553 eventos surgen solos de la rampa de vibración y de la lectura de mala calidad, y de las cuatro predicciones insertadas sólo las dos que superan el umbral de 0,70 generan alerta. Sobre este estado se apoyan las consultas representativas de la Actividad 8.
