# 12. Escalabilidad y rendimiento

## 12.1 El problema de escala

El volumen lo domina la telemetría: 2 plantas × 10 dispositivos × 52 sensores en total, con frecuencias de 10 a 60 s, dan unas 161.000 lecturas por día, **del orden de 59 millones de filas al año** en `medicion`. El resto de las entidades (eventos, alertas, órdenes, intervenciones) son varios órdenes de magnitud menores. Todo el diseño de rendimiento apunta a que ese volumen de mediciones no degrade el sistema.

## 12.2 Particionamiento

`plata.medicion` está **particionada por rango mensual** sobre `timestamp_medicion`. Dos beneficios concretos:

- **Consultas por tiempo:** una consulta acotada a un rango de fechas lee solo las particiones involucradas (poda de particiones), no la tabla entera. En el plan de la consulta 6 (Actividad 8) se ve cómo los meses sin datos se descartan al instante.
- **Retención:** purgar el detalle vencido es descartar particiones enteras (`DROP TABLE` de la partición del mes), operación casi instantánea, en lugar de un `DELETE` masivo que reescribiría índices y generaría trabajo de vacío.

## 12.3 Índices

- **BRIN** sobre `medicion(timestamp_medicion)`: para datos naturalmente ordenados por tiempo, un BRIN es muchísimo más chico que un B-tree y suficiente para acotar rangos.
- **B-tree** sobre `alerta(id_dispositivo, estado)` y `evento(id_sensor, timestamp_medicion)` para las consultas operativas.
- Índice **parcial** sobre las features etiquetadas (`fallo_en_horizonte IS NOT NULL`), que aísla las filas de entrenamiento.
- **HNSW** sobre `intervencion.embedding` para la búsqueda vectorial.

## 12.4 Retención diferenciada

No todo se conserva igual, según volumen y valor:

| Entidad | Retención | Motivo |
|---|---|---|
| `medicion` (detalle) | ~1 año en plata | Un año captura la estacionalidad del dominio; el detalle completo es inviable de sostener indefinidamente |
| Agregados de oro | varios años | Bajo volumen; permiten análisis interanual sin la serie completa |
| Eventos, alertas, órdenes, intervenciones | período extenso / indefinido | Pocos registros y alto valor histórico (insumo de la búsqueda por similitud) |

Que `evento` no tenga FK hacia `medicion` (y copie `valor_medido`/`umbral_vigente`) es lo que permite purgar mediciones sin perder los eventos ni su interpretabilidad.

## 12.5 Precálculo analítico

Las tablas de oro (agregados y features) son **datos derivados precalculados**: evitan recorrer millones de mediciones en cada consulta analítica. La Actividad 8 lo mide: obtener el promedio diario de un sensor desde el agregado de oro fue unos dos órdenes de magnitud más rápido que calcularlo sobre la serie cruda de plata (~0,09 ms contra ~12 ms sobre ~1 millón de filas), y la diferencia crece con el volumen. Las features se calculan una vez por ventana y alimentan tanto el entrenamiento como la predicción, con ~175.000 filas al año frente a los ~59 millones de mediciones.

## 12.6 Síntesis

Particionamiento + BRIN para la serie, precálculo en oro para la analítica, índices acordes a cada patrón de consulta y retención diferenciada por entidad. En conjunto, permiten que el sistema sostenga el volumen anual proyectado sin que las consultas se degraden a medida que crece la historia.
