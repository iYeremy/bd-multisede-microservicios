-- 03_dblink/quitar.sql
-- quita dblink y las conexiones guardadas de la base actual. lo usan los
-- datos de prueba al terminar. ver README.md.

DROP SCHEMA remoto CASCADE;
DROP EXTENSION dblink;
