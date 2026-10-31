CREATE TABLE accounts (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    currency text NOT NULL,
    balance numeric(19,4) NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_accounts_balance_nonneg CHECK (balance >= 0),
    CONSTRAINT chk_accounts_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);
