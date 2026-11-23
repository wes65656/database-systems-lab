-- Banco didático. Execute uma vez ou repita sem apagar seus dados.
-- docker compose exec db psql -U lab -d database_lab -v ON_ERROR_STOP=1 -f /lab/sql/00_schema.sql

CREATE TABLE IF NOT EXISTS accounts (
    id INT PRIMARY KEY,
    owner_name TEXT NOT NULL,
    balance NUMERIC(12, 2) NOT NULL CHECK (balance >= 0)
);

INSERT INTO accounts (id, owner_name, balance) VALUES
    (1, 'Ana', 1000.00),
    (2, 'Bruno', 500.00)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS products (
    id INT PRIMARY KEY,
    name TEXT NOT NULL,
    stock INT NOT NULL CHECK (stock >= 0),
    version INT NOT NULL DEFAULT 1 CHECK (version > 0)
);

INSERT INTO products (id, name, stock, version)
VALUES (1, 'Última caneca', 1, 1)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS purchases (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

SELECT 'schema pronto' AS status;
