\set ON_ERROR_STOP on
\ir explain_helper.sql
\echo '=== Sort: arquivos temporários versus memória ==='
SET max_parallel_workers_per_gather = 0;
\set query 'SELECT id, payload FROM perf_lab.events WHERE id <= 25000 ORDER BY payload, id'
SET work_mem = '64kB';
SELECT pg_temp.measure(:'query') AS small_plan \gset
SET work_mem = '32MB';
SELECT pg_temp.measure(:'query') AS large_plan \gset

WITH plans AS (
    SELECT '64 kB' AS work_mem, :'small_plan'::jsonb AS plan
    UNION ALL
    SELECT '32 MB', :'large_plan'::jsonb
)
SELECT work_mem, plan ->> 'Sort Method' AS method, plan ->> 'Sort Space Type' AS space_type,
       plan ->> 'Temp Read Blocks' AS temp_read_blocks, plan ->> 'Temp Written Blocks' AS temp_written_blocks
FROM plans;
SELECT 1 / COALESCE((
    :'small_plan'::jsonb ->> 'Sort Space Type' = 'Disk'
    AND (:'small_plan'::jsonb ->> 'Temp Written Blocks')::int > 0
    AND :'large_plan'::jsonb ->> 'Sort Space Type' = 'Memory'
    AND (:'large_plan'::jsonb ->> 'Temp Written Blocks')::int = 0
    AND (:'large_plan'::jsonb ->> 'Actual Rows')::numeric = 25000
)::int, 0) AS sort_check;
