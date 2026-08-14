// =====================================================
// TP Integrador BDIA - Caso 3: Monitoreo IoT predictivo
// Modelo logico relacional (Actividad 4)
// Arquitectura Medallion: bronce / plata / oro
// =====================================================

// -----------------------------------------------------
// CAPA BRONCE - ingesta cruda, sin claves foraneas
// -----------------------------------------------------

Table bronce.medicion_cruda {
  id_medicion_cruda bigserial [pk]
  payload jsonb
  timestamp_recepcion timestamptz
  procesado boolean
  error_validacion text

  Note: 'Ingesta cruda de mediciones. Sin FK: en esta capa no se garantizan las referencias.'
}

Table bronce.configuracion_cruda {
  id_configuracion_cruda bigserial [pk]
  payload jsonb
  timestamp_recepcion timestamptz
  procesado boolean

  Note: 'Ingesta cruda de configuracion de sensores. Volumen y frecuencia mucho menor que medicion_cruda.'
}

// -----------------------------------------------------
// CAPA PLATA - normalizada (3FN), integridad referencial
// -----------------------------------------------------

// --- Catalogos ---

Table plata.unidad {
  id_unidad serial [pk]
  simbolo varchar(10)
  nombre varchar(50)
}

Table plata.tipo_variable {
  id_tipo_variable serial [pk]
  nombre varchar(50)
  id_unidad integer [ref: > plata.unidad.id_unidad]

  Note: 'La unidad cuelga del tipo de variable, no del sensor (elimina dependencia transitiva).'
}

Table plata.tipo_dispositivo {
  id_tipo_dispositivo serial [pk]
  nombre varchar(50)
  descripcion text
}

// --- Activos ---

Table plata.ubicacion {
  id_ubicacion serial [pk]
  nombre varchar(100)
  nivel varchar(20)
  id_ubicacion_padre integer [ref: > plata.ubicacion.id_ubicacion, null]

  Note: 'Jerarquia autoreferencial: planta > area > linea. Base del aislamiento por RLS.'
}

Table plata.dispositivo {
  id_dispositivo serial [pk]
  nombre varchar(100)
  id_tipo_dispositivo integer [ref: > plata.tipo_dispositivo.id_tipo_dispositivo]
  id_ubicacion integer [ref: > plata.ubicacion.id_ubicacion]
  estado varchar(20)
  fecha_alta date
}

Table plata.sensor {
  id_sensor serial [pk]
  id_dispositivo integer [ref: > plata.dispositivo.id_dispositivo]
  id_tipo_variable integer [ref: > plata.tipo_variable.id_tipo_variable]
  nombre varchar(100)
  estado varchar(20)

  Note: 'Un sensor mide una sola variable.'
}

Table plata.configuracion_dispositivo {
  id_configuracion serial [pk]
  id_dispositivo integer [ref: > plata.dispositivo.id_dispositivo]
  parametros jsonb
  valido_desde timestamptz
  valido_hasta timestamptz

  Note: 'Guardia historia y no se pisa la configuracion anterior.'
}

// --- Telemetria ---

Table plata.medicion {
  id_sensor integer [pk, ref: > plata.sensor.id_sensor]
  timestamp_medicion timestamptz [pk]
  valor "numeric(12,4)"
  calidad varchar(20)

  Note: 'PK compuesta. Particionada por rango mensual sobre timestamp_medicion, indice BRIN. Formato largo. ~59M filas/año.'
}

Table plata.evento {
  id_evento bigserial [pk]
  id_sensor integer [ref: > plata.sensor.id_sensor]
  timestamp_medicion timestamptz
  tipo_evento varchar(30)
  descripcion text
  valor_medido "numeric(12,4)"
  umbral_vigente "numeric(12,4)"
  timestamp_deteccion timestamptz

  Note: 'id_sensor + timestamp_medicion identifican la medicion de origen SIN FK, para permitir la eliminacion anual en tabla plata.medicion. valor_medido y umbral_vigente son copia intencional.'
}

Table plata.alerta {
  id_alerta bigserial [pk]
  id_dispositivo integer [ref: > plata.dispositivo.id_dispositivo]
  id_sensor integer [ref: > plata.sensor.id_sensor, null]
  id_evento bigint [ref: > plata.evento.id_evento, null]
  id_prediccion bigint [ref: > oro.prediccion.id_prediccion, null]
  origen varchar(20)
  severidad varchar(20)
  estado varchar(20)
  timestamp_apertura timestamptz
  timestamp_cierre timestamptz

  Note: 'CHECK: exactamente uno entre id_evento e id_prediccion. id_dispositivo es redundante (derivable) pero se materializa para RLS. id_prediccion es la unica FK de plata hacia oro.'
}

// --- Gestion ---

Table plata.usuario {
  id_usuario serial [pk]
  nombre varchar(100)
  email varchar(100)
  rol_negocio varchar(30)
  id_ubicacion integer [ref: > plata.ubicacion.id_ubicacion]
}

Table plata.orden_trabajo {
  id_orden_trabajo serial [pk]
  id_alerta bigint [ref: > plata.alerta.id_alerta]
  tipo varchar(30)
  estado varchar(20)
  fecha_apertura date
  fecha_cierre date

  Note: 'No almacena dispositivo ni sensor objetivo: se obtienen de la alerta (evita dependencia transitiva).'
}

Table plata.intervencion {
  id_intervencion serial [pk]
  id_orden_trabajo integer [ref: > plata.orden_trabajo.id_orden_trabajo]
  id_usuario integer [ref: > plata.usuario.id_usuario]
  fecha date
  observaciones text
  embedding "vector(384)"

  Note: 'Busqueda por similitud via pgvector sobre observaciones. id_usuario no visible para el rol cientifico de datos.'
}

// -----------------------------------------------------
// CAPA ORO - desnormalizada para lectura analitica
// -----------------------------------------------------

// --- Agregados analiticos ---

Table oro.agregado_horario {
  id_sensor integer [pk, ref: > plata.sensor.id_sensor]
  hora timestamptz [pk]
  promedio "numeric(12,4)"
  minimo "numeric(12,4)"
  maximo "numeric(12,4)"
  desvio "numeric(12,4)"
  cantidad_lecturas integer

  Note: 'Se retienen los datos mas alla del año de detalle en plata.'
}

Table oro.agregado_diario {
  id_sensor integer [pk, ref: > plata.sensor.id_sensor]
  dia date [pk]
  promedio "numeric(12,4)"
  minimo "numeric(12,4)"
  maximo "numeric(12,4)"
  desvio "numeric(12,4)"
  cantidad_lecturas integer

  Note: 'Se retienen los datos mas alla del año de detalle en plata.'
}

// --- Features para el modelo predictivo ---

Table oro.feature_motor_ventana {
  id_dispositivo integer [pk, ref: > plata.dispositivo.id_dispositivo]
  ventana_hasta timestamptz [pk]
  ventana_desde timestamptz
  vib_media "numeric(12,4)"
  vib_max "numeric(12,4)"
  vib_desvio "numeric(12,4)"
  vib_tendencia "numeric(12,4)"
  temp_media "numeric(12,4)"
  temp_max "numeric(12,4)"
  corr_media "numeric(12,4)"
  cant_eventos integer
  horas_operacion "numeric(6,2)"
  fallo_en_horizonte boolean
  timestamp_calculo timestamptz

  Note: 'Ventana de 24h recalculada cada hora. ~175 mil filas/anio. Alimenta entrenamiento y prediccion. fallo_en_horizonte NULL hasta que madura la ventana. feature_bomba_ventana, feature_cinta_ventana y feature_tablero_ventana son analogas y no se incluyen en el presente diagrama por simplicidad.'
}

// --- Trazabilidad del modelo predictivo ---

Table oro.modelo {
  id_modelo serial [pk]
  nombre varchar(100)
  version varchar(20)
  id_tipo_dispositivo integer [ref: > plata.tipo_dispositivo.id_tipo_dispositivo]
  horizonte_h integer
  estado varchar(20)

  Note: 'Un modelo por tipo de dispositivo. Los retirados se conservan para interpretar predicciones historicas.'
}

Table oro.corrida_entrenamiento {
  id_corrida bigserial [pk]
  id_modelo integer [ref: > oro.modelo.id_modelo]
  fecha timestamptz
  rango_desde timestamptz
  rango_hasta timestamptz
  criterio_seleccion jsonb
  hiperparametros jsonb
  uri_artefacto text

  Note: 'rango_desde/hasta + criterio_seleccion reemplazan la tabla puente de la N:M medicion-corrida del conceptual.'
}

Table oro.metrica {
  id_metrica bigserial [pk]
  id_corrida bigint [ref: > oro.corrida_entrenamiento.id_corrida]
  nombre varchar(50)
  particion varchar(20)
  valor "numeric(12,6)"

  Note: 'Formato largo: una fila por metrica. Admite cualquier indicador sin modificar el esquema.'
}

Table oro.prediccion {
  id_prediccion bigserial [pk]
  id_dispositivo integer [ref: > plata.dispositivo.id_dispositivo]
  id_modelo integer [ref: > oro.modelo.id_modelo]
  timestamp_prediccion timestamptz
  ventana_desde timestamptz
  ventana_hasta timestamptz
  horizonte_h integer
  score "numeric(5,4)"
  umbral_aplicado "numeric(5,4)"

  Note: 'Prediccion horaria por dispositivo. Trigger genera alerta si score > umbral_aplicado. id_dispositivo + ventana_hasta identifican la fila de features SIN FK (la tabla destino depende del tipo de dispositivo).'
}

// -----------------------------------------------------
// AGRUPAMIENTO VISUAL POR CAPA
// -----------------------------------------------------

TableGroup bronce {
  bronce.medicion_cruda
  bronce.configuracion_cruda
}

TableGroup plata {
  plata.unidad
  plata.tipo_variable
  plata.tipo_dispositivo
  plata.ubicacion
  plata.dispositivo
  plata.sensor
  plata.configuracion_dispositivo
  plata.medicion
  plata.evento
  plata.alerta
  plata.usuario
  plata.orden_trabajo
  plata.intervencion
}

TableGroup oro {
  oro.agregado_horario
  oro.agregado_diario
  oro.feature_motor_ventana
  oro.modelo
  oro.corrida_entrenamiento
  oro.metrica
  oro.prediccion
}