CREATE TABLE customers (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email text NOT NULL,
    full_name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_customers_full_name_not_empty CHECK (btrim(full_name) <> '')
);

-- Case-insensitive email uniqueness
CREATE UNIQUE INDEX uq_customers_email_lower ON customers (LOWER(email));
