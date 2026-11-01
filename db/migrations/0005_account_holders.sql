CREATE TABLE account_holders (
    account_id bigint NOT NULL,
    customer_id bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),

    -- We name the constraints so our tests can check them!
    CONSTRAINT pk_account_holders PRIMARY KEY (account_id, customer_id),
    CONSTRAINT fk_account_holders_account FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CONSTRAINT fk_account_holders_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE RESTRICT
);

-- THE BACKFILL: Copy existing owners so we don't lose them.
INSERT INTO account_holders (account_id, customer_id)
SELECT id, customer_id FROM accounts;
