# 6. Selección tecnológica

## 6.1 Descripción general

En esta sección se justifica la elección del motor de base de datos sobre el que se implementa el sistema. La decisión no se toma en abstracto, sino a partir de los requisitos técnicos que impone el caso de monitoreo IoT con análisis predictivo, contrastando la opción adoptada contra las alternativas razonables que se evaluaron.

La conclusión, que se desarrolla a lo largo de la sección, es el uso de un **motor único: PostgreSQL, con la extensión pgvector**. La particularidad del caso es que combina tipos de datos y patrones de acceso que suelen resolverse en sistemas distintos y especializados, y la pregunta de fondo es si conviene combinar varios motores (uno por necesidad) o cubrir todo con uno solo lo suficientemente versátil.

---

## 6.2 Requisitos técnicos que impone el caso

Antes de comparar tecnologías conviene enumerar qué necesidades concretas tiene que satisfacer la base, porque son esas necesidades las que definen contra qué se compara cada candidato. Del dominio surgen cinco requisitos que no siempre conviven en un mismo motor:

**1. Series temporales de alto volumen.** El corazón del sistema son las mediciones de los sensores: del orden de 59 millones de filas al año (ver Actividad 12), llegando de forma continua y consultándose siempre por rango temporal (últimas lecturas, promedios por día, medias móviles). Esto exige escritura sostenida, particionamiento e índices adecuados para datos ordenados por tiempo.

**2. Datos semiestructurados (JSON).** Tanto el payload crudo que llega a la capa bronce como la configuración de los sensores (umbrales, calibración) tienen forma de documento con estructura variable. Se necesita poder almacenarlos sin un esquema rígido y, a la vez, poder consultar e indexar claves internas sin parsear el documento completo cada vez.

**3. Texto no estructurado con búsqueda por similitud.** Las observaciones que deja el técnico en cada intervención son texto libre en lenguaje natural. El caso pide poder recuperar intervenciones pasadas con síntomas parecidos, lo que implica trabajar con _embeddings_ (representaciones vectoriales del texto) y hacer búsqueda por cercanía entre vectores.

**4. Aislamiento de datos por planta (seguridad a nivel de fila).** Al haber dos plantas y roles con alcance acotado, la base tiene que garantizar que ciertos usuarios solo vean las filas que les corresponden. No es un filtro que pueda quedar solo en la aplicación: se busca resolverlo en el propio motor, con seguridad a nivel de fila (Row-Level Security, RLS; ver Actividad 11).

**5. Integridad referencial fuerte en el dominio de gestión.** Toda la cadena de negocio —dispositivo, sensor, evento, alerta, orden de trabajo, intervención, usuario— tiene relaciones que deben mantenerse consistentes. Una orden de trabajo no puede apuntar a una alerta inexistente, ni una intervención a una orden que no existe. Esto es terreno natural del modelo relacional con claves foráneas y restricciones (`CHECK`, `UNIQUE`).

A esto se suma un requisito transversal: la arquitectura Medallion (bronce / plata / oro) elegida en la Actividad 4 se implementa como _schemas_ dentro de un mismo sistema, lo que ya inclina la decisión hacia un motor que permita separar capas lógicamente sin multiplicar la infraestructura.

---

## 6.3 La disyuntiva de fondo: motor único vs. persistencia poliglota

Los cinco requisitos anteriores rara vez brillan todos en el mismo producto. Frente a esto hay dos estrategias posibles.

La primera es la **persistencia poliglota**: usar varios motores, cada uno especializado en lo que mejor hace. Por ejemplo, una base de series temporales (InfluxDB, TimescaleDB) para las mediciones, una base documental (MongoDB) para el JSON, una base vectorial dedicada (Pinecone, Milvus, Qdrant) para los embeddings, y una relacional para la gestión. Cada pieza rinde muy bien en su terreno.

La segunda es el **motor único**: elegir un sistema lo bastante versátil como para cubrir todos los requisitos de manera aceptable, aunque en algún punto individual no sea el mejor del mercado.

El costo de la opción poliglota no aparece en el rendimiento de cada motor, sino en el sistema como conjunto:

| Dimensión               | Costo de combinar varios motores                                                                                                                                              |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Integridad referencial  | Se pierde entre sistemas. Una alerta en un motor no puede tener una clave foránea a una predicción de otro motor; la consistencia queda librada a la aplicación.              |
| Seguridad y aislamiento | Hay que replicar el control de acceso (RLS) en cada motor, con criterios y mecanismos distintos, multiplicando la superficie de error.                                        |
| Operación               | Más piezas que desplegar, respaldar, monitorear, versionar y mantener sincronizadas. Cada motor es un punto de falla y una dependencia más.                                   |
| Consultas mixtas        | Cruzar una intervención (texto/vector) con su orden de trabajo y su dispositivo (relacional) obliga a unir datos entre sistemas en la aplicación, en vez de un simple `JOIN`. |

Para el volumen y la complejidad de este caso, esos costos superan a la ganancia de rendimiento por especialización. El sistema no maneja el volumen de texto ni la escala de series que justificarían un motor dedicado; sí necesita, en cambio, integridad y seguridad coherentes en todo el dominio, que es precisamente lo que la opción poliglota vuelve difícil. Por eso se opta por un motor único, siempre que exista uno capaz de cubrir los cinco requisitos.

---

## 6.4 La opción elegida: PostgreSQL + pgvector

PostgreSQL es una base de datos relacional de código abierto, madura y extensible. Esa extensibilidad es la clave de la elección: además de todo lo que se espera de una relacional (claves foráneas, restricciones, transacciones ACID), incorpora de forma nativa o vía extensiones las capacidades que el caso necesita. La siguiente tabla mapea cada requisito de la sección 6.2 con el mecanismo de PostgreSQL que lo resuelve:

| Requisito del caso                         | Cómo lo cubre PostgreSQL                                                                                                                                               |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Series temporales de alto volumen          | Particionamiento declarativo por rango sobre el timestamp e índices **BRIN**, muy compactos para datos naturalmente ordenados por tiempo (ver Actividades 7 y 12).     |
| Datos semiestructurados (JSON)             | Tipo de dato **JSONB**, que almacena el documento en forma binaria indexable y permite consultar claves internas sin recorrer todo el texto.                           |
| Texto no estructurado + búsqueda vectorial | Extensión **pgvector**, que agrega el tipo `vector` y operadores de distancia, con índices aproximados (HNSW / IVFFlat) para búsqueda por similitud (ver Actividad 9). |
| Aislamiento por planta                     | **Row-Level Security** nativo: políticas que filtran filas según la identidad del usuario, evaluadas por el propio motor en cada consulta (ver Actividad 11).          |
| Integridad referencial del dominio         | Modelo relacional clásico: claves foráneas, `CHECK`, `UNIQUE`, transacciones. Es el terreno propio de PostgreSQL.                                                      |
| Separación en capas (Medallion)            | **Schemas** (`bronce`, `plata`, `oro`) dentro de la misma base, sin necesidad de sistemas separados.                                                                   |

El punto decisivo es que la extensión **pgvector** es lo que permite que la búsqueda por similitud, que sería el argumento más fuerte a favor de sumar un motor dedicado, se resuelva dentro del mismo PostgreSQL. Con eso, el último requisito que empujaba hacia la persistencia poliglota queda cubierto sin salir del motor único, y se conservan la integridad referencial y la seguridad unificadas.

Un beneficio adicional, propio de mantener todo en un solo sistema, es que la búsqueda vectorial puede quedar sujeta a las mismas políticas RLS que el resto de los datos: una búsqueda por similitud sobre las intervenciones no puede devolver resultados de una planta a la que el usuario no tiene acceso (ver Actividades 9 y 11). En un esquema poliglota, con los vectores en un motor aparte, garantizar eso sería considerablemente más complejo.

---

## 6.5 Alternativas evaluadas y descartadas

Se evaluaron y descartaron tres alternativas: las bases de series temporales (TimescaleDB, InfluxDB), excelentes para las mediciones pero débiles en integridad referencial, aislamiento por fila y búsqueda vectorial; MongoDB, que encaja con el JSON pero resigna las claves foráneas y el control de acceso a nivel de fila que el dominio necesita; y las bases vectoriales dedicadas (Pinecone, Milvus, Qdrant), sobredimensionadas para el bajo volumen de texto del caso, que pgvector maneja de sobra. Cada una resolvía bien una arista pero debilitaba las demás: PostgreSQL con pgvector es la única que cubre las cinco necesidades en un solo sistema, con integridad y seguridad coherentes.

---
