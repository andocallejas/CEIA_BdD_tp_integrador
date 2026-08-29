# Búsqueda vectorial (pgvector)

## Caso de uso

Recuperar intervenciones pasadas con **síntomas parecidos** a uno nuevo, descriptos en lenguaje natural por el técnico. La búsqueda por palabras no sirve: dos textos pueden describir el mismo problema sin compartir vocabulario. Se resuelve con **embeddings** (representación vectorial del significado) y búsqueda por cercanía.

## Alcance

Acotada solo a `plata.intervencion.observaciones` (texto libre). Es independiente del análisis predictivo numérico, que consume series, no texto. Se descartó vectorizar la señal de vibración por complejidad fuera del alcance del TP.

## Implementación

- **Campo:** `plata.intervencion.embedding vector(384)`.
- **Modelo:** dimensión 384, típica de un modelo liviano multilingüe como `all-MiniLM-L6-v2`. Si se cambia el modelo, cambia la dimensión (una línea del esquema).
- **Cálculo:** en producción, un servicio externo calcula el embedding de cada observación al registrarse (las observaciones son inmutables, así que no se desactualiza). En este TP se cargan **embeddings de ejemplo** (vectores aleatorios, `db/datos/30_embeddings_intervencion.sql`) para dejar el esquema y la búsqueda operativos sin depender del modelo.
- **Índice:** HNSW con distancia coseno (`db/indices_vistas/31_indice_vectorial.sql`), para el vecino más cercano rápido.
- **Consulta:** operador `<=>` (distancia coseno) ordenando por cercanía (`db/consultas/32_consulta_8_busqueda_similitud.sql`).

## Riesgo de exposición vía IA

La búsqueda por similitud **debe respetar el aislamiento**: no puede devolver intervenciones de una planta a la que el usuario no tiene acceso. Se garantiza aplicando RLS también sobre `intervencion` (Actividad 11), de modo que el vecino más cercano se busca únicamente entre las filas visibles para el usuario.
