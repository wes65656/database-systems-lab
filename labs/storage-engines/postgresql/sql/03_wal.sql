\set ON_ERROR_STOP on
\echo '=== WAL: mesma atualização antes e depois de um checkpoint ==='
CREATE EXTENSION IF NOT EXISTS pg_walinspect;
CREATE SCHEMA IF NOT EXISTS storage_lab;
DROP TABLE IF EXISTS storage_lab.wal_demo;
CREATE TABLE storage_lab.wal_demo (id integer, payload text)
WITH (autovacuum_enabled = false);
INSERT INTO storage_lab.wal_demo VALUES (1, repeat('a', 512));
SET wal_compression = off;
SET synchronous_commit = on;
SHOW full_page_writes;
SHOW wal_compression;

CHECKPOINT;
UPDATE storage_lab.wal_demo SET payload = repeat('b', 512);
SELECT pg_current_wal_insert_lsn() AS warm_start \gset
EXPLAIN (ANALYZE, BUFFERS, WAL)
UPDATE storage_lab.wal_demo SET payload = repeat('c', 512);
SELECT pg_current_wal_insert_lsn() AS warm_end \gset

CHECKPOINT;
SELECT checkpoint_lsn, redo_lsn, checkpoint_time FROM pg_control_checkpoint();
SELECT pg_current_wal_insert_lsn() AS cold_start \gset
EXPLAIN (ANALYZE, BUFFERS, WAL)
UPDATE storage_lab.wal_demo SET payload = repeat('d', 512);
SELECT pg_current_wal_insert_lsn() AS cold_end \gset

SELECT 'before checkpoint' AS phase,
       pg_wal_lsn_diff(:'warm_end', :'warm_start') AS cluster_wal_bytes,
       coalesce(sum(fpi_length), 0) AS cluster_fpi_bytes
FROM pg_get_wal_records_info(:'warm_start', :'warm_end')
UNION ALL
SELECT 'after checkpoint', pg_wal_lsn_diff(:'cold_end', :'cold_start'),
       coalesce(sum(fpi_length), 0)
FROM pg_get_wal_records_info(:'cold_start', :'cold_end');

SELECT 1 / ((SELECT payload = repeat('d', 512) FROM storage_lab.wal_demo)
    AND (SELECT coalesce(sum(block_fpi_length), 0) > 0
         FROM pg_get_wal_block_info(:'cold_start', :'cold_end', false)
         WHERE relfilenode = pg_relation_filenode('storage_lab.wal_demo')
           AND reldatabase = (SELECT oid FROM pg_database WHERE datname = current_database())))::int AS wal_check;
