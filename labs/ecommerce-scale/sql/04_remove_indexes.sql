-- Reinicia o experimento removendo SOMENTE índices extras deste laboratório.
-- PKs e UNIQUEs são preservados, assim como todos os dados.
\set ON_ERROR_STOP on
\timing on
DROP INDEX IF EXISTS idx_orders_customer_placed;
DROP INDEX IF EXISTS idx_order_items_order;
DROP INDEX IF EXISTS idx_order_items_product;
DROP INDEX IF EXISTS idx_products_category;
ANALYZE;
\echo Indices extras removidos. O baseline pode ser medido novamente.
