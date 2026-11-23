-- EXPERIMENTO 03: padrões de concorrência.
-- Transações revertidas para preservar o estoque didático.
-- O console C# executa a disputa simultânea.

-- Lock pessimista:
BEGIN;
SELECT id, stock, version FROM products WHERE id = 1 FOR UPDATE;
UPDATE products SET stock = stock - 1, version = version + 1
WHERE id = 1 AND stock > 0 RETURNING id, stock, version;
ROLLBACK;

-- Atualização condicional atômica:
BEGIN;
UPDATE products SET stock = stock - 1, version = version + 1
WHERE id = 1 AND stock > 0 RETURNING id, stock, version;
ROLLBACK;

-- Token de concorrência otimista:
BEGIN;
UPDATE products SET name = 'Caneca editada', version = version + 1
WHERE id = 1 AND version = 1 RETURNING id, version;
ROLLBACK;
