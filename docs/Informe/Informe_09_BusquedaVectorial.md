# 9. Datos semiestructurados, no estructurados y búsqueda vectorial

## 9.1 Descripción general

La actividad cubre los tres tipos de dato no puramente tabulares del caso: los **semiestructurados** (JSON), los **no estructurados** (texto libre) y la **búsqueda vectorial** sobre ese texto. Los tres se resuelven dentro de PostgreSQL, sin sumar un motor aparte, coherente con la selección tecnológica de la Actividad 6.

## 9.2 Datos semiestructurados (JSONB)

Lo semiestructurado se maneja con el tipo `JSONB`: payloads crudos en bronce, umbrales de operación en `plata.configuracion_dispositivo.parametros`, y criterios/hiperparámetros de entrenamiento en oro. Se elige `JSONB` sobre `JSON` porque guarda el documento en forma binaria indexable y permite leer claves internas sin re-parsear el texto. El detalle está en `nosql/modelo_nosql.md`; la consulta 7 (`db/consultas/26_consulta_7_umbrales_jsonb.sql`) muestra cómo se extraen los umbrales vigentes de cada dispositivo con `jsonb_each` y `->>`.

## 9.3 Datos no estructurados y búsqueda vectorial

El dato no estructurado es la observación de texto libre que deja el técnico en cada intervención. El objetivo es poder recuperar intervenciones pasadas con **síntomas parecidos**, descriptos en lenguaje natural. La búsqueda por palabras no alcanza: dos textos pueden describir el mismo problema sin compartir vocabulario.

La solución es la **búsqueda vectorial** con la extensión **pgvector**:

- Cada observación se convierte en un *embedding*: un vector que representa su significado. Textos con significado parecido dan vectores cercanos, aunque usen palabras distintas.
- El embedding se guarda en `plata.intervencion.embedding`, de tipo `vector(384)`. La dimensión 384 corresponde a un modelo liviano multilingüe (`all-MiniLM-L6-v2`); cambiar de modelo cambia solo esa dimensión.
- La búsqueda es un "vecino más cercano": se ordena por distancia coseno (operador `<=>`) y se toman los primeros. Un índice **HNSW** (`db/indices_vistas/31_indice_vectorial.sql`) lo hace rápido a escala.

### Alcance de la implementación

En este trabajo los embeddings se cargan como **vectores de ejemplo** (`db/datos/30_embeddings_intervencion.sql`), lo que deja el esquema, el índice y la consulta de similitud (`db/consultas/32_consulta_8_busqueda_similitud.sql`) plenamente operativos. En producción, un servicio externo calcularía el embedding real de cada observación al registrarla; como las observaciones son inmutables, el vector no se desactualiza. El foco del TP es cómo se estructura y se consulta el dato vectorial, no la calidad semántica del modelo de embeddings.

## 9.4 Riesgo de exposición vía IA

El punto sensible que pide la consigna: la búsqueda por similitud **debe respetar el aislamiento**. No puede devolver una intervención de una planta a la que el usuario no tiene acceso, aunque sea la más parecida. Se garantiza aplicando RLS también sobre `intervencion` (Actividad 11): el vecino más cercano se busca únicamente entre las filas visibles para el usuario. Sin esa precaución, la capa de IA se convertiría en una vía de fuga de datos entre plantas.
