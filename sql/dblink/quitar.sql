-- =====================================================================
-- dblink/quitar.sql
-- quita dblink de la base donde se corre. lo usan los datos de prueba:
-- un servicio necesita dblink solo mientras arma sus datos (por ejemplo
-- ventas lee los precios de catalogo) y despues se le quita, para que en
-- su base no quede ninguna conexion hacia otra base.
--
-- CASCADE borra tambien lo que depende de la extension: los servidores
-- srv_* y sus USER MAPPING.
-- =====================================================================

DROP EXTENSION dblink CASCADE;
