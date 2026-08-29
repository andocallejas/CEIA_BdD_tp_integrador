# Datos semiestructurados (JSONB)

El caso no usa una base NoSQL separada: lo semiestructurado se resuelve dentro de PostgreSQL con el tipo **JSONB**, coherente con la decisión de motor único (Actividad 6).

## Dónde aparece

| Uso | Tabla / campo | Capa |
|---|---|---|
| Payload crudo de ingesta de mediciones | `bronce.medicion_cruda.payload` | bronce |
| Payload crudo de configuración de sensores | `bronce.configuracion_cruda.payload` | bronce |
| Umbrales y parámetros de operación por dispositivo | `plata.configuracion_dispositivo.parametros` | plata |
| Criterio de selección e hiperparámetros de entrenamiento | `oro.corrida_entrenamiento.criterio_seleccion`, `hiperparametros` | oro |

## Por qué JSONB y no JSON

`JSONB` guarda el documento en forma binaria indexable: permite leer e indexar claves internas sin re-parsear el texto completo en cada consulta. Se prioriza sobre `JSON`, que solo conviene cuando hay que preservar el documento exactamente como llegó (orden de claves, duplicados).

## Por qué semiestructurado y no columnas

- En **bronce** el dato llega tal cual, sin esquema garantizado; un documento flexible es lo único que tolera entradas incompletas o con formato variable.
- En **configuración**, cada tipo de equipo tiene distintos umbrales (un motor mide vibración/temperatura/corriente; un tablero, consumo/tensión). Un JSONB evita tener columnas distintas por tipo o una tabla de umbrales por variable, manteniendo el esquema estable ante nuevos tipos.

## Cómo se consulta

Los operadores `->` (devuelve JSON) y `->>` (devuelve texto) leen dentro del documento, y `jsonb_each` expande sus claves a filas. La consulta 7 (`db/consultas/26_consulta_7_umbrales_jsonb.sql`) muestra la extracción de los umbrales vigentes por dispositivo. También se puede indexar con GIN sobre el JSONB si el volumen de consultas por clave lo justificara.
