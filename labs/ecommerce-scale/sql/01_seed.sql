-- População determinística e reproduzível: por padrão ~260,6 mil linhas.
-- Para carga completa, passe variáveis pelo psql (-v customers=1000000 ...).
-- ATENÇÃO: TRUNCATE limpa apenas AS SEIS TABELAS DO BANCO ISOLADO.
\set ON_ERROR_STOP on
\timing on

\if :{?customers}
\else
\set customers 10000
\endif
\if :{?products}
\else
\set products 500
\endif
\if :{?orders}
\else
\set orders 50000
\endif

\echo Limpando dados anteriores do laboratório ecommerce_scale...
TRUNCATE TABLE payments, order_items, orders, products, customers, categories;

\echo Inserindo 100 categorias...
INSERT INTO categories (id, name)
SELECT g, 'Categoria ' || g
FROM generate_series(1, 100) AS g;

\echo Inserindo clientes...
INSERT INTO customers (id, full_name, email, created_at)
SELECT g,
       'Cliente ' || g,
       'cliente' || g || '@example.invalid',
       TIMESTAMPTZ '2024-01-01 00:00:00+00' + ((g - 1) % 730) * INTERVAL '1 day'
FROM generate_series(1::bigint, (:customers)::bigint) AS g;

\echo Inserindo produtos...
INSERT INTO products (id, category_id, name, unit_price, active)
SELECT g,
       (((g - 1) % 100) + 1)::int,
       'Produto ' || g,
       ((1000 + (g % 10000))::numeric / 100)::numeric(12, 2),
       TRUE
FROM generate_series(1::bigint, (:products)::bigint) AS g;

\echo Inserindo pedidos...
INSERT INTO orders (id, customer_id, placed_at, status)
SELECT g,
       ((g - 1) % (:customers)) + 1,
       TIMESTAMPTZ '2024-01-01 00:00:00+00'
         + ((g - 1) % 730) * INTERVAL '1 day'
         + ((g - 1) % 1440) * INTERVAL '1 minute',
       'paid'
FROM generate_series(1::bigint, (:orders)::bigint) AS g;

\echo Inserindo 3 itens por pedido...
INSERT INTO order_items (id, order_id, product_id, quantity, unit_price)
SELECT (o.id - 1) * 3 + k.pos,
       o.id,
       p.product_id,
       (((o.id + k.pos) % 3) + 1)::int,
       ((1000 + (p.product_id % 10000))::numeric / 100)::numeric(12, 2)
FROM generate_series(1::bigint, (:orders)::bigint) AS o(id)
CROSS JOIN generate_series(1, 3) AS k(pos)
CROSS JOIN LATERAL (
    SELECT ((o.id + k.pos * 97 - 1) % (:products)) + 1 AS product_id
) AS p;

\echo Inserindo um pagamento por pedido (valor real calculado a partir dos itens)...
INSERT INTO payments (id, order_id, amount, status, paid_at)
SELECT oi.order_id,
       oi.order_id,
       SUM(oi.quantity * oi.unit_price)::numeric(14, 2),
       'captured',
       TIMESTAMPTZ '2024-01-01 00:00:00+00'
          + ((oi.order_id - 1) % 730) * INTERVAL '1 day'
          + ((oi.order_id - 1) % 1440) * INTERVAL '1 minute'
          + INTERVAL '5 minutes'
FROM order_items AS oi
GROUP BY oi.order_id;

\echo Atualizando estatísticas (ANALYZE)...
ANALYZE;
\echo População concluída.
