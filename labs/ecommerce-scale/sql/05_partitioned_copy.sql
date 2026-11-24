-- LAB: compara partições por RANGE com a tabela orders convencional.
-- ATENÇÃO: copia TODOS os pedidos para uma SEGUNDA tabela, usando disco adicional.
-- Rode apenas quando tiver espaço. NÃO altera orders, order_items ou payments.
-- Na carga completa, esta etapa pode levar bastante tempo.
\set ON_ERROR_STOP on
\timing on
SET TIME ZONE 'UTC';

DROP TABLE IF EXISTS orders_partitioned;

CREATE TABLE orders_partitioned (
    id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    placed_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('paid', 'cancelled', 'pending')),
    -- Em tabelas particionadas, UNIQUE/PK deve incluir a chave de partição.
    PRIMARY KEY (id, placed_at)
) PARTITION BY RANGE (placed_at);

-- Cria partições mensais entre jan/2024 e dez/2025.
DO $$
DECLARE
    start_date DATE := DATE '2024-01-01';
    end_date DATE;
    partition_name TEXT;
BEGIN
    WHILE start_date < DATE '2026-01-01' LOOP
        end_date := (start_date + INTERVAL '1 month')::DATE;
        partition_name := 'orders_part_' || to_char(start_date, 'YYYY_MM');
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF orders_partitioned FOR VALUES FROM (%L) TO (%L)',
            partition_name,
            start_date::timestamptz,
            end_date::timestamptz
        );
        start_date := end_date;
    END LOOP;
END $$;

INSERT INTO orders_partitioned (id, customer_id, placed_at, status)
SELECT id, customer_id, placed_at, status
FROM orders;

ANALYZE orders_partitioned;

\echo ==== CONTAGEM DAS DUAS ESTRUTURAS ====
SELECT 'orders' AS tabela, count(*) AS registros FROM orders
UNION ALL
SELECT 'orders_partitioned', count(*) FROM orders_partitioned;

\echo ==== REGISTROS POR PARTICAO ====
SELECT tableoid::regclass AS particao, count(*) AS registros
FROM orders_partitioned
GROUP BY tableoid
ORDER BY tableoid::regclass::text;

\echo ==== AGORA RODE 06_partition_comparison.sql ====
