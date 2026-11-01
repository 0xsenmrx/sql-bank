-- db/demos/savepoint_demo.sql
\set ON_ERROR_STOP off

BEGIN;
INSERT INTO customers (email, full_name) VALUES ('demo-savepoint@test.com', 'Demo Savepoint');

SAVEPOINT my_savepoint;

-- This will fail and ABORT the transaction
INSERT INTO accounts (customer_id, currency, balance) 
VALUES ((SELECT id FROM customers WHERE email = 'demo-savepoint@test.com'), 'USD', -50.00);
-- ERROR: new row violates check constraint "chk_accounts_balance_nonneg"

-- Prove the transaction is aborted. This SELECT will also fail!
SELECT 'This will fail' AS status;
-- ERROR: current transaction is aborted...

-- Revive the transaction
ROLLBACK TO SAVEPOINT my_savepoint;

-- Now the transaction works again
SELECT 'It works!' AS status;

ROLLBACK;
\set ON_ERROR_STOP on
