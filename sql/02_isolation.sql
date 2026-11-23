-- EXPERIMENTO 02: níveis de isolamento.
-- Consulte docs/isolamento-duas-sessoes.md para observar concorrência real.
SHOW default_transaction_isolation;
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT id, balance FROM accounts WHERE id = 1;
COMMIT;

BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT id, balance FROM accounts WHERE id = 1;
COMMIT;

-- No PostgreSQL, READ UNCOMMITTED comporta-se como READ COMMITTED.
-- SERIALIZABLE pode precisar repetir transações que recebam erro 40001.
