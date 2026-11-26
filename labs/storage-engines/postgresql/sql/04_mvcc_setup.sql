\set ON_ERROR_STOP on
CREATE EXTENSION IF NOT EXISTS pgstattuple;
CREATE SCHEMA IF NOT EXISTS storage_lab;
DROP TABLE IF EXISTS storage_lab.mvcc_demo;
CREATE TABLE storage_lab.mvcc_demo (id integer PRIMARY KEY, balance integer)
WITH (autovacuum_enabled = false);
INSERT INTO storage_lab.mvcc_demo VALUES (1, 900);
