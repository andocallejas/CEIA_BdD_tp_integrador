# Monitoreo IoT con análisis predictivo

**Trabajo Práctico Integrador — Bases de Datos para IA (CEIA)**

Integrantes: Mariano Jauffroy y Andrés García · Agosto 2026

El informe completo está en [`docs/Informe_Final.pdf`](docs/Informe_Final.pdf).

---

# 1. Descripción del trabajo

Este trabajo es una **solución de datos end-to-end** para el monitoreo IoT con análisis predictivo de una planta industrial de dos sitios, con equipos rotativos (motores, bombas, cintas y tableros) instrumentados con sensores. El objetivo de los datos es pasar de un mantenimiento reactivo a uno **predictivo**: a partir de la telemetría de los sensores se detectan eventos anómalos, se generan alertas, se registran las intervenciones de mantenimiento y se sostiene el análisis histórico y predictivo.

El conjunto de datos es la telemetría de esos sensores —del orden de decenas de millones de lecturas al año—, generada sintéticamente a escala realista para validar el diseño, el circuito de detección y las consultas sin depender de una planta real.

# 2. Solución propuesta

La solución se apoya en una **arquitectura Medallion** sobre un único PostgreSQL (con pgvector), implementada como schemas:

- **Bronce** — ingesta cruda tal como llega (JSONB, sin validar).
- **Plata** — datos limpios y validados, normalizados (3FN), con Row-Level Security para el aislamiento entre plantas.
- **Oro** — modelado final para consumo: agregados y features desnormalizados, más la trazabilidad del modelo predictivo.

Sobre esa base:

- **Analítica:** agregados horarios/diarios y consultas representativas (últimas lecturas, alertas por planta, medias móviles, rankings) que sirven de KPIs y alimentan los tableros de supervisión.
- **Predicción:** el ciclo de ML está modelado en la capa oro (features por ventana, modelo por tipo de equipo, corridas, métricas y predicciones); una predicción que supera el umbral genera una alerta por trigger. El entrenamiento del modelo en sí es externo y queda fuera del alcance.
- **Consumo:** búsqueda vectorial de intervenciones por similitud (pgvector) para el técnico, y una app operativa que consume la capa oro —conceptual, fuera del alcance de este trabajo, ya que la base registra hechos y la aplicación gobierna los procesos con estado.

# 3. Estructura de carpetas

```
CEIA_BdD_tp_integrador/
├── README.md                     Esta guía
├── docker-compose.yml            Levanta PostgreSQL + pgvector y carga todo
├── docker/initdb/                Script que auto-carga la base en el primer arranque
├── db/                           Todo el SQL, numerado por orden de ejecución
│   ├── run_all.sql               Script maestro (arma el modelo base en orden)
│   ├── estructura/               DDL de tablas, triggers (00–08, 11) y seguridad RLS (40)
│   ├── indices_vistas/           Particiones e índices (09, 10, 31 vectorial)
│   ├── datos/                    Carga de datos (12–18) y embeddings (30)
│   └── consultas/                Las 8 consultas representativas (20–26, 32)
├── docs/
│   ├── Informe/                  Los 12 informes por actividad (.md)
│   ├── Informe_Final.pdf         Informe completo (este documento)
│   ├── arquitectura_datos.mmd    Fuente del diagrama de arquitectura
│   ├── modelo_conceptual.png     Diagrama del modelo conceptual
│   └── modelo_logico.png         Diagrama del modelo lógico
├── anexos/                       Contexto del proyecto, guía de implementación y DBML
├── nosql/  vectorial/            Notas de datos semiestructurados y vectoriales
└── data/                         Reservada para datos de ejemplo exportados
```

El informe principal se entrega como PDF (`docs/Informe_Final.pdf`); todo lo demás —SQL, consultas, diagramas y anexos— queda versionado por separado en las carpetas de arriba.

# 4. Cómo ejecutar todo

**Prerrequisito:** Docker Desktop instalado y corriendo.

**a) Levantar la base (crea y carga todo solo).** Desde la raíz del proyecto:

```bash
docker compose up -d
```

En el primer arranque, PostgreSQL crea la base `tp_bdia` y ejecuta automáticamente los scripts de `db/` (estructura, particiones, índices, triggers, carga de datos, seguridad RLS y búsqueda vectorial), dejando la base lista sin pasos extra.

**b) Verificar que cargó.** Datos de conexión: host `localhost`, puerto `5432`, usuario `postgres`, contraseña `bdia`, base `tp_bdia`.

```bash
docker compose exec db psql -U postgres -d tp_bdia -c "SELECT count(*) FROM plata.medicion;"
```

Debe devolver del orden de un millón de mediciones.

**c) Probar las consultas.** Están en `db/consultas/`. Por ejemplo:

```bash
docker compose exec db psql -U postgres -d tp_bdia -f /db/consultas/25_consulta_6_explain_plata_vs_oro.sql
```

**d) App de consumo.** Fuera del alcance de este trabajo: el proyecto entrega la base de datos (donde la aplicación operativa se conectaría a la capa oro), no la aplicación en sí.
