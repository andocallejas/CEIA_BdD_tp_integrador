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

El catálogo de tipos de dispositivo puede listar más tipos (para mostrar generalidad del modelo), pero los datos de ejemplo se cargan solo para estos 4. Debe haber más de una instancia de cada tipo por planta (ej. 2-3 motores), para que consultas de ranking/comparación no sean triviales.

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
| 6 | Gestión de alertas (agrupar eventos, asignar, escalar) vive en la aplicación, no en la base | Es lógica de negocio con estado; un trigger no es el lugar apropiado | 10 |
| 7 | Motor único: **PostgreSQL** (con extensión pgvector) | Cubre series temporales (particionamiento), semiestructurado (JSONB), seguridad por fila (RLS) y vectorial, todo en un sistema. Alternativas evaluadas y descartadas: TimescaleDB/InfluxDB (buenas para la serie, débiles para el resto del dominio), MongoDB (pierde integridad referencial y RLS), vectorial dedicado tipo Pinecone (innecesario para el volumen de texto del caso) | 6 |
| 8 | Normalización diferenciada por capa: plata en 3FN, oro deliberadamente desnormalizada (ancha, con agregados) | Cada capa optimiza para un patrón de acceso distinto: integridad de escritura vs. velocidad de lectura | 5 |
| 9 | Búsqueda vectorial (pgvector) acotada **solo** a `intervencion.observaciones` (texto libre del técnico) | Caso de uso genuino: recuperar intervenciones pasadas con síntomas parecidos, descriptos en lenguaje natural. Independiente del análisis predictivo numérico (que consume series, no texto). Se descartó vectorizar la señal de vibración por ser mucho más compleja de justificar/implementar en el alcance del TP | 9 |
| 10 | Riesgo de seguridad a documentar explícitamente: la búsqueda por similitud debe respetar RLS — no puede devolver intervenciones de una planta a la que el usuario no tiene acceso | Es el ángulo de "riesgo de exposición vía IA" que pide el enunciado | 9, 11 |
| 11 | Retención diferenciada por entidad: **mediciones** con 1 año de detalle en plata (agregados horarios/diarios conservados más tiempo en oro); **órdenes de trabajo e intervenciones** conservadas por un período bastante más extenso (potencialmente indefinido), al ser muchos menos registros y tener valor histórico real (ej. cómo se resolvió una falla similar años atrás) | Un año captura estacionalidad real del dominio en mediciones (ciclos de producción, verano/invierno) y limita el volumen de la serie; pero aplicar el mismo criterio a órdenes/intervenciones tiraría información de bajo volumen y alto valor analítico (insumo directo de la búsqueda por similitud) | 12 |
| 12 | Volumen estimado: ~2 plantas × ~10 dispositivos × ~50 sensores, frecuencia promedio ~30s → **~50 millones de filas/año** en mediciones | Justifica que particionamiento y vistas materializadas son necesarios de verdad, no un agregado cosmético | 12 |
| 13 | Particionamiento por rango mensual sobre `medicion`; índices BRIN sobre timestamp | BRIN es mucho más chico que B-tree para datos naturalmente ordenados por tiempo | 7, 12 |
| 14 | Datos de ejemplo: catálogo completo, población acotada a 4 tipos de dispositivo, 1-2 semanas de mediciones; volumen anual se documenta como proyección, no se carga completo | Evita generar millones de filas sin necesidad, mantiene el foco en la estimación razonada | 7, 12 |
| 15 | Entidades separadas: `evento` (detectado por umbral) → puede generar → `alerta` (con estado y responsable) → puede originar → `orden_mantenimiento`/`intervencion` (texto libre + posible vector) | Un evento puede no generar alerta; una alerta puede agrupar varios eventos; separar da flexibilidad real del dominio | 3, 4 |
| 16 | Historización de `configuracion_dispositivo` con `valido_desde`/`valido_hasta` (no se pisa la config anterior) | Una alerta pasada debe interpretarse con el umbral vigente en ese momento, no con el actual | 4, 11 |
| 17 | Calidad del dato como generadora de eventos propios: una medición fuera de rango tras la validación, o la ausencia de reporte de un sensor (gap de conectividad), también dispara un evento de "calidad de dato", que puede derivar en una orden de trabajo apuntando a revisar el **sensor** (no el dispositivo) | Evita que un problema de instrumentación se confunda con una falla real del equipo, y aprovecha el mismo camino evento → alerta → orden de trabajo ya definido en la decisión 15, en vez de crear un mecanismo paralelo | 3, 4, 5, 10 |

---

## 4. Modelo conceptual (bloques principales)

1. **Activos**: `ubicacion` (autoreferencial: planta → área → línea) → `dispositivo` → `sensor`.
2. **Telemetría**: `medicion`, `evento`, `alerta`.
3. **Gestión**: `usuario`, `orden_trabajo`, `intervencion` (con `observaciones text` + `embedding vector`), `configuracion_dispositivo` (historizada).
4. **Analítico**: `modelo`, `corrida_entrenamiento`, `metrica`, `prediccion`, features precalculadas por ventana.
5. **Catálogos**: `tipo_dispositivo`, `tipo_variable`, `unidad`.

Notas de cardinalidad: un sensor mide una sola variable; PK de `medicion` es compuesta `(sensor_id, timestamp)`; N:M entre `orden_trabajo` y `alerta` (una orden puede cerrar varias alertas).

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
| 1 | Análisis del caso de uso | **Resuelto** | Informe redactado (`docs/informe/01_analisis_caso_uso.md`); dudas de la sesión resueltas o derivadas a las secciones correspondientes (ver decisiones 3, 11, 17) |
| 2 | Relevamiento y clasificación de datos | Resuelto conceptualmente | Ver tabla de clasificación abajo |
| 3 | Modelo conceptual | Resuelto conceptualmente | Falta diagrama formal (DER) |
| 4 | Modelo lógico relacional | Resuelto conceptualmente | Falta tablero completo de tablas/PK/FK |
| 5 | Normalización y desnormalización | Resuelto (decisión 8) | |
| 6 | Selección tecnológica | Resuelto (decisión 7) | |
| 7 | Modelo físico e implementación mínima | Pendiente | DDL real, carga de ejemplo |
| 8 | Consultas representativas | Pendiente | 6 consultas ya identificadas (ver abajo), falta escribir el SQL |
| 9 | Semiestructurados/no estructurados/vectorial | Resuelto conceptualmente (decisiones 9-10) | Falta implementación |
| 10 | Arquitectura de datos | Resuelto conceptualmente | Falta diagrama formal |
| 11 | Seguridad, permisos, aislamiento | Resuelto conceptualmente (decisiones 3-4, 16) | Falta DDL de roles/políticas, y definir mecanismo de ocultamiento de columnas para el científico de datos (vista de oro sin la columna vs. column-level `GRANT`) |
| 12 | Escalabilidad y rendimiento | Resuelto conceptualmente (decisiones 11-13) | |

### Clasificación de datos (actividad 2)

| Tipo | Ejemplos |
|---|---|
| Estructurados | mediciones, dispositivos, sensores, ubicaciones, alertas |
| Semiestructurados | configuración de sensor (JSONB: umbrales, calibración), payload crudo en bronce |
| No estructurados | observaciones de texto libre en intervenciones |
| Operacionales | plata: lecturas recientes, alertas abiertas, órdenes en curso |
| Analíticos | oro: features por ventana, KPIs, predicciones |
| Sensibles | datos personales de usuarios/técnicos |
| Auditoría | log de accesos, historial de configuración, cambios de estado de alertas |

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
- Diagramas en Mermaid cuando sea posible (versionable, se renderiza en GitHub).

---

## 9. Pendientes abiertos

- Definir el mecanismo exacto de agrupamiento de alertas (evitar reabrir/duplicar alerta por el mismo evento sostenido en el tiempo).
- Definir el mecanismo de ocultamiento de columnas sensibles para el científico de datos: vista de oro sin la columna vs. column-level `GRANT` (ver decisión 3 y actividad 11).
- Confirmar terminología una vez vistas las Clases 6 y 7.
- Escribir el DDL real (actividad 7).
- Escribir el SQL de las 6 consultas (actividad 8).
- Diagramas formales: DER (actividad 3) y arquitectura (actividad 10).
- Decidir si este documento de contexto se versiona en el repo Git o queda solo como insumo de Claude Project Knowledge.

---

*Última actualización: sesión del 11/08 (cierre de Actividad 1 — Análisis del caso de uso). Próximo paso: Actividad 2 (Relevamiento y clasificación de datos) o Actividad 3 (Modelo conceptual), según orden de trabajo del equipo.*
