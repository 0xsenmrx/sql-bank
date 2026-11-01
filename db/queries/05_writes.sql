BEGIN;

-- 1. Upsert Demo
-- prediction: It inserts 'upsert@test.com'. The second time it updates the name.
INSERT INTO customers (email, full_name) 
VALUES ('upsert@test.com', 'Original Name') 
ON CONFLICT (LOWER(email)) 
DO UPDATE SET full_name = EXCLUDED.full_name;

INSERT INTO customers (email, full_name) 
VALUES ('UPSERT@test.com', 'Updated Name') 
ON CONFLICT (LOWER(email)) 
DO UPDATE SET full_name = EXCLUDED.full_name;

-- Verify
SELECT email, full_name FROM customers WHERE LOWER(email) = 'upsert@test.com';

-- INSERT ... RETURNING demo
DO $$
DECLARE
    v_cust_id bigint;
    v_acc_id bigint;
BEGIN
    INSERT INTO customers (email, full_name)
    VALUES ('returning-demo@test.com', 'Returning Demo')
    RETURNING id INTO v_cust_id;

    INSERT INTO accounts (customer_id, currency, balance)
    VALUES (v_cust_id, 'USD', 500.00)
    RETURNING id INTO v_acc_id;

    RAISE NOTICE '✅ PASS: Created customer % and account %', v_cust_id, v_acc_id;
END $$;

-- Guarded withdrawal demo
DO $$
DECLARE
    v_new_balance numeric(19,4);
BEGIN
    -- Try to withdraw 999999 from account 1 (should fail)
    UPDATE accounts SET balance = balance - 999999
    WHERE id = 1 AND balance >= 999999
    RETURNING balance INTO v_new_balance;

    IF v_new_balance IS NULL THEN
        RAISE NOTICE '✅ PASS: Guarded withdrawal rejected (zero rows updated).';
    ELSE
        RAISE EXCEPTION '❌ FAIL: Allowed overdraft!';
    END IF;
END $$;

ROLLBACK;
