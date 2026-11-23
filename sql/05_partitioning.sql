-- EXPERIMENTO 05: particionamento por mês.
CREATE TABLE IF NOT EXISTS events (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    customer_id INT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    description TEXT NOT NULL
) PARTITION BY RANGE (occurred_at);

CREATE TABLE IF NOT EXISTS events_2026_10 PARTITION OF events
FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');

CREATE TABLE IF NOT EXISTS events_2026_11 PARTITION OF events
FOR VALUES FROM ('2026-11-01 00:00:00+00') TO ('2026-12-01 00:00:00+00');

-- Somente os dados de demonstração são limpos.
TRUNCATE TABLE events RESTART IDENTITY;
INSERT INTO events (customer_id, occurred_at, description)
SELECT (g % 300) + 1,
       TIMESTAMPTZ '2026-10-01 00:00:00+00' + g * INTERVAL '5 minutes',
       'Evento de estudo'
FROM generate_series(0, 14999) g;

ANALYZE events;
SELECT tableoid::regclass AS particao, count(*) AS registros
FROM events GROUP BY tableoid ORDER BY particao;

\echo ==== PRUNING: CONSULTA SOMENTE NOVEMBRO ====
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM events
WHERE occurred_at >= '2026-11-01 00:00:00+00'
  AND occurred_at < '2026-12-01 00:00:00+00';

\echo ==== SEM FILTRO DE DATA: LE AS DUAS PARTICOES ====
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM events;
