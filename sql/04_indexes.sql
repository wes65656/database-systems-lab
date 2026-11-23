-- EXPERIMENTO 04: impacto de índice composto (100 mil pedidos).
CREATE TABLE IF NOT EXISTS orders (
    id BIGINT PRIMARY KEY,
    customer_id INT NOT NULL,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    total NUMERIC(12, 2) NOT NULL
);

INSERT INTO orders (id, customer_id, status, created_at, total)
SELECT g,
       (g % 1000) + 1,
       CASE WHEN g % 3 = 0 THEN 'paid' ELSE 'pending' END,
       TIMESTAMPTZ '2026-01-01 00:00:00+00' + g * INTERVAL '1 minute',
       ((g % 10000) + 100) / 100.0
FROM generate_series(1, 100000) AS g
ON CONFLICT (id) DO NOTHING;

DROP INDEX IF EXISTS idx_orders_customer_created_at;
ANALYZE orders;
\echo ==== SEM INDICE COMPOSTO ====
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, customer_id, created_at, total
FROM orders WHERE customer_id = 42
ORDER BY created_at DESC LIMIT 20;

CREATE INDEX idx_orders_customer_created_at
    ON orders (customer_id, created_at DESC);
ANALYZE orders;
\echo ==== COM INDICE COMPOSTO ====
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, customer_id, created_at, total
FROM orders WHERE customer_id = 42
ORDER BY created_at DESC LIMIT 20;

-- Compare plano, tempo e buffers. Cache e aquecimento interferem nas medições.
