\set ON_ERROR_STOP on
\ir 04_mvcc_setup.sql
CREATE EXTENSION IF NOT EXISTS pageinspect;

BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT 1 / (balance = 900)::int AS initial_snapshot_check
FROM storage_lab.mvcc_demo WHERE id = 1;

-- psql abre uma segunda conexão. O VACUUM do escritor ocorre com o snapshot em aberto.
\! psql -X -U lab -d storage_engines -f /lab/sql/04_mvcc_writer.sql
SELECT 1 / (:'SHELL_EXIT_CODE'::int = 0)::int AS writer_check;
SELECT balance AS old_snapshot_balance FROM storage_lab.mvcc_demo WHERE id = 1;
SELECT 1 / (balance = 900)::int AS old_snapshot_check
FROM storage_lab.mvcc_demo WHERE id = 1;
SELECT count(*) AS versions_during_snapshot
FROM heap_page_items(get_raw_page('storage_lab.mvcc_demo', 0)) WHERE lp_flags = 1 \gset
\echo 'Versões físicas com snapshot aberto:' :versions_during_snapshot
SELECT 1 / (:versions_during_snapshot = 2)::int AS retained_version_check;
COMMIT;

SELECT balance AS new_snapshot_balance FROM storage_lab.mvcc_demo WHERE id = 1;
SELECT 1 / (balance = 1000)::int AS new_snapshot_check
FROM storage_lab.mvcc_demo WHERE id = 1;
VACUUM (VERBOSE, TRUNCATE FALSE) storage_lab.mvcc_demo;
SELECT count(*) AS versions_after_vacuum
FROM heap_page_items(get_raw_page('storage_lab.mvcc_demo', 0)) WHERE lp_flags = 1 \gset
\echo 'Versões físicas após VACUUM:' :versions_after_vacuum
SELECT 1 / (:versions_after_vacuum = 1)::int AS reclaimed_version_check;
