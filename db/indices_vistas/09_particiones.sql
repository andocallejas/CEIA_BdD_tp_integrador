-- =====================================================
-- 09 - Particiones de plata.medicion
-- =====================================================
-- medicion se declaro PARTITION BY RANGE sobre el timestamp
-- (script 03). Ahora se crean las particiones concretas: una
-- subtabla por mes. Cada INSERT en medicion se enruta solo a
-- la particion cuyo rango contiene su timestamp; si no existe
-- la particion destino, el INSERT FALLA. Por eso las
-- particiones se crean ANTES de cargar datos.
--
-- Se genera un anio completo (2026) con un bloque DO en lugar
-- de escribir 12 CREATE TABLE a mano. El rango de cada mes es
-- [primer dia del mes, primer dia del mes siguiente).
-- =====================================================

DO $$
DECLARE
    mes_inicio date := '2026-01-01';
    i integer;
    desde date;
    hasta date;
    nombre text;
BEGIN
    FOR i IN 0..11 LOOP
        desde  := mes_inicio + (i    || ' months')::interval;
        hasta  := mes_inicio + (i + 1|| ' months')::interval;
        nombre := 'medicion_' || to_char(desde, 'YYYY_MM');
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS plata.%I PARTITION OF plata.medicion
               FOR VALUES FROM (%L) TO (%L);',
            nombre, desde, hasta
        );
    END LOOP;
END $$;
