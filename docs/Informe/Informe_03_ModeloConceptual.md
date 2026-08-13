# 3. Modelo conceptual

## 3.1 Descripción general

El modelo conceptual representa el dominio de monitoreo IoT con análisis predictivo en cuatro bloques: **Activos** (ubicaciones, dispositivos, sensores y su configuración), **Telemetría** (mediciones, eventos y alertas), **Gestión** (usuarios, órdenes de trabajo e intervenciones) y **Analítico** (modelos de ML, corridas de entrenamiento, métricas y predicciones). El modelo es independiente de la tecnología de implementación; la traducción a tablas relacionales sobre PostgreSQL se desarrolla en la Actividad 4 (modelo lógico).

El diagrama completo se adjunta como `docs/modelo_conceptual.png`.


## 3.2 Entidades y atributos relevantes

| Bloque | Entidad | Atributos relevantes |
|---|---|---|
| Activos | **Ubicación** | nombre, tipo (planta / área / línea), ubicación padre (autoreferencial) |
| Activos | **Dispositivo** | nombre, tipo de dispositivo, ubicación |
| Activos | **Sensor** | nombre, tipo de variable, unidad |
| Activos | **Configuración de Dispositivo** (historizada) | parámetro, valor, vigente desde / hasta |
| Telemetría | **Medición** | timestamp, valor |
| Telemetría | **Evento** | timestamp, tipo de evento, descripción |
| Telemetría | **Alerta** | severidad, estado, timestamp de apertura |
| Gestión | **Orden de Trabajo** | estado, fecha de apertura / cierre |
| Gestión | **Intervención** | observaciones (texto libre + embedding), fecha |
| Gestión | **Usuario** | nombre, rol, ubicación |
| Analítico | **Modelo (ML)** | nombre, tipo, versión |
| Analítico | **Corrida de Entrenamiento** | fecha, dataset usado, hiperparámetros |
| Analítico | **Métrica** | nombre, valor |
| Analítico | **Predicción** | ventana, probabilidad de falla, umbral, timestamp |

## 3.3 Relaciones y cardinalidades

| # | Relación | Cardinalidad |
|---|---|---|
| 1 | Ubicación **contiene** Ubicación | 1:N (autoreferencial) |
| 2 | Ubicación **aloja** Dispositivo | 1:N |
| 3 | Dispositivo **tiene** Sensor | 1:N |
| 4 | Dispositivo **tiene** (config. vigente) Configuración de Dispositivo | 1:N |
| 5 | Sensor **genera** Medición | 1:N |
| 6 | Medición **dispara** Evento | 1:N |
| 7 | Evento **dispara** Alerta | 1:N |
| 8 | Alerta **deriva en** Orden de Trabajo | 1:N |
| 9 | Orden de Trabajo **implica** Intervención | 1:N |
| 10 | Usuario **realiza** Intervención | 1:N |
| 11 | Medición **alimenta** Corrida de Entrenamiento | N:M |
| 12 | Medición **utilizada en** Predicción | N:M |
| 13 | Modelo **tiene** Corrida de Entrenamiento | 1:N |
| 14 | Modelo **genera** Predicción | 1:N |
| 15 | Corrida de Entrenamiento **produce** Métrica | 1:N |
| 16 | Predicción **dispara** Alerta | 1:N |

> Adicionalmente, **Intervención se compara por similitud con Intervención** (vía embedding sobre el campo de observaciones). No se representa en el diagrama como relación estructural porque es una operación de consulta (búsqueda por similitud).

## 3.4 Restricciones y decisiones de diseño relevantes

- Un sensor mide una sola variable.
- Una alerta se interpreta con la configuración/umbral vigente al momento de su apertura, no con la configuración actual — por eso Configuración de Dispositivo está historizada.
- Toda intervención pertenece a una orden de trabajo.
- El rol científico de datos no tiene visibilidad de qué técnico específico realizó una intervención.
- Evento depende de Medición: se detecta analizando el valor de una medición concreta, no directamente del sensor como fuente genérica.
- Un evento puede disparar varias alertas y una alerta puede derivar en varias órdenes de trabajo (ambas 1:N).
- Un evento por deficiencia en calidad de medición (medición fuera de rango o ausencia de reporte) se reporta asociada al sensor, nunca al dispositivo, para distinguir una falla de instrumentación de una falla real del equipo.
- Cada alerta tiene un único origen: o un evento detectado por umbral, o una predicción de falla que supera el umbral del modelo — nunca ambos. Un mismo dispositivo puede tener varias alertas abiertas simultáneamente, incluso de orígenes distintos.
- El responsable de una alerta se identifica indirectamente, a través del usuario que realizó la intervención asociada — no hay una relación directa Usuario–Alerta.
- Ubicación se modela con una jerarquía autoreferencial (planta → área → línea), lo que permite resolver a qué planta pertenece cualquier nivel inferior — necesario para el aislamiento de datos por planta (RLS).