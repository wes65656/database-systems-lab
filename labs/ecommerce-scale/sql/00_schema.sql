-- LAB INDEPENDENTE: e-commerce relacional, sem particionamento inicial.
-- Execute apenas no banco ecommerce_scale, nunca em bases de trabalho/produção.
\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS customers (
    id BIGINT PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
    id BIGINT PRIMARY KEY,
    category_id INTEGER NOT NULL REFERENCES categories(id),
    name TEXT NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS orders (
    id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(id),
    placed_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('paid', 'cancelled', 'pending'))
);

CREATE TABLE IF NOT EXISTS order_items (
    id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id),
    product_id BIGINT NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE IF NOT EXISTS payments (
    id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL UNIQUE REFERENCES orders(id),
    amount NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
    status TEXT NOT NULL CHECK (status IN ('captured', 'refunded', 'pending')),
    paid_at TIMESTAMPTZ NOT NULL
);

-- Intencionalmente sem índices adicionais nas FKs: o benchmark
-- de consultas mostrará o custo antes/depois de indexação.
\echo Esquema inicial pronto: seis tabelas, PKs, FKs e constraints.
