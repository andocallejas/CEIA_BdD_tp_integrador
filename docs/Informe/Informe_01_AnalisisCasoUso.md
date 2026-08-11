# 1. Análisis del caso de uso

## 1.1 Descripción general

El trabajo trata el caso de **monitoreo IoT con análisis predictivo**. Como impronta propia se plantea el problema sobre industria con equipos rotativos (motores eléctricos, bombas centrífugas, cintas transportadoras y además tableros eléctricos). Adicionalmente, se optó por modelar el escenario con **dos sitios** en lugar de uno solo, lo que obliga a que el diseño contemple desde el inicio el aislamiento de datos entre plantas para ciertos roles.

## 1.2 Problema que busca resolver la solución

El problema principal que busca resolver la solución es pasar de un esquema de **mantenimiento reactivo a uno predictivo**: hoy las fallas en los equipos rotativos se detectan cuando ya ocurrieron o cuando un operario las nota, y la idea es poder anticiparlas a partir del análisis histórico y en tiempo real de las mediciones de los sensores.

Sobre esa base, la solución termina resolviendo también otros problemas que surgen naturalmente del mismo dominio:

- **Gestión de alarmas**: cuando una medición se sale de rango, el sistema tiene que generar un evento, que podría convertirse en una alerta, y permitir que alguien la atienda.
- **Registro y consulta de intervenciones de mantenimiento**, incluyendo la posibilidad de buscar casos pasados con síntomas similares a partir de las observaciones que deja el técnico, usando búsqueda por similitud sobre texto.
- **Trazabilidad histórica**, para poder analizar tendencias y comparar comportamiento entre dispositivos, líneas o plantas.

## 1.3 Usuarios principales

Se modelan los siguientes usuarios:

- Operario de linea
- Técnico de mantenimiento
- Supervisor de planta
- Científico de datos
- Administrador o ingeniero de datos

Estos se pueden agrupar según cómo acceden a los datos:

- **Acceso indirecto, a través de una aplicación**: el operario de línea y el técnico de mantenimiento interactúan con el sistema desde apps dedicadas, sin ellos escribir o consultar SQL de forma directa mediante credenciales de base de datos propias.
- **Acceso directo o semidirecto a los datos**: el supervisor de planta y el científico de datos consultan información con mayor libertad, aunque siempre dentro de los límites que impone el control de acceso.
- **Acceso total**: el administrador o ingeniero de datos, responsable de la infraestructura completa.

El detalle de cada rol y su implementación se desarrolla en la sección de seguridad, permisos y aislamiento.

## 1.4 Procesos y funcionalidades que debería soportar

- Ingesta continua de mediciones desde los sensores de cada dispositivo.
- Validación de esas mediciones antes de que se consideren "confiables" para el resto del sistema.
- Detección automática de eventos anómalos a partir de umbrales.
- Generación y seguimiento de alertas, con asignación a un responsable.
- Registro de órdenes de trabajo e intervenciones de mantenimiento, con texto libre de observaciones.
- Búsqueda de intervenciones pasadas por similitud de síntomas descriptos en lenguaje natural.
- Consulta y análisis histórico de las mediciones.
- Soporte a un componente predictivo que consume los datos históricos para generar predicciones sobre el estado de los equipos.

## 1.5 Información que necesita gestionar

A grandes rasgos, el sistema tiene que gestionar información de varios tipos: datos de los activos (ubicaciones, dispositivos, sensores y su configuración), datos de telemetría (mediciones, eventos, alertas), datos de gestión (usuarios, órdenes de trabajo, intervenciones) y datos analíticos (features calculadas, modelos entrenados, predicciones). Luego, toda esta información pasa y se distribuye en distintos grados de madurez a lo largo del flujo de los datos (se retoma en detalle en la sección de relevamiento y clasificación de datos).

## 1.6 Riesgos que aparecen en relación con los datos

**Exposición de datos cruzada (aislamiento).** Sin un control de acceso adecuado, un usuario podría terminar viendo información que no le corresponde: un supervisor accediendo a datos de una planta que no es la suya, la búsqueda por similitud devolviendo intervenciones de otra planta, o un científico de datos viendo qué técnico específico hizo una intervención (un dato personal que no necesita para su análisis). Este riesgo se encara aplicando Row-Level Security en la capa plata y en la búsqueda vectorial, y combinando RLS con vistas en la capa oro que filtran ciertas columnas sensibles (como la identidad del técnico).

**Calidad del dato de sensores.** Las lecturas pueden llegar erróneas por un sensor que falla, o fuera de rango, o directamente faltar por pérdida de conectividad, lo que podría generar falsas alarmas o la falta de ellas si no se toman con cuidado. Este riesgo se encara validando el dato entre la capa bronce (crudo, tal como llega) y la capa plata, y haciendo que la detección de eventos corra sobre la capa plata y no sobre el dato crudo. Para los casos de mediciones validadas como fuera de rango o faltantes, también se generan eventos que pueden derivar en órdenes de trabajo, pero apuntando a revisar el sensor, no el dispositivo.

**Volumen y retención.** Con el volumen estimado para el caso (del orden de 50 millones de filas por año en mediciones), si hubieran consultas sin optimizar o una retención de datos históricos sin límites, se termina degradando el sistema a medida que crece. Este riesgo se encara acotando la retención del detalle de mediciones a un año en la capa plata (con agregados de más largo plazo en la capa oro), mientras que las órdenes de trabajo e intervenciones (al ser muchos menos registros) se conservan por un período bastante más extenso. Se aplica particionamiento mensual con índices adecuados para ese tipo de dato.

## 1.7 Decisiones de diseño importantes para el caso

- **Motor único: PostgreSQL.** Se eligió un solo motor, en lugar de combinar varios sistemas especializados, porque cubre series temporales (para los históricos y sistema predictivo), datos semiestructurados (configuración de sensores en JSONB), seguridad por fila y búsqueda vectorial (extensión pgvector) en un solo motor. Más detalles en sección Selección tecnológica.
- **Arquitectura Medallion (Bronce/Plata/Oro).** Los datos se organizan en capas según su nivel de madurez: crudo, validado, analítico. Se implementan como schemas dentro del mismo PostgreSQL. Se desarrolla en la sección de arquitectura de datos.
- **Row-Level Security (RLS).** El aislamiento por planta no queda sólo librado a la lógica de la aplicación, sino que se resuelve también en la base de datos. Se desarrolla en la sección de seguridad, permisos y aislamiento.
- **Mediciones en formato largo/angosto.** Cada lectura de sensor se guarda como una fila, en lugar de una columna por variable, para poder incorporar nuevos sensores o tipos de variable sin tener que rediseñar el modelo. Se desarrolla en la sección de modelo lógico y normalización.
- **Alcance acotado de la búsqueda vectorial.** pgvector se aplica únicamente sobre el texto libre de las observaciones de las intervenciones de los técnicos para encontrar intervenciones pasadas con síntomas parecidos expresados en lenguaje natural. Se desarrolla en la sección de datos semiestructurados, no estructurados y vectoriales.
