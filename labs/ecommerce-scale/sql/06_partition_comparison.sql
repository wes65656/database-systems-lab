-- Compare os mesmos filtros de data entre a tabela convencional e a
-- cópia particionada. Execute 05_partitioned_copy.sql antes.
-- Não há garantia de que o tempo melhore. Observe os *planos*.
\set ON_ERROR_STOP on
\timing on
SET TIME ZONE 'UTC';

\echo ==== TABELA NORMAL: BUSCA POR INTERVALO EM MARCO/2025 ====
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) AS total
FROM orders
WHERE placed_at >= TIMESTAMPTZ '2025-03-01 00:00:00+00'
  AND placed_at < TIMESTAMPTZ '2025-04-01 00:00:00+00';

\echo ==== TABELA PARTICIONADA: MESMO INTERVALO ====
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) AS total
FROM orders_partitioned
WHERE placed_at >= TIMESTAMPTZ '2025-03-01 00:00:00+00'
  AND placed_at < TIMESTAMPTZ '2025-04-01 00:00:00+00';

\echo ==== QUERY SEM FILTRO DE DATA: NAO HA PRUNING ====
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM orders_partitioned;

-- A análise correta compara nós no plano, buffers, estimativas e medições
-- em execuções repetidas. Particionar não implica aceleração automática.
