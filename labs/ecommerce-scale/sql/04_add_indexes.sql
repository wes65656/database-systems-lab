-- EXPERIMENTO: adiciona indices orientados pelas consultas do baseline.
-- Operação potencialmente custosa com a carga de 26 milhões de linhas.
\set ON_ERROR_STOP on
\timing on

CREATE INDEX IF NOT EXISTS idx_orders_customer_placed
    ON orders (customer_id, placed_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_order
    ON order_items (order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product
    ON order_items (product_id);

CREATE INDEX IF NOT EXISTS idx_products_category
    ON products (category_id);

-- Payments.order_id ja possui indice UNIQUE; nao duplicar.
ANALYZE;

\echo ===== INDICES CRIADOS =====
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('orders', 'order_items', 'products')
ORDER BY tablename, indexname;

\echo ===== RODE 03_baseline_queries.sql NOVAMENTE PARA COMPARAR =====
