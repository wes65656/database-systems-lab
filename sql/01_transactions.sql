-- EXPERIMENTO 01: ACID / COMMIT / ROLLBACK / SAVEPOINT
-- Reinicia os saldos, apenas na base didática.
BEGIN;
UPDATE accounts SET balance = 1000.00 WHERE id = 1;
UPDATE accounts SET balance = 500.00 WHERE id = 2;
COMMIT;

SELECT 'ANTES' AS etapa, id, owner_name, balance FROM accounts ORDER BY id;

-- Transação confirmada: transferir 100 de Ana para Bruno.
BEGIN;
UPDATE accounts SET balance = balance - 100.00 WHERE id = 1 AND balance >= 100;
UPDATE accounts SET balance = balance + 100.00 WHERE id = 2;
COMMIT;

SELECT 'DEPOIS DO COMMIT' AS etapa, id, owner_name, balance FROM accounts ORDER BY id;

-- A próxima transação é cancelada: nenhum efeito deve persistir.
BEGIN;
UPDATE accounts SET balance = balance - 50.00 WHERE id = 1;
SAVEPOINT antes_credito;
UPDATE accounts SET balance = balance + 50.00 WHERE id = 2;
ROLLBACK TO SAVEPOINT antes_credito;
-- Neste ponto só o crédito foi revertido, mas o débito também será revertido.
SELECT 'DENTRO DA TRANSACAO' AS etapa, id, balance FROM accounts ORDER BY id;
ROLLBACK;

SELECT 'DEPOIS DO ROLLBACK' AS etapa, id, owner_name, balance FROM accounts ORDER BY id;

-- Em produção, verifique que o débito afetou uma linha e coloque
-- validações de negócio e crédito na mesma transação.
