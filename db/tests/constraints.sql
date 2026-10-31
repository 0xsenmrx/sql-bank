BEGIN;

-- 1. FIXTURES: Create our own test data
DO $$
DECLARE
    v_cust_id bigint;
    v_acc_id bigint;
BEGIN
    INSERT INTO customers (email, full_name) VALUES ('test-fixture@example.com', 'Test Fixture') RETURNING id INTO v_cust_id;
    INSERT INTO accounts (customer_id, currency, balance) VALUES (v_cust_id, 'USD', 100.00) RETURNING id INTO v_acc_id;
    INSERT INTO transactions (account_id, amount) VALUES (v_acc_id, 10.00);
END $$;

-- 2. NOT NULL TESTS
DO $$ BEGIN
    INSERT INTO customers (email, full_name) VALUES (NULL, 'Test');
    RAISE EXCEPTION '❌ FAIL: Customer NULL email allowed.';
EXCEPTION WHEN not_null_violation THEN RAISE NOTICE '✅ PASS: Customer NULL email rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO customers (email, full_name) VALUES ('test@test.com', NULL);
    RAISE EXCEPTION '❌ FAIL: Customer NULL full_name allowed.';
EXCEPTION WHEN not_null_violation THEN RAISE NOTICE '✅ PASS: Customer NULL full_name rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO accounts (customer_id, currency, balance) VALUES (NULL, 'USD', 100);
    RAISE EXCEPTION '❌ FAIL: Account NULL customer_id allowed.';
EXCEPTION WHEN not_null_violation THEN RAISE NOTICE '✅ PASS: Account NULL customer_id rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO accounts (customer_id, currency, balance) VALUES (1, NULL, 100);
    RAISE EXCEPTION '❌ FAIL: Account NULL currency allowed.';
EXCEPTION WHEN not_null_violation THEN RAISE NOTICE '✅ PASS: Account NULL currency rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO transactions (account_id, amount) VALUES (NULL, 100);
    RAISE EXCEPTION '❌ FAIL: Transaction NULL account_id allowed.';
EXCEPTION WHEN not_null_violation THEN RAISE NOTICE '✅ PASS: Transaction NULL account_id rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO transactions (account_id, amount) VALUES (1, NULL);
    RAISE EXCEPTION '❌ FAIL: Transaction NULL amount allowed.';
EXCEPTION WHEN not_null_violation THEN RAISE NOTICE '✅ PASS: Transaction NULL amount rejected.';
END $$;

-- 3. UNIQUE & FORMAT TESTS
DO $$ BEGIN
    INSERT INTO customers (email, full_name) VALUES ('test-fixture@example.com', 'Duplicate');
    RAISE EXCEPTION '❌ FAIL: Duplicate email allowed.';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE '✅ PASS: Duplicate email rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO customers (email, full_name) VALUES ('TEST-FIXTURE@example.com', 'Duplicate Case');
    RAISE EXCEPTION '❌ FAIL: Case-insensitive duplicate email allowed.';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE '✅ PASS: Case-insensitive duplicate email rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO customers (email, full_name) VALUES ('empty@test.com', '');
    RAISE EXCEPTION '❌ FAIL: Empty full_name allowed.';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: Empty full_name rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO customers (email, full_name) VALUES ('whitespace@test.com', '   ');
    RAISE EXCEPTION '❌ FAIL: Whitespace full_name allowed.';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: Whitespace full_name rejected.';
END $$;

-- 4. CHECK CONSTRAINTS
DO $$ BEGIN
    INSERT INTO accounts (customer_id, currency, balance) VALUES (1, 'USD', -50.00);
    RAISE EXCEPTION '❌ FAIL: Negative balance allowed.';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: Negative balance rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO accounts (customer_id, currency, balance) VALUES (1, 'usd', 100);
    RAISE EXCEPTION '❌ FAIL: Lowercase currency allowed.';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: Lowercase currency rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO accounts (customer_id, currency, balance) VALUES (1, 'BANANA', 100);
    RAISE EXCEPTION '❌ FAIL: Non-currency text allowed.';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: Non-currency text rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO transactions (account_id, amount) VALUES (1, 0);
    RAISE EXCEPTION '❌ FAIL: Zero amount transaction allowed.';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: Zero amount transaction rejected.';
END $$;

-- 5. FOREIGN KEY CONSTRAINTS (Orphans)
DO $$ BEGIN
    INSERT INTO accounts (customer_id, currency, balance) VALUES (99999, 'USD', 100);
    RAISE EXCEPTION '❌ FAIL: Orphan account allowed.';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '✅ PASS: Orphan account rejected.';
END $$;

DO $$ BEGIN
    INSERT INTO transactions (account_id, amount) VALUES (99999, 100);
    RAISE EXCEPTION '❌ FAIL: Orphan transaction allowed.';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '✅ PASS: Orphan transaction rejected.';
END $$;

-- 6. ON DELETE RESTRICT TESTS
DO $$ BEGIN
    DELETE FROM customers WHERE email = 'test-fixture@example.com';
    RAISE EXCEPTION '❌ FAIL: Deleted customer with active accounts.';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '✅ PASS: Cannot delete customer with accounts.';
END $$;

DO $$ BEGIN
    DELETE FROM accounts WHERE currency = 'USD' AND customer_id = (SELECT id FROM customers WHERE email = 'test-fixture@example.com');
    RAISE EXCEPTION '❌ FAIL: Deleted account with transactions.';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE '✅ PASS: Cannot delete account with transactions.';
END $$;

-- 7. DEFAULT VALUE TESTS
DO $$
DECLARE
    v_balance numeric(19,4);
    v_created_at timestamptz;
    v_new_acc_id bigint;
BEGIN
    INSERT INTO accounts (customer_id, currency) 
    VALUES ((SELECT id FROM customers WHERE email = 'test-fixture@example.com'), 'GBP') 
    RETURNING id, balance, created_at INTO v_new_acc_id, v_balance, v_created_at;
    
    IF v_balance = 0 THEN 
        RAISE NOTICE '✅ PASS: Default balance is 0.';
    ELSE 
        RAISE EXCEPTION '❌ FAIL: Default balance was %, expected 0.', v_balance; 
    END IF;

    IF v_created_at IS NOT NULL AND v_created_at <= now() THEN 
        RAISE NOTICE '✅ PASS: Default created_at was populated.';
    ELSE 
        RAISE EXCEPTION '❌ FAIL: Default created_at was not populated.'; 
    END IF;
    
    DELETE FROM accounts WHERE id = v_new_acc_id;
END $$;

-- 8. BOUNDARY (POSITIVE) TESTS
DO $$ BEGIN
    -- Balance of exactly 0 should be allowed
    INSERT INTO accounts (customer_id, currency, balance)
    VALUES ((SELECT id FROM customers WHERE email = 'test-fixture@example.com'), 'USD', 0.00);
    RAISE NOTICE '✅ PASS: Zero balance accepted.';
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION '❌ FAIL: Zero balance rejected. Error: %', SQLERRM;
END $$;

DO $$ BEGIN
    -- Valid currency 'USD' should be allowed
    INSERT INTO accounts (customer_id, currency, balance)
    VALUES ((SELECT id FROM customers WHERE email = 'test-fixture@example.com'), 'USD', 10.00);
    RAISE NOTICE '✅ PASS: Valid currency accepted.';
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION '❌ FAIL: Valid currency rejected. Error: %', SQLERRM;
END $$;

ROLLBACK;
