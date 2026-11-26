\set ON_ERROR_STOP on
\echo '=== pg_stat_statements: consultas normalizadas e custo acumulado ==='
SELECT oid AS lab_dbid FROM pg_database WHERE datname = current_database() \gset
SELECT pg_stat_statements_reset(0, :lab_dbid, 0);

SELECT count(*) FROM perf_lab.events WHERE category = 1;
SELECT count(*) FROM perf_lab.events WHERE category = 2;
SELECT count(*) FROM perf_lab.events WHERE category = 3;
SELECT sum(length(payload)) FROM perf_lab.events WHERE id BETWEEN 100 AND 10000;

SELECT queryid, calls, round(total_exec_time::numeric, 3) AS total_exec_ms,
       round(mean_exec_time::numeric, 3) AS mean_exec_ms,
       rows, shared_blks_hit, shared_blks_read, temp_blks_written, query
FROM pg_stat_statements
WHERE dbid = :lab_dbid AND toplevel AND query LIKE 'SELECT % FROM perf_lab.events WHERE %'
ORDER BY total_exec_time DESC;

SELECT 1 / COALESCE((count(*) = 1 AND sum(calls) = 3 AND sum(rows) = 3)::int, 0) AS workload_check
FROM pg_stat_statements
WHERE dbid = :lab_dbid AND toplevel
  AND query LIKE 'SELECT count(*) FROM perf_lab.events WHERE category = %';
