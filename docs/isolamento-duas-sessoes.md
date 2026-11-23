# Experimento 02 — Isolamento com duas sessões

Objetivo: demonstrar uma **non-repeatable read** com `READ COMMITTED`, e como `REPEATABLE READ` preserva o snapshot no PostgreSQL.

Execute `sql/00_schema.sql` primeiro. Abra **dois terminais**, A e B, com:

```powershell
docker compose exec db psql -U lab -d database_lab
```

## READ COMMITTED

1. No terminal A, execute:

```sql
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE id = 1;
```

2. Enquanto A está aberta, no terminal B:

```sql
BEGIN;
UPDATE accounts SET balance = balance + 10 WHERE id = 1;
COMMIT;
```

3. Volte ao terminal A:

```sql
SELECT balance FROM accounts WHERE id = 1;
COMMIT;
```

A segunda leitura observa o novo valor confirmado no terminal B.

## REPEATABLE READ

1. No terminal A:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE id = 1;
```

2. No terminal B:

```sql
BEGIN;
UPDATE accounts SET balance = balance + 10 WHERE id = 1;
COMMIT;
```

3. No terminal A:

```sql
SELECT balance FROM accounts WHERE id = 1;
COMMIT;
SELECT balance FROM accounts WHERE id = 1;
```

As leituras **dentro** da transação A são iguais; depois do `COMMIT`, a próxima leitura observa o valor atualizado.

## Próximos assuntos

- `SERIALIZABLE` e retry após erro `40001`
- Lost update, phantom read e write skew
- `SELECT ... FOR UPDATE` e contenção real entre transações

Referência: https://www.postgresql.org/docs/current/transaction-iso.html
