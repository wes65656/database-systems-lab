\set ON_ERROR_STOP on
\echo '=== Bloat: espaço ocupado, versões mortas e espaço reutilizável ==='
CREATE EXTENSION IF NOT EXISTS pgstattuple;
CREATE SCHEMA IF NOT EXISTS storage_lab;
DROP TABLE IF EXISTS storage_lab.bloat_demo;
CREATE TABLE storage_lab.bloat_demo (id integer, payload text)
WITH (autovacuum_enabled = false);

INSERT INTO storage_lab.bloat_demo
SELECT id, repeat(md5(id::text), 8) FROM generate_series(1, 20000) AS id;
SELECT 'initial' AS phase, table_len, tuple_count, dead_tuple_count, free_space
FROM pgstattuple('storage_lab.bloat_demo');

-- As linhas apagadas ficam espalhadas pelo heap, inclusive nas páginas do meio.
DELETE FROM storage_lab.bloat_demo WHERE id % 5 <> 0;
SELECT 'after delete' AS phase, table_len, tuple_count, dead_tuple_count, free_space
FROM pgstattuple('storage_lab.bloat_demo') \gset deleted_
\echo 'after delete' :deleted_table_len :deleted_tuple_count :deleted_dead_tuple_count :deleted_free_space

VACUUM (TRUNCATE FALSE, ANALYZE) storage_lab.bloat_demo;
SELECT 'after vacuum' AS phase, table_len, tuple_count, dead_tuple_count, free_space
FROM pgstattuple('storage_lab.bloat_demo') \gset vacuum_
\echo 'after vacuum' :vacuum_table_len :vacuum_tuple_count :vacuum_dead_tuple_count :vacuum_free_space

VACUUM FULL storage_lab.bloat_demo;
SELECT 'after vacuum full' AS phase, table_len, tuple_count, dead_tuple_count, free_space
FROM pgstattuple('storage_lab.bloat_demo');
SELECT 1 / (
    :deleted_dead_tuple_count = 16000
    AND :vacuum_dead_tuple_count = 0
    AND :vacuum_free_space > :deleted_free_space
    AND :vacuum_table_len = :deleted_table_len
    AND pg_relation_size('storage_lab.bloat_demo') < :vacuum_table_len
    AND (SELECT count(*) FROM storage_lab.bloat_demo) = 4000
)::int AS vacuum_check;
