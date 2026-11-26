\set ON_ERROR_STOP on
SELECT set_config('perf_lab.blocker_pid', :'blocker_pid', false);
DO $observe$
DECLARE
    blocker integer := current_setting('perf_lab.blocker_pid')::integer;
    waiting_pid integer;
BEGIN
    FOR attempt IN 1..100 LOOP
        PERFORM pg_stat_clear_snapshot();
        SELECT pid INTO waiting_pid
        FROM pg_stat_activity
        WHERE datname = current_database() AND application_name = 'perf_lab_waiter'
          AND wait_event_type = 'Lock' AND blocker = ANY(pg_blocking_pids(pid));
        EXIT WHEN FOUND;
        PERFORM pg_sleep(0.05);
    END LOOP;

    IF waiting_pid IS NULL THEN
        RAISE EXCEPTION 'A espera pelo bloqueador % não apareceu a tempo', blocker;
    END IF;
    PERFORM set_config('perf_lab.waiter_pid', waiting_pid::text, false);
END;
$observe$;

SELECT waiting.pid AS waiting_pid, waiting.wait_event_type, waiting.wait_event,
       holder.pid AS blocking_pid, holder.state AS blocking_state,
       waiting.query AS waiting_query
FROM pg_stat_activity AS waiting
JOIN pg_stat_activity AS holder ON holder.pid = ANY(pg_blocking_pids(waiting.pid))
WHERE waiting.pid = current_setting('perf_lab.waiter_pid')::int
  AND holder.pid = current_setting('perf_lab.blocker_pid')::int;

SELECT locktype, mode, granted
FROM pg_locks
WHERE pid = current_setting('perf_lab.waiter_pid')::int AND NOT granted;

SELECT 1 / pg_cancel_backend(current_setting('perf_lab.waiter_pid')::int)::int AS cancel_check;
