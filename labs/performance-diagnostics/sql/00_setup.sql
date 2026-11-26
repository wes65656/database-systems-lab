\set ON_ERROR_STOP on
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE SCHEMA IF NOT EXISTS perf_lab;
DROP TABLE IF EXISTS perf_lab.events;
CREATE TABLE perf_lab.events (
    id integer PRIMARY KEY,
    tenant_id integer NOT NULL,
    category integer NOT NULL,
    payload text NOT NULL
) WITH (autovacuum_enabled = false);

INSERT INTO perf_lab.events
SELECT id, id % 200, id % 20, repeat(md5(id::text), 8)
FROM generate_series(1, 60000) AS id;
ANALYZE perf_lab.events;

SELECT current_setting('server_version') AS server_version,
       current_setting('block_size') AS block_size,
       count(*) AS seeded_events
FROM perf_lab.events;
SELECT 1 / COALESCE((count(*) = 60000 AND count(DISTINCT tenant_id) = 200)::int, 0) AS seed_check
FROM perf_lab.events;
