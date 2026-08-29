# 11. Seguridad, permisos y aislamiento

## 11.1 Descripción general

El requisito central es el **aislamiento por planta**: con dos sitios y roles de alcance acotado, un usuario no debe ver datos de una planta que no le corresponde. El aislamiento no queda librado a la aplicación, sino que se resuelve en la propia base con **Row-Level Security (RLS)**. Se suma el ocultamiento de columnas sensibles (la identidad del técnico) para el científico de datos. El DDL está en `db/estructura/40_seguridad_rls.sql`.

## 11.2 Doble identidad: roles de base vs usuarios de aplicación

Los usuarios finales (operarios, técnicos, supervisores) **no tienen credencial de base de datos**. La aplicación se conecta con un único **rol de servicio** (`app_servicio`) y comunica quién es el usuario final por una variable de sesión (`app.usuario_id`) al inicio de cada transacción (`SET LOCAL app.usuario_id = ...`). Las políticas RLS leen esa variable con `current_setting('app.usuario_id')`. Así, un mismo rol de conexión atiende a todos los usuarios, pero cada uno ve solo lo suyo.

Se definen dos roles sin login: `app_servicio` (la app) y `rol_cientifico` (acceso analítico restringido).

## 11.3 Aislamiento por planta con RLS

La planta de una alerta se resuelve subiendo la jerarquía de ubicaciones (línea → área → planta) con funciones auxiliares (`fn_planta_de_ubicacion`, `fn_planta_de_dispositivo`). La política compara la planta del dato con la planta del usuario actual (`fn_planta_usuario_actual`), y deja pasar todo a los usuarios de alcance global —científico y administrador, con `id_ubicacion` en `NULL`— vía `fn_usuario_es_global`.

Se aplicó RLS sobre `alerta` (el caso testigo) y sobre `intervencion` (para que la búsqueda vectorial no cruce plantas). Las demás tablas de plata siguen el mismo patrón. La verificación sobre los datos de ejemplo:

| Usuario | Alcance | Alertas visibles |
|---|---|---|
| Supervisor Planta Norte | su planta | 3 |
| Supervisor Planta Sur | su planta | 1 |
| Científico de datos | global | 4 (todas) |

Los 3 + 1 de los supervisores suman exactamente las 4 que ve el usuario global: el aislamiento filtra bien, sin perder ni filtrar filas.

## 11.4 Ocultamiento de columnas sensibles

RLS es un control a nivel de **fila**: sirve para decidir qué filas ve alguien, pero no para ocultar una **columna** dentro de una fila visible. El científico de datos puede ver las intervenciones de todas las plantas, pero no debe ver *qué técnico* hizo cada una (`id_usuario`, dato personal innecesario para su análisis). Eso requiere un mecanismo aparte, y hay dos opciones:

- **Vista en oro sin la columna (elegida).** Se crea `oro.v_intervencion`, que proyecta todo menos `id_usuario`, y se le da acceso al `rol_cientifico` a esa vista en lugar de a la tabla base. Es simple y explícito: el científico literalmente no tiene por dónde acceder a la columna.
- **Permiso a nivel de columna (alternativa).** `GRANT SELECT (col1, col2, ...)` sobre la tabla, excluyendo `id_usuario`. Es más granular y evita crear una vista, pero es menos visible y más fácil de romper al agregar columnas. Queda documentado como comentario en el script.

## 11.5 Notas de implementación

- El trigger que crea alertas predictivas vive en oro y escribe en plata: **cruza schemas**, así que el rol que lo ejecuta necesita permisos en ambos.
- La búsqueda vectorial hereda el RLS de `intervencion`: el "vecino más cercano" se busca solo entre filas visibles, cerrando el riesgo de exposición vía IA (Actividad 9).
- El costo del recorrido que RLS hace sobre `intervencion` (varios saltos hasta la planta) es aceptable por el bajo volumen de la tabla; si creciera, se podría materializar la planta como se hizo con `id_dispositivo` en `alerta`.
