-- A função existe apenas na sessão que a carrega e recebe consultas fixas do laboratório.
CREATE OR REPLACE FUNCTION pg_temp.measure(statement text) RETURNS jsonb
LANGUAGE plpgsql AS $measure$
DECLARE plan jsonb;
BEGIN
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, FORMAT JSON) ' || statement INTO plan;
    RAISE NOTICE '%', jsonb_pretty(plan);
    RETURN plan -> 0 -> 'Plan';
END;
$measure$;
