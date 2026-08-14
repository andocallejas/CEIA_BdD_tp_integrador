# 5. Normalización, desnormalización y decisiones de diseño

## 5.1 Criterio general

El nivel de normalización no es el mismo para todo el modelo. Como criterio general adoptado: **se normaliza donde se escribe, y se desnormaliza lo que es derivado y voluminoso**.

Se normaliza para eliminar redundancias (mismo dato repetido en varias filas de distintas tablas) cuando son tablas en las que se escribe recurrentemente por diseño porque es en esos casos es cuando la redundancia presenta peligro. Si dicho valor repetido comienza a actualizarse en todas las filas y tablas, y hay un fallo que deja algunas filas actualizadas y otras no, la base queda en estado contradictorio y puede ser complejo reconocer el valor correcto y recuperarlo correctamente.

Por eso la capa plata, que recibe constantemente inserciones y modificaciones desde la operación, está de manera general normalizada en 3FN. 

Por otro lado, las tablas agregadas (analíticas) y las features (para predicción) de la capa oro se desnormalizan: son datos calculados a partir de plata, nadie los edita a mano, y si se pierden se recalculan (a diferencia de la complejidad de restaurar un valor parcialmente actualizado en la capa de plata).

La capa oro, sin embargo, contiene dos bloques desnormalizados y uno normalizado:

| Bloque | Contenido | Estructura |
|---|---|---|
| Agregados | `agregado_horario`, `agregado_diario` | Desnormalizada |
| Features | `feature_motor_ventana` y análogas | Desnormalizada |
| Trazabilidad | `modelo`, `corrida_entrenamiento`, `metrica`, `prediccion` | Normalizada |

Los dos primeros son datos derivados de `medicion` y de gran volumen, con lo cual se aplica el criterio de desnormalización (ya que el gran volumen invita a evitar JOINs a causa de la normalización que terminan siendo "caros"). El bloque de trazabilidad no implica campos calculados ni gran volumen: no se deriva de ninguna otra tabla, se escribe directamente (cada entrenamiento inserta una corrida, cada hora se inserta una predicción). Ninguno de los dos motivos para desnormalizar aplica, y por eso se mantiene normalizado.

La capa bronce, por otro lado, no le aplica nada de esto, ya que como está planteada, en bronce el dato se almacena como jsonb sin esquema declarado, con lo cual no hay dependencias para evaluar. La capa simplemente existe para poder recibir el dato tal como llega, incluso cuando pudiera no cumplir alguna reglas del dominio.

---

## 5.2 Normalización en la capa plata

Todas las tablas de plata están en 3FN. El criterio se aplicó de manera general, verificando en cada tabla que todos sus atributos dependan de la clave primaria y no de otro atributo no clave.

Un caso que ejemplifica claramente esto es el de la unidad de medida. En el modelo conceptual, la entidad `sensor` incluía los atributos `tipo_variable` y `unidad`. Pero si eso se llevara a tabla así como está, se incumpliría la tercera forma normal, porque en realidad la unidad no depende del sensor sino del tipo de variable: toda medición de temperatura se expresa en la misma unidad, sea cual sea el sensor que la tome.

En el modelo lógico la unidad se separa y pasa al catálogo `tipo_variable`. Así se evitan problemas de redundancia con los riesgos de anomalías en actualizaciones, inserciones, etc.


---

## 5.3 Normalización y desnormalizado en la capa oro

En los agregados y las features aplicamos desnormalización ya que se almacena un cálculo en lugar de calcularlo a demanda en la consulta. `agregado_diario.promedio` no es un hecho sino una agregación tipo `AVG()` sobre `medicion`. 

Esto muestra que no se cumple la dependencia funcional mencionada en el punto anterior que exige la 3FN. El valor de `promedio` no depende estrictamente de la clave `(id_sensor, dia)`, sino de las aproximadamente 2.880 mediciones de ese día. La clave etiqueta el valor pero no lo determina, depende de otra cosa.

De alguna manera el mismo dato existe dos veces y en dos formas distintas (una especie de redundancia). Las mediciones de un día están completas en `medicion` y resumidas en una fila de `agregado_diario`. Pero no presenta el riesgo de redundancia de la capa plata. Si por algo el cálculo de la fila agregada fallara, se vuelve a calcular a partir de plata, que tiene integridad asegurada.

Las features agregan la desnormalización típica necesaria para ML: el formato ancho. Mientras `medicion` guarda una fila por lectura sin importar qué variable sea, `feature_motor_ventana` tiene `vib_media`, `temp_media` y `corr_media` como columnas separadas. La variable dejó de ser un dato para pasar a ser parte de la estructura, y por eso incorporar un sensor nuevo a un motor obliga a agregar columnas, cosa que en `medicion` no pasa.

En ambos casos se asume que los datos quedan desactualizados hasta el siguiente recálculo. Pero como ventaja, las consultas analíticas no tienen que recorrer millones de filas.

---

## 5.4 Excepciones de Desnormalizaciones en plata

Hay tres casos que se apartan de la 3FN en esta capa a propósito.

`evento` copia `valor_medido` y `umbral_vigente`, que en realidad ya están en `medicion` y en `configuracion_dispositivo`. Esto porque las mediciones se borran al año y los eventos se conservan mucho más tiempo. Si no se hiciera la copia quedarían eventos en los que se sabría que hubo una superación de umbral pero no de cuánto ni contra qué límite porque ya no tendrías la medición para ir a buscar esos datos. El compromiso es que se renuncia a la clave foránea hacia `medicion` (para poder borrar los registros de mediciones con libertad), aunque no hay riesgo de inconsistencia porque ambos valores no tienen alteración una vez ocurrido el hecho.

`alerta` guarda `id_dispositivo` aunque sea derivable con algunos saltos entre tablas. El motivo es que el camino hasta el dispositivo depende del origen de la alerta: si nació de un evento, hay que recorrer `alerta` → `evento` → `sensor` → `dispositivo`; si nació de una predicción, `alerta` → `prediccion` → `dispositivo`. Sin la columna agregada en redundancia, determinar a qué equipo pertenece una alerta requeriría dos recorridos alternativos según cuál clave foránea esté cargada (evento o predicción). Como las políticas RLS se evalúan fila por fila en toda consulta sobre la tabla, ese recorrido condicional se repetiría en cada evaluación. Con la columna, la política resuelve la planta con una sola comparación. Hay una redundancia pero es acotada porque el valor se conoce al crear la alerta y no cambia nunca.

`intervencion` almacena `embedding`, que es un dato derivado del texto de `observaciones`. Por el criterio general correspondería calcularlo en el momento de la búsqueda o ubicarlo en la capa oro por ser derivado, pero se guarda junto al texto porque calcular un embedding requiere invocar un modelo externo y sería inviable hacerlo directamente en cada consulta. Dado que las observaciones no se modifican una vez registrada la intervención, el embedding no puede quedar desactualizado, por lo que el riesgo es mínimo.

---

## 5.5 Resolución de las relaciones N:M

El modelo conceptual define dos relaciones muchos a muchos: `Medición ↔ Corrida de Entrenamiento` y `Medición ↔ Predicción`. Lo típico sería una tabla puente que enumere cada par.

Pero con unos 59 millones de mediciones al año, una corrida entrenada sobre un año de datos generaría 59 millones de filas puente, y doce corridas anuales superarían los 700 millones de filas cuya única función sería registrar qué mediciones participaron.

Entonces, en lugar de eso la relación se guarda por comprensión: `corrida_entrenamiento` almacena `rango_desde`, `rango_hasta` y `criterio_seleccion`, de modo que el conjunto de mediciones queda determinado por esa regla en vez de enumerado. `prediccion` resuelve lo mismo con `ventana_desde` y `ventana_hasta`.

El compromiso es que se pierde integridad referencial hacia las mediciones concretas, que de todas formas se borran al año.

---

## 5.6 Correspondencia con los patrones de consulta

La estructura elegida responde a cuatro formas de consumo bien distintas.

**La aplicación**, que es por donde operan operarios y técnicos, escribe alertas, órdenes e intervenciones y lee el estado actual, siempre bajo RLS. Consulta pocas filas por vez y necesita que el dato sea exacto, con lo cual la normalización de plata le garantiza consistencia. Además es el consumidor que motiva una de las dos desnormalizaciones de esa capa: id_dispositivo en alerta existe para que RLS resuelva la planta sin recorridos condicionales.

**El supervisor** puede consultar la base directamente. Usa plata para el estado operativo (alertas abiertas, últimas lecturas) y oro para tendencias, con lo cual atraviesa las dos capas y aprovecha las dos estructuras.

**El científico de datos** trabaja sobre oro, con análisis histórico de meses o años sobre todas las plantas y sin acceso a datos personales. Los precálculos de las tablas de fetures le evita agregar la serie completa en cada consulta y le brinda el formato "ancho" que necesita para sus modelos, consumidos a través del servicio de predicción.
