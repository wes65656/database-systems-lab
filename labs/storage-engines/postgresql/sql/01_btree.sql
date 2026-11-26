\set ON_ERROR_STOP on
\echo '=== B-Tree: páginas e registros de split no WAL ==='
CREATE EXTENSION IF NOT EXISTS pageinspect;
CREATE EXTENSION IF NOT EXISTS pg_walinspect;
CREATE SCHEMA IF NOT EXISTS storage_lab;
DROP TABLE IF EXISTS storage_lab.btree_demo;
CREATE TABLE storage_lab.btree_demo (id integer NOT NULL);
CREATE UNIQUE INDEX btree_demo_id ON storage_lab.btree_demo (id);

SELECT level AS initial_level FROM bt_metap('storage_lab.btree_demo_id');
SELECT pg_current_wal_insert_lsn() AS start_lsn \gset
INSERT INTO storage_lab.btree_demo SELECT generate_series(1, 30000);
SELECT pg_current_wal_insert_lsn() AS end_lsn \gset
ANALYZE storage_lab.btree_demo;

SELECT level AS root_level FROM bt_metap('storage_lab.btree_demo_id');
SELECT type, count(*) AS pages, round(avg(free_size), 1) AS average_free_bytes
FROM bt_multi_page_stats('storage_lab.btree_demo_id', 1, -1)
GROUP BY type ORDER BY type;

SELECT record_type, count(*) AS wal_records
FROM pg_get_wal_records_info(:'start_lsn', :'end_lsn')
WHERE resource_manager = 'Btree' AND record_type LIKE 'SPLIT_%'
GROUP BY record_type ORDER BY record_type;

-- As inserções acima devem produzir splits e uma raiz acima das folhas.
SELECT 1 / (EXISTS (
  SELECT FROM pg_get_wal_records_info(:'start_lsn', :'end_lsn')
  WHERE resource_manager = 'Btree' AND record_type LIKE 'SPLIT_%'
) AND (SELECT level > 0 FROM bt_metap('storage_lab.btree_demo_id')))::int AS split_check;

EXPLAIN (ANALYZE, BUFFERS) SELECT id FROM storage_lab.btree_demo WHERE id = 15001;
