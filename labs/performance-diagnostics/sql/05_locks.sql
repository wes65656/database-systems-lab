\set ON_ERROR_STOP on
\echo '=== Esperas: sessão bloqueada e sessão bloqueadora ==='
SET application_name = 'perf_lab_holder';
BEGIN;
UPDATE perf_lab.events SET category = category + 1 WHERE id = 1;
SELECT pg_backend_pid() AS blocker_pid \gset
\setenv PERF_LAB_BLOCKER_PID :blocker_pid
\! sh /lab/sql/observe_lock.sh
SELECT 1 / COALESCE((:'SHELL_EXIT_CODE'::int = 0)::int, 0) AS lock_check;
ROLLBACK;

SELECT 1 / COALESCE((category = 1)::int, 0) AS rollback_check
FROM perf_lab.events WHERE id = 1;
