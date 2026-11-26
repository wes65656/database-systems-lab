\set ON_ERROR_STOP on
\ir explain_helper.sql
\echo '=== Índice composto: mesma consulta antes e depois ==='
SET max_parallel_workers_per_gather = 0;
DROP INDEX IF EXISTS perf_lab.events_tenant_recent;
\set query 'SELECT id, payload FROM perf_lab.events WHERE tenant_id = 7 ORDER BY id DESC LIMIT 20'
CREATE TEMP TABLE baseline AS :query;
SELECT pg_temp.measure(:'query') AS before_plan \gset

CREATE INDEX events_tenant_recent ON perf_lab.events (tenant_id, id DESC);
SELECT pg_temp.measure(:'query') AS after_plan \gset
CREATE TEMP TABLE indexed_result AS :query;

WITH plans AS (
    SELECT 'sem índice composto' AS phase, :'before_plan'::jsonb AS plan
    UNION ALL
    SELECT 'com índice composto', :'after_plan'::jsonb
)
SELECT phase, plan #>> '{Plans,0,Node Type}' AS access_node,
       plan ->> 'Actual Rows' AS rows_returned,
       (plan ->> 'Shared Hit Blocks')::int + (plan ->> 'Shared Read Blocks')::int AS shared_blocks
FROM plans;

WITH differences AS (
    (SELECT * FROM baseline EXCEPT ALL SELECT * FROM indexed_result)
    UNION ALL
    (SELECT * FROM indexed_result EXCEPT ALL SELECT * FROM baseline)
)
SELECT 1 / COALESCE((
    NOT EXISTS (SELECT FROM differences)
    AND (SELECT count(*) FROM indexed_result) = 20
    AND :'after_plan'::jsonb #>> '{Plans,0,Index Name}' = 'events_tenant_recent'
    AND (:'after_plan'::jsonb ->> 'Shared Hit Blocks')::int + (:'after_plan'::jsonb ->> 'Shared Read Blocks')::int
        < (:'before_plan'::jsonb ->> 'Shared Hit Blocks')::int + (:'before_plan'::jsonb ->> 'Shared Read Blocks')::int
)::int, 0) AS index_check;
