-- 03_dblink/quitar.sql
-- quita dblink de la base actual (y con CASCADE, sus servidores srv_*).
-- lo usan los datos de prueba al terminar. ver README.md.

DROP EXTENSION dblink CASCADE;
