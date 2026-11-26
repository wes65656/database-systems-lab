\set ON_ERROR_STOP on
BEGIN;
UPDATE storage_lab.mvcc_demo SET balance = 1000 WHERE id = 1;
COMMIT;
SELECT balance FROM storage_lab.mvcc_demo WHERE id = 1;
VACUUM (VERBOSE, TRUNCATE FALSE) storage_lab.mvcc_demo;
