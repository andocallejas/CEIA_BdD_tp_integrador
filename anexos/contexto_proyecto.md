# Contexto del proyecto — TP Integrador BDIA

> Este documento es la fuente de verdad del proyecto. Se sube a Project Knowledge (de cada integrante, en su propia cuenta de Claude) y se actualiza al final de cada sesión de trabajo. Cualquier chat nuevo debería poder arrancar leyendo solo esto.

---

## 1. Marco general

Materia: *Bases de Datos para IA*. Trabajo Práctico Integrador en equipo de 2 personas, con entrega vía repositorio Git (estructura sugerida por la cátedra, informe en Markdown convertido a PDF al final con Pandoc).

Consigna: elegir uno de 10 casos de uso propuestos, darle impronta propia, y resolver 12 actividades que van desde el análisis del caso hasta escalabilidad y rendimiento, entregando modelos (conceptual/lógico/físico), justificaciones, DDL, consultas y un informe.

Fechas administrativas: informar el caso elegido antes del inicio de la Clase 6. Entrega: domingo siguiente a la última clase, 23:59.

---

## 2. Escenario elegido

**Caso 3 — Monitoreo IoT con análisis predictivo.**

Impronta propia: **planta industrial con dos sitios**, con equipos rotativos monitoreados por sensores. El sistema busca pasar de mantenimiento reactivo a predictivo: detectar eventos anómalos, generar alertas, registrar intervenciones de mantenimiento y sostener análisis histórico y predictivo sobre las mediciones.

### Dispositivos y sensores (alcance elegido: 4 tipos de dispositivo)

| Dispositivo | Sensores | Frecuencia aproximada |
|---|---|---|
| Motor eléctrico | vibración, temperatura, corriente | 10 s / 30 s / 30 s |
| Bomba centrífuga | presión, caudal, temperatura | 30 s |
| Cinta transportadora | velocidad, corriente | 60 s |
| Tablero eléctrico | consumo, tensión | 60 s |

El catálogo de tipos de dispositivo puede listar más tipos (para mostrar generalidad del modelo), pero los datos de ejemplo se cargan solo para estos 4. Debe haber más de una instancia de cada tipo por planta, para que consultas de ranking/comparación no sean triviales.

**Reparto fijado:** 3 motores, 3 bombas, 2 cintas y 2 tableros **por planta** = 10 dispositivos por planta, **20 dispositivos y 52 sensores en total**. De este reparto surgen la estimación de volumen (decisión 12) y los datos de ejemplo de la actividad 7.

### Jerarquía de ubicación
`Planta → Área/Sector → Línea de producción` (autoreferencial en el modelo, 3 niveles alcanzan).

### Usuarios del dominio (roles de negocio, no roles de base de datos)
- **Operario de línea** — plata, solo sus dispositivos/ubicación.
- **Técnico de mantenimiento** — plata, registra intervenciones (vía su aplicación, no SQL directo).
- **Supervisor de planta** — plata + oro, alcance de su planta completa.
- **Científico de datos** — plata + oro, todas las plantas, sin datos personales (ej. sin ver qué técnico específico hizo qué intervención).
- **Administrador / ingeniero de datos** — bronce + plata + oro, todo.

Se evaluó incluir planificador de mantenimiento e ingeniero de confiabilidad; se descartaron por simplicidad, dejando aclarado en el informe que podrían existir más roles organizacionales sin que aporten diferenciación real de acceso a datos.

---

## 3. Decisiones de diseño (bitácora)

| # | Decisión | Motivo | Afecta actividades |
|---|---|---|---|
| 1 | Mediciones en formato "largo/angosto" (una fila por lectura, no una columna por variable) | Flexible ante nuevos sensores/variables; estándar para series temporales | 4, 5, 9, 12 |
| 2 | Arquitectura en capas Bronce/Plata/Oro (Medallion) vía **schemas de PostgreSQL** | Separa madurez del dato (crudo → validado → analítico); coincide con lo visto en Clase 5 | 7, 10, 11 |
| 3 | RLS (Row-Level Security) para aislamiento por planta/ubicación, aplicado sobre plata y también sobre las vistas de oro. Para ocultar columnas sensibles dentro de una fila visible (ej. `tecnico_id` para el científico de datos), RLS **no alcanza** por ser un control a nivel de fila — se combina con vistas en oro que no proyectan esas columnas | Sin RLS en oro, un agregado filtra datos entre plantas igual; el ocultamiento de columnas requiere un mecanismo aparte (vista, o column-level GRANT) | 7, 11 |
| 4 | Doble identidad: roles de PostgreSQL (técnicos, pocos) vs. usuarios de aplicación (tabla `usuario`, con rol de negocio) | Los usuarios finales no tienen credencial de base; la app se conecta con un rol de servicio y pasa el usuario por variable de sesión (`SET LOCAL app.usuario_id`), que las políticas RLS consultan | 11 |
| 5 | Detección de eventos: trigger simple `AFTER INSERT` en la capa **plata** (no en bronce) | En bronce el dato no está validado (podría haber valores corruptos) → evita falsos positivos | 7, 10 |
| 6 | La base **crea** alertas (por trigger de umbral o de predicción); la **gestión** posterior (agrupar, asignar, escalar, cerrar) vive en la aplicación | Criterio unificador: la base registra hechos, la aplicación gobierna procesos con estado. Una alerta recién creada es un hecho; una alerta asignada o escalada es un proceso con historia y responsables | 4, 7, 10 |
| 7 | Motor único: **PostgreSQL** (con extensión pgvector) | Cubre series temporales (particionamiento), semiestructurado (JSONB), seguridad por fila (RLS) y vectorial, todo en un sistema. Alternativas evaluadas y descartadas: TimescaleDB/InfluxDB (buenas para la serie, débiles para el resto del dominio), MongoDB (pierde integridad referencial y RLS), vectorial dedicado tipo Pinecone (innecesario para el volumen de texto del caso) | 6 |
| 8 | Normalización según el **patrón de acceso**: se normaliza donde se escribe, se desnormaliza lo derivado y voluminoso. Plata en 3FN. Oro contiene **dos bloques desnormalizados** (agregados y features) y **uno normalizado** (trazabilidad: `modelo`, `corrida_entrenamiento`, `metrica`, `prediccion`). Bronce queda fuera del análisis | La redundancia sólo es peligrosa donde hay escritura. El bloque de trazabilidad no es derivado, se escribe directo y es de bajo volumen, con lo cual ninguno de los dos motivos para desnormalizar aplica. En bronce el dato es JSONB sin esquema declarado: no hay dependencias funcionales que evaluar | 5 |
| 9 | Búsqueda vectorial (pgvector) acotada **solo** a `intervencion.observaciones` (texto libre del técnico) | Caso de uso genuino: recuperar intervenciones pasadas con síntomas parecidos, descriptos en lenguaje natural. Independiente del análisis predictivo numérico (que consume series, no texto). Se descartó vectorizar la señal de vibración por ser mucho más compleja de justificar/implementar en el alcance del TP. El `embedding` se almacena junto al texto en plata pese a ser un dato derivado, porque calcularlo requiere invocar un modelo externo y las observaciones son inmutables una vez registradas | 4, 5, 9 |
| 10 | Riesgo de seguridad a documentar explícitamente: la búsqueda por similitud debe respetar RLS — no puede devolver intervenciones de una planta a la que el usuario no tiene acceso | Es el ángulo de "riesgo de exposición vía IA" que pide el enunciado | 9, 11 |
| 11 | Retención diferenciada por entidad: **mediciones** con 1 año de detalle en plata (agregados horarios/diarios conservados más tiempo en oro); **órdenes de trabajo e intervenciones** conservadas por un período bastante más extenso (potencialmente indefinido), al ser muchos menos registros y tener valor histórico real (ej. cómo se resolvió una falla similar años atrás) | Un año captura estacionalidad real del dominio en mediciones (ciclos de producción, verano/invierno) y limita el volumen de la serie; pero aplicar el mismo criterio a órdenes/intervenciones tiraría información de bajo volumen y alto valor analítico (insumo directo de la búsqueda por similitud) | 12 |
| 12 | Volumen estimado: 2 plantas × **10 dispositivos por planta** = 20 dispositivos y 52 sensores, frecuencias de 10 a 60 s según tipo → ~161.000 lecturas/día, **del orden de 50-60 millones de filas/año** en mediciones | Justifica que particionamiento y vistas materializadas son necesarios de verdad, no un agregado cosmético | 12 |
| 13 | Particionamiento por rango mensual sobre `medicion`; índices BRIN sobre timestamp | BRIN es mucho más chico que B-tree para datos naturalmente ordenados por tiempo | 7, 12 |
| 14 | Datos de ejemplo: catálogo completo, población acotada a 4 tipos de dispositivo, 1-2 semanas de mediciones; volumen anual se documenta como proyección, no se carga completo | Evita generar millones de filas sin necesidad, mantiene el foco en la estimación razonada | 7, 12 |
| 15 | Entidades separadas en cadena: `medicion` → dispara → `evento` (por umbral) → dispara → `alerta` (con estado) → deriva en → `orden_trabajo` → implica → `intervencion` (texto libre + vector) | Evento depende de la medición concreta que lo dispara, no del sensor como fuente genérica. Un evento puede disparar varias alertas y una alerta puede derivar en varias órdenes de trabajo (1:N en ambos casos; ej. un mismo problema que requiere frentes de intervención distintos, eléctrico y mecánico). El responsable de una alerta se identifica indirectamente vía la intervención asociada, no como relación directa Usuario–Alerta | 3, 4 |
| 16 | Historización de `configuracion_dispositivo` con `valido_desde`/`valido_hasta` (no se pisa la config anterior) | Una alerta pasada debe interpretarse con el umbral vigente en ese momento, no con el actual | 4, 11 |
| 17 | Calidad del dato como generadora de eventos propios: una medición fuera de rango tras la validación, o la ausencia de reporte de un sensor (gap de conectividad), también dispara un evento de "calidad de dato", que puede derivar en una orden de trabajo apuntando a revisar el **sensor** (no el dispositivo) | Evita que un problema de instrumentación se confunda con una falla real del equipo, y aprovecha el mismo camino evento → alerta → orden de trabajo ya definido en la decisión 15, en vez de crear un mecanismo paralelo | 3, 4, 5, 10 |
| 18 | Tanto el payload crudo de bronce como la configuración de sensor se implementan como **JSONB** (no JSON) | JSONB permite indexar y consultar claves internas sin necesidad de parsear el documento completo cada vez; se prioriza sobre JSON salvo que se necesite preservar el documento exactamente como llegó (orden de claves, duplicados) | 7, 9 |
| 19 | Features precalculadas con **ventana de 24 h recalculada cada hora**, una fila por (dispositivo, ventana) | Una sola tabla alimenta entrenamiento y predicción, garantizando que las features se calculen de forma idéntica en ambos casos; ~175.000 filas/año contra ~59 M de mediciones | 4, 5, 7, 12 |
| 20 | **Horizonte de predicción de 72 h.** `fallo_en_horizonte` se almacena como columna, en `NULL` hasta que el horizonte transcurre y se puede verificar si hubo intervención correctiva | Divide la tabla en filas maduras (entrenables) y recientes (predecibles), que es lo que permite que una misma tabla sirva para ambos usos. Evita recalcular el cruce con `orden_trabajo`/`intervencion` y asegura un criterio de etiquetado único entre corridas | 4, 5 |
| 21 | Sistema planteado **en régimen**, con ~18 meses de operación previa: ya hay historia suficiente, modelos entrenados y ciclo de predicción activo | Evita modelar el arranque en frío (sin etiquetas no hay modelo, sin modelo no hay predicción), que es un problema operativo y no de diseño de base. Coherente con la retención de 1 año de la decisión 11 | 1, 4, 12 |
| 22 | **Predicción horaria** por dispositivo sobre la fila de features más reciente; trigger que crea una alerta cuando el score supera el umbral (0,7 inicial) | Integra la predicción al circuito operativo alerta → orden de trabajo de la decisión 15, en vez de dejarla como dato inerte. El trigger vive en oro y escribe en plata: cruza schemas, a considerar en permisos | 4, 7, 10, 11 |
| 23 | `alerta` con **doble origen** (evento o predicción): FKs nullable, campo `origen` y CHECK de origen único. Un mismo dispositivo puede tener varias alertas abiertas simultáneamente, incluso de orígenes distintos | Las dos vías de detección son independientes (valor instantáneo vs. tendencia de 24 h) y su coincidencia es confirmación cruzada, no duplicación. Agrega la relación 16 al modelo conceptual | 3, 4, 8 |
| 24 | **Una tabla de features por tipo de dispositivo** (`feature_motor_ventana` y análogas), no una tabla única. Implica un modelo entrenado por tipo de dispositivo | Las variables medidas no son comparables entre tipos; una tabla única dejaría la mayoría de columnas en `NULL` y un nulo en una feature no es neutro para un modelo. Efecto: el enlace `prediccion` → features queda documentado sin FK, porque la tabla destino varía según el tipo | 4, 7, 9 |
| 25 | `evento` **sin FK hacia `medicion`**, con copia de `valor_medido` y `umbral_vigente` | Permite purgar mediciones al año sin perder eventos ni su interpretabilidad (se sabría que hubo superación de umbral pero no de cuánto ni contra qué límite). Los valores son inmutables una vez ocurrido el hecho, con lo cual no hay riesgo de inconsistencia | 4, 5, 12 |
| 26 | `id_dispositivo` **redundante** en `alerta` | El camino hasta el dispositivo se bifurca según el origen (`alerta`→`evento`→`sensor`→`dispositivo` o `alerta`→`prediccion`→`dispositivo`). Como RLS se evalúa fila por fila en toda consulta, sin la columna ese recorrido condicional se repetiría en cada evaluación | 4, 5, 11 |
| 27 | El **límite base / aplicación** se documenta como sección canónica en la actividad 10, con menciones breves donde el tema aparece (actividades 4 y 7) | Criterio unificador de las decisiones 5, 6 y 22: la base registra hechos, la aplicación gobierna procesos con estado | 4, 7, 10 |
| 28 | `intervencion.embedding` declarado como `vector(384)`, dimensión **preliminar** sujeta a confirmación al elegir el modelo de embeddings | 384 corresponde a modelos livianos multilingües tipo `all-MiniLM-L6-v2`. Si se opta por otro modelo la dimensión cambia, pero es una modificación acotada de una línea del esquema | 4, 9 |
| 29 | Scripts SQL organizados en `db/` (subcarpetas `estructura`, `datos`, `indices_vistas`, `consultas`) con numeración global 00–18 como orden de ejecución; script maestro `db/run_all.sql` y `docker-compose.yml` (imagen `pgvector/pgvector:pg16`) | Permite reconstruir la base entera en orden con un solo comando y que el profe la ejecute sin instalar nada | 7 |
| 30 | Dos triggers implementados (medición→evento y predicción→alerta predictiva); las alertas por umbral las crea la aplicación agrupando eventos, no un trigger | Coherente con la decisión 6: la base registra hechos, la app gobierna procesos. Un episodio anómalo genera muchos eventos pero una sola alerta, y esa agrupación es lógica de aplicación | 7, 10 |
| 31 | Embeddings cargados como vectores de ejemplo (no se integra el modelo real al repo); el esquema, el índice HNSW y la consulta de similitud quedan operativos | El foco del TP es cómo se estructura y consulta el dato vectorial, no la calidad del modelo. Calcular embeddings reales requiere un servicio externo, innecesario para demostrar el mecanismo | 9 |
| 32 | Ocultamiento de `id_usuario` al científico de datos vía **vista de oro** sin la columna; column-level `GRANT` queda documentado como alternativa | La vista es más simple y explícita (el rol no tiene por dónde acceder a la columna); el GRANT es más granular pero más frágil ante nuevas columnas | 11 |

---

## 4. Modelo conceptual (bloques principales)

1. **Activos**: `ubicacion` (autoreferencial: planta → área → línea) → `dispositivo` → `sensor`; `configuracion_dispositivo` (historizada, colgando de `dispositivo`).
2. **Telemetría**: `medicion` → `evento` → `alerta`.
3. **Gestión**: `usuario`, `orden_trabajo`, `intervencion` (con `observaciones text` + `embedding vector`).
4. **Analítico**: `modelo`, `corrida_entrenamiento`, `metrica`, `prediccion`, features precalculadas por ventana.
5. **Catálogos**: `tipo_dispositivo`, `tipo_variable`, `unidad`.

Notas de cardinalidad: un sensor mide una sola variable; PK de `medicion` es compuesta `(sensor_id, timestamp)`; `evento` depende de `medicion` (no del sensor directamente); `evento` → `alerta` y `alerta` → `orden_trabajo` son ambas 1:N (un evento puede disparar varias alertas; una alerta puede derivar en varias órdenes de trabajo); `prediccion` → `alerta` es 1:N (una predicción que supera el umbral genera una alerta de origen predictivo); `medicion` → `corrida_entrenamiento` y `medicion` → `prediccion` son N:M, y se resuelven **por comprensión** (rango temporal y criterio de selección) en vez de con tablas puente.

Modelo conceptual completo, con diagrama, atributos, las 16 relaciones y las restricciones del dominio, en `docs/Informe/Informe_03_ModeloConceptual.md` (+ `docs/modelo_conceptual.png`).

---

## 5. Arquitectura de datos (flujo)

```
Sensores → Ingesta → [bronze: crudo] → Validación/tipado → [silver: RLS activo] 
→ Transformación/agregación → [gold: agregados, features] → Consumidores
(app operativa, tablero de supervisión, análisis del científico de datos, 
servicio de predicción que escribe de vuelta en gold)
```

Encuadre: **lakehouse lógico dentro de un único PostgreSQL** (schemas, no sistemas separados). Corresponde a la arquitectura Medallion vista en Clase 5.

---

## 6. Pasada por las 12 actividades — estado

| # | Actividad | Estado | Notas |
|---|---|---|---|
| 1 | Análisis del caso de uso | **Resuelto** | Informe redactado (`docs/Informe/Informe_01_AnalisisCasoUso.md`); dudas de la sesión resueltas o derivadas a las secciones correspondientes (ver decisiones 3, 11, 17) |
| 2 | Relevamiento y clasificación de datos | **Resuelto** | Informe redactado (`docs/Informe/Informe_02_RelevamientoDatos.md`), con ejemplos preliminares mínimos por categoría. Se ampliará con más detalle y coherencia entre entidades en las actividades 4, 7 y 8 |
| 3 | Modelo conceptual | **Resuelto** | Informe redactado (`docs/Informe/Informe_03_ModeloConceptual.md`) y diagrama formal completo (`docs/modelo_conceptual.png`, con fuente editable). 14 entidades, **16 relaciones** con cardinalidades y restricciones del dominio |
| 4 | Modelo lógico relacional | **Resuelto** | Informe redactado (`docs/Informe/Informe_04_ModeloLogico.md`). **22 tablas**: bronce 2, plata 13, oro 7, más 3 tablas de features declaradas como análogas. Diagrama en `docs/modelo_logico.png`, acceso directo `docs/modelo_logico_interactivo` y código fuente en `anexos/modelo_logico_interactivo.md` |
| 5 | Normalización y desnormalización | **Resuelto** | Informe redactado (`docs/Informe/Informe_05_Normalizacion.md`). Cubre el criterio por patrón de acceso, la normalización de plata, qué está desnormalizado en oro, las excepciones deliberadas, las N:M por comprensión y los cuatro tipos de consumo |
| 6 | Selección tecnológica | **Resuelto** | Informe redactado (`docs/Informe/Informe_06_SeleccionTecnologica.md`); desarrolla la decisión 7 |
| 7 | Modelo físico e implementación mínima | **Resuelto** | Informe redactado (`docs/Informe/Informe_07_ModeloFisicoImplementacion.md`). DDL completo de las 22 tablas + particiones + índices + triggers en `db/` (scripts 00–18), carga de ejemplo probada de punta a punta sobre PostgreSQL 16 + pgvector. `docker-compose.yml` y `db/run_all.sql` para levantar todo con un solo comando |
| 8 | Consultas representativas | **Resuelto** | Informe redactado (`docs/Informe/Informe_08_ConsultasRepresentativas.md`). Las 6 consultas en SQL (`db/consultas/20–25`) más una 7ª sobre JSONB (`26`), probadas. EXPLAIN de plata vs oro con volumen real (~1 M mediciones) |
| 9 | Semiestructurados/no estructurados/vectorial | **Resuelto** | Informe redactado (`docs/Informe/Informe_09_BusquedaVectorial.md`) + `nosql/modelo_nosql.md` y `vectorial/modelo_vectorial.md`. Embeddings de ejemplo (`db/datos/30`), índice HNSW (`db/indices_vistas/31`) y consulta de similitud (`db/consultas/32`). Opción conceptual (sin modelo real) |
| 10 | Arquitectura de datos | **Resuelto** | Informe redactado (`docs/Informe/Informe_10_ArquitecturaDatos.md`) con diagrama Mermaid del flujo por capas; fuente en `docs/arquitectura_datos.mmd` |
| 11 | Seguridad, permisos, aislamiento | **Resuelto** | Informe redactado (`docs/Informe/Informe_11_SeguridadPermisosAislamiento.md`). DDL de roles, RLS por planta sobre `alerta` e `intervencion`, y ocultamiento de `id_usuario` con vista de oro (+ column-level `GRANT` documentado) en `db/estructura/40_seguridad_rls.sql`. Aislamiento verificado |
| 12 | Escalabilidad y rendimiento | **Resuelto** | Informe redactado (`docs/Informe/Informe_12_EscalabilidadRendimiento.md`); apoya particionado, BRIN, retención diferenciada y precálculo de oro en el EXPLAIN de la actividad 8 |

### Clasificación de datos (actividad 2)

| Tipo | Ejemplos | Capa (Medallion) |
|---|---|---|
| Estructurados | dispositivos, sensores, ubicaciones, mediciones, alertas, órdenes de trabajo | plata / oro |
| Semiestructurados | payload crudo de ingesta (JSONB), configuración de sensor (JSONB: umbrales, calibración) | bronce / plata |
| No estructurados | observaciones de texto libre cargadas por el técnico en cada intervención | plata |
| Operacionales | alertas abiertas o en revisión, órdenes de trabajo en curso | plata |
| Analíticos | features calculadas por ventana, predicciones de falla, métricas de modelos | oro |
| Sensibles | datos personales de usuarios y técnicos (nombre, email, etc. asociados a una intervención) | plata |
| Auditoría / trazabilidad | log de cambios de estado de alertas, histórico de configuración de dispositivo | plata |

Ejemplos completos por categoría (JSON, tablas de muestra) en `docs/informe/02_relevamiento_datos.md`.

### Consultas representativas identificadas (actividad 8)

1. Última lectura de cada sensor de un dispositivo (`DISTINCT ON`).
2. Alertas abiertas por planta, con severidad y antigüedad (muestra RLS en acción).
3. Promedio/máximo de vibración por dispositivo/día en un rango (agregación).
4. Media móvil de 7 días sobre una variable (función de ventana — pedido explícito de la consigna).
5. Ranking de dispositivos por cantidad de intervenciones correctivas (subconsulta).
6. Comparación con `EXPLAIN` entre consultar plata directo vs. la vista materializada de oro (justifica la optimización).

---

## 7. Relación con el contenido de la materia

Clases 1 a 5 ya vistas y revisadas (imágenes/PDFs de la cátedra en el proyecto). Puntos clave que respaldan decisiones ya tomadas:

- **Clase 3**: JSONB, funciones de ventana, índices, `EXPLAIN ANALYZE` → usados en decisiones 1, 13 y en la actividad 8.
- **Clase 4**: mapa de decisión NoSQL → usado para justificar por qué no se eligió NoSQL (decisión 7).
- **Clase 5**: arquitectura Medallion, Data Lake/Warehouse/Lakehouse → es literalmente la base de la decisión 2 y la sección 5 de este documento.

Pendientes de la materia que pueden ajustar terminología (no la sustancia) de decisiones ya tomadas:
- **Clase 6** (bases vectoriales y escalabilidad): puede afinar cómo se presenta pgvector y el particionamiento.
- **Clase 7** (seguridad aplicada a IA): puede afinar cómo se presenta RLS y el riesgo de exposición vía IA.
- **Clase 8**: caso integrador.

---

## 8. Metodología de trabajo (equipo + Claude)

- Cuentas de Claude **separadas** (sin plan compartido). Este documento es la fuente de verdad que reemplaza la memoria de Claude entre integrantes.
- Un chat de Claude por sección del informe, nombrado igual que el archivo Markdown correspondiente (ej. chat `informe_01_AnalisisCasoUso` ↔ archivo `docs/informe/01_analisis_caso_uso.md`).
- Al cerrar cada sesión: actualizar este documento (nueva fila en la bitácora si hubo una decisión, marcar actividad como resuelta) y commitear.
- Antes de empezar a trabajar: `git pull` siempre primero.
- Informe en Markdown dividido por sección (`docs/informe/NN_seccion.md`), conversión a PDF con Pandoc **solo al final**.
- Commits frecuentes y descriptivos, por archivo específico (no `git add .` salvo el commit inicial de estructura). Verificar que `user.email` de Git coincida con la cuenta de GitHub de cada uno.
- Conflictos de Git esperables solo en este documento de contexto (es el único archivo que ambos tocan seguido); se minimizan agregando filas al final de las tablas en vez de editar líneas existentes, y se resuelven fácilmente si aparecen (no son destructivos).
- Modelo lógico: se diagrama en **dbdiagram.io con DBML**. Se versionan tres archivos: el `.png` exportado, el acceso directo a la vista interactiva (`docs/modelo_logico_interactivo`) y el código fuente del diagrama (`anexos/modelo_logico_interactivo.md`).
- Diagramas: se versiona siempre la fuente editable junto al `.png` exportado, para que cualquiera del equipo pueda modificarlos después. Mermaid queda como opción cuando el diagrama sea simple (versionable en texto plano, se renderiza solo en GitHub); para diagramas con mucho cruce de relaciones se usa herramienta gráfica y se adjunta la imagen.

---

## 9. Pendientes abiertos

Las 12 actividades están resueltas. Quedan cuestiones menores y opcionales:

- Confirmar la dimensión del vector de `intervencion.embedding` si se elige un modelo de embeddings real distinto de 384 (hoy se usan embeddings de ejemplo; ver decisiones 28 y 31).
- Opcional: calcular embeddings reales con un modelo (`all-MiniLM-L6-v2`) en lugar de los de ejemplo, si se quiere que la búsqueda por similitud sea semántica de verdad.
- Confirmar terminología una vez vistas las Clases 6 a 8 (no cambia la sustancia).
- Conversión final del informe completo a PDF con Pandoc.
- Decidir si este documento de contexto se versiona en el repo Git o queda solo como insumo de Claude Project Knowledge.

---

*Última actualización: sesión del 24/08 (cierre de Actividades 8 a 12 — Consultas, Vectorial, Arquitectura, Seguridad/RLS y Escalabilidad). Las 12 actividades quedan resueltas; próximo paso: repaso final y conversión a PDF con Pandoc.*
