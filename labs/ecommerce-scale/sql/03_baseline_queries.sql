-- EXPERIMENTO: consultas antes da indexação adicional.
-- Rode APÓS 01_seed.sql e ANTES de 04_add_indexes.sql.
-- Consultas somente leitura. Planos e tempos variam por máquina, cache e tamanho.
\set ON_ERROR_STOP on
\timing on

\echo ===== 01: ultimos pedidos do cliente 42 =====
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, customer_id, placed_at, status
FROM orders
WHERE customer_id = 42
ORDER BY placed_at DESC
LIMIT 20;

\echo ===== 02: itens de um pedido especifico =====
EXPLAIN (ANALYZE, BUFFERS)
SELECT oi.product_id, oi.quantity, oi.unit_price
FROM order_items AS oi
WHERE oi.order_id = 42;

\echo ===== 03: vendas por categoria no recorte dos primeiros 5000 pedidos =====
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.category_id,
       SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items AS oi
JOIN products AS p ON p.id = oi.product_id
WHERE oi.order_id BETWEEN 1 AND 5000
GROUP BY p.category_id
ORDER BY revenue DESC
LIMIT 10;

-- Para salvar resultados:
-- docker compose exec -T db psql ... -f /lab/sql/03_baseline_queries.sql | Tee-Object baseline.txt
