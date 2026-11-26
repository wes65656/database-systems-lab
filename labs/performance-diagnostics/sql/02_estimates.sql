\set ON_ERROR_STOP on
\ir explain_helper.sql
\echo '=== Estimativas: distribuição alterada e ANALYZE ==='
CREATE TEMP TABLE distribution WITH (autovacuum_enabled = false)
AS SELECT id, CASE WHEN id <= 1000 THEN 1 ELSE 2 END AS status
FROM generate_series(1, 10000) AS id;
ANALYZE distribution;
UPDATE distribution SET status = 1 WHERE id BETWEEN 1001 AND 9000;

\set query 'SELECT id FROM distribution WHERE status = 1'
SELECT pg_temp.measure(:'query') AS stale_plan \gset
ANALYZE distribution;
SELECT pg_temp.measure(:'query') AS fresh_plan \gset

WITH plans AS (
    SELECT 'estatísticas antigas' AS phase, :'stale_plan'::jsonb AS plan
    UNION ALL
    SELECT 'após ANALYZE', :'fresh_plan'::jsonb
)
SELECT phase, plan ->> 'Plan Rows' AS estimated_rows, plan ->> 'Actual Rows' AS actual_rows
FROM plans;

WITH estimates AS (
    SELECT (:'stale_plan'::jsonb ->> 'Plan Rows')::int AS stale,
           (:'fresh_plan'::jsonb ->> 'Plan Rows')::int AS fresh,
           (:'fresh_plan'::jsonb ->> 'Actual Rows')::numeric AS actual
)
SELECT 1 / COALESCE((actual = 9000 AND abs(fresh - actual) < abs(stale - actual))::int, 0) AS estimate_check
FROM estimates;
