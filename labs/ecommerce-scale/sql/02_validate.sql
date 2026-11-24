-- Conferir quantidades e relacionamento dos dados gerados.
\set ON_ERROR_STOP on
\timing on

SELECT 'categories' AS tabela, count(*) AS registros FROM categories
UNION ALL SELECT 'customers', count(*) FROM customers
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'payments', count(*) FROM payments
ORDER BY tabela;

-- Uma unidade lógica de compra tem 3 itens e 1 pagamento.
SELECT
    o.id AS pedido,
    count(oi.id) AS itens,
    SUM(oi.quantity * oi.unit_price) AS total_itens,
    p.amount AS valor_pago,
    (SUM(oi.quantity * oi.unit_price) = p.amount) AS pagamento_confere
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN payments p ON p.order_id = o.id
WHERE o.id = 42
GROUP BY o.id, p.amount;

-- Resultado final esperado na carga completa:
-- categories    100
-- customers     1000000
-- products      50000
-- orders        5000000
-- order_items   15000000
-- payments      5000000
-- TOTAL         26050100
