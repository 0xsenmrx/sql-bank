-- db/tests/transfer.sql
-- Proof for Module 6

BEGIN;

-- Snapshot the total balance before any transfer
CREATE TEMP TABLE initial_sum AS SELECT SUM(balance) AS total FROM accounts;

-- ==========================================
-- 1. NORMAL TRANSFER
-- ==========================================
DO $$
DECLARE
    v_alice_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
    v_bob_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD');
    v_alice_before numeric;
    v_bob_before numeric;
    v_alice_after numeric;
    v_bob_after numeric;
BEGIN
    SELECT balance INTO v_alice_before FROM accounts WHERE id = v_alice_id;
    SELECT balance INTO v_bob_before FROM accounts WHERE id = v_bob_id;

    PERFORM transfer_funds(v_alice_id, v_bob_id, 50.00);

    SELECT balance INTO v_alice_after FROM accounts WHERE id = v_alice_id;
    SELECT balance INTO v_bob_after FROM accounts WHERE id = v_bob_id;

    IF v_alice_after = v_alice_before - 50.00
       AND v_bob_after = v_bob_before + 50.00 THEN
        RAISE NOTICE '✅ PASS: Exact amount moved (Alice: % -> %, Bob: % -> %)',
            v_alice_before, v_alice_after, v_bob_before, v_bob_after;
    ELSE
        RAISE EXCEPTION '❌ FAIL: Balances wrong (Alice: % -> %, Bob: % -> %)',
            v_alice_before, v_alice_after, v_bob_before, v_bob_after;
    END IF;
END $$;

-- ==========================================
-- 2. INSUFFICIENT FUNDS
-- ==========================================
DO $$
DECLARE
    v_alice_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
    v_bob_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD');
    v_failed boolean := false;
BEGIN
    BEGIN
        PERFORM transfer_funds(v_bob_id, v_alice_id, 999999.00);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Insufficient funds%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;

    IF NOT v_failed THEN
        RAISE EXCEPTION '❌ FAIL: Allowed overdraft.';
    END IF;
    RAISE NOTICE '✅ PASS: Insufficient funds rejected correctly.';
END $$;

-- ==========================================
-- 3. REJECT SAME ACCOUNT
-- ==========================================
DO $$
DECLARE
    v_alice_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
    v_failed boolean := false;
BEGIN
    BEGIN
        PERFORM transfer_funds(v_alice_id, v_alice_id, 10.00);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Cannot transfer to same account%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;

    IF NOT v_failed THEN
        RAISE EXCEPTION '❌ FAIL: Allowed same account transfer.';
    END IF;
    RAISE NOTICE '✅ PASS: Same account rejected correctly.';
END $$;

-- ==========================================
-- 4. REJECT ZERO / NEGATIVE
-- ==========================================
DO $$
DECLARE
    v_alice_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
    v_bob_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD');
    v_failed boolean := false;
BEGIN
    BEGIN
        PERFORM transfer_funds(v_alice_id, v_bob_id, 0);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Amount must be positive%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION '❌ FAIL: Allowed zero amount.'; END IF;
    RAISE NOTICE '✅ PASS: Zero amount rejected correctly.';
END $$;

DO $$
DECLARE
    v_alice_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
    v_bob_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD');
    v_failed boolean := false;
BEGIN
    BEGIN
        PERFORM transfer_funds(v_alice_id, v_bob_id, -50.00);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Amount must be positive%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION '❌ FAIL: Allowed negative amount.'; END IF;
    RAISE NOTICE '✅ PASS: Negative amount rejected correctly.';
END $$;

-- ==========================================
-- 5. NORMAL TRANSFER CREATES TWO ROWS
-- ==========================================
DO $$
DECLARE
    v_transfer_id uuid;
    v_pos_count int;
    v_neg_count int;
BEGIN
    SELECT transfer_id INTO v_transfer_id FROM transactions WHERE transfer_id IS NOT NULL ORDER BY id DESC LIMIT 1;

    SELECT COUNT(*) INTO v_pos_count FROM transactions WHERE transfer_id = v_transfer_id AND amount > 0;
    SELECT COUNT(*) INTO v_neg_count FROM transactions WHERE transfer_id = v_transfer_id AND amount < 0;

    IF v_pos_count = 1 AND v_neg_count = 1 THEN
        RAISE NOTICE '✅ PASS: Transfer has one positive and one negative row.';
    ELSE
        RAISE EXCEPTION '❌ FAIL: Signs wrong (pos: %, neg: %)', v_pos_count, v_neg_count;
    END IF;
END $$;

-- ==========================================
-- 6. FULL BALANCE TRANSFER
-- ==========================================
DO $$
DECLARE
    v_alice_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
    v_bob_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD');
    v_balance numeric(19,4);
BEGIN
    SELECT balance INTO v_balance FROM accounts WHERE id = v_alice_id;
    PERFORM transfer_funds(v_alice_id, v_bob_id, v_balance);

    SELECT balance INTO v_balance FROM accounts WHERE id = v_alice_id;
    IF v_balance = 0 THEN
        RAISE NOTICE '✅ PASS: Transferred full balance, result is 0.';
    ELSE
        RAISE EXCEPTION '❌ FAIL: Expected 0, got %', v_balance;
    END IF;
END $$;

-- ==========================================
-- 7. FAILED TRANSFER LEAVES NO PARTIAL CHANGES
-- ==========================================
DO $$
DECLARE
    v_alice_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
    v_bob_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD');
    v_count_before bigint;
    v_alice_bal numeric;
    v_bob_bal numeric;
    v_failed boolean := false;
BEGIN
    SELECT balance INTO v_alice_bal FROM accounts WHERE id = v_alice_id;
    SELECT balance INTO v_bob_bal FROM accounts WHERE id = v_bob_id;
    SELECT COUNT(*) INTO v_count_before FROM transactions;

    BEGIN
        PERFORM transfer_funds(v_alice_id, v_bob_id, 999999.00);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Insufficient funds%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;

    IF NOT v_failed THEN
        RAISE EXCEPTION '❌ FAIL: Allowed overdraft.';
    END IF;

    IF (SELECT balance FROM accounts WHERE id = v_alice_id) = v_alice_bal
       AND (SELECT balance FROM accounts WHERE id = v_bob_id) = v_bob_bal
       AND (SELECT COUNT(*) FROM transactions) = v_count_before THEN
        RAISE NOTICE '✅ PASS: Failed transfer changed nothing.';
    ELSE
        RAISE EXCEPTION '❌ FAIL: Partial change detected!';
    END IF;
END $$;

-- ==========================================
-- 8. GUARD TESTS
-- ==========================================
DO $$
DECLARE
    v_failed boolean := false;
BEGIN
    BEGIN
        PERFORM transfer_funds(NULL, 1, 10.00);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Arguments cannot be NULL%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION '❌ FAIL: NULL allowed.'; END IF;
    RAISE NOTICE '✅ PASS: NULL from_id rejected.';
END $$;

DO $$
DECLARE
    v_alice_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
    v_bob_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD');
    v_failed boolean := false;
BEGIN
    BEGIN
        PERFORM transfer_funds(v_alice_id, v_bob_id, 10.00005);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Amount must have at most 4 decimal places%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION '❌ FAIL: >4 decimals allowed.'; END IF;
    RAISE NOTICE '✅ PASS: >4 decimals rejected.';
END $$;

DO $$
DECLARE
    v_usd_id bigint := (SELECT id FROM accounts WHERE currency = 'USD' LIMIT 1);
    v_eur_id bigint := (SELECT id FROM accounts WHERE currency = 'EUR' LIMIT 1);
    v_failed boolean := false;
BEGIN
    BEGIN
        PERFORM transfer_funds(v_usd_id, v_eur_id, 10.00);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Currency mismatch%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION '❌ FAIL: Currency mismatch allowed.'; END IF;
    RAISE NOTICE '✅ PASS: Currency mismatch rejected.';
END $$;

DO $$
DECLARE
    v_failed boolean := false;
BEGIN
    BEGIN
        PERFORM transfer_funds(999999, 1, 10.00);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Sender account 999999 not found%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION '❌ FAIL: Missing sender allowed.'; END IF;
    RAISE NOTICE '✅ PASS: Missing sender rejected.';
END $$;

-- Receiver account not found
DO $$
DECLARE
    v_usd_id bigint := (SELECT id FROM accounts WHERE currency = 'USD' LIMIT 1);
    v_failed boolean := false;
BEGIN
    BEGIN
        PERFORM transfer_funds(v_usd_id, 999999, 10.00);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Receiver account 999999 not found%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION '❌ FAIL: Missing receiver allowed.'; END IF;
    RAISE NOTICE '✅ PASS: Missing receiver rejected.';
END $$;

-- NULL amount
DO $$
DECLARE
    v_alice_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
    v_bob_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD');
    v_failed boolean := false;
BEGIN
    BEGIN
        PERFORM transfer_funds(v_alice_id, v_bob_id, NULL);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Arguments cannot be NULL%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;
    IF NOT v_failed THEN RAISE EXCEPTION '❌ FAIL: NULL amount allowed.'; END IF;
    RAISE NOTICE '✅ PASS: NULL amount rejected.';
END $$;

-- ==========================================
-- 9. ATOMICITY: FAILURE AFTER DEBIT
-- ==========================================
CREATE OR REPLACE FUNCTION fail_on_transaction() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'Simulated power failure';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER test_fail_trigger
BEFORE INSERT ON transactions
FOR EACH ROW EXECUTE FUNCTION fail_on_transaction();

DO $$
DECLARE
    v_alice_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
    v_bob_id bigint := (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD');
    v_alice_before numeric;
    v_bob_before numeric;
    v_alice_after numeric;
    v_bob_after numeric;
    v_count_before bigint;
    v_count_after bigint;
    v_failed boolean := false;
BEGIN
    SELECT balance INTO v_alice_before FROM accounts WHERE id = v_alice_id;
    SELECT balance INTO v_bob_before FROM accounts WHERE id = v_bob_id;
    SELECT COUNT(*) INTO v_count_before FROM transactions;

    -- Bob sends to Alice (Bob has money at this point, Alice may be at 0)
    BEGIN
        PERFORM transfer_funds(v_bob_id, v_alice_id, 10.00);
    EXCEPTION WHEN OTHERS THEN
        v_failed := true;
        IF SQLERRM NOT LIKE 'Simulated power failure%' THEN
            RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
        END IF;
    END;

    IF NOT v_failed THEN
        RAISE EXCEPTION '❌ FAIL: Expected the trigger to abort the transfer.';
    END IF;

    SELECT balance INTO v_alice_after FROM accounts WHERE id = v_alice_id;
    SELECT balance INTO v_bob_after FROM accounts WHERE id = v_bob_id;
    SELECT COUNT(*) INTO v_count_after FROM transactions;

    IF v_alice_before = v_alice_after
       AND v_bob_before = v_bob_after
       AND v_count_before = v_count_after THEN
        RAISE NOTICE '✅ PASS: Atomicity holds. Debit and credit rolled back after trigger failure.';
    ELSE
        RAISE EXCEPTION '❌ FAIL: Partial change detected! (Alice: % -> %, Bob: % -> %, rows: % -> %)',
            v_alice_before, v_alice_after, v_bob_before, v_bob_after, v_count_before, v_count_after;
    END IF;
END $$;

DROP TRIGGER test_fail_trigger ON transactions;
DROP FUNCTION fail_on_transaction();

-- ==========================================
-- 10. INVARIANT: SUM OF BALANCES UNCHANGED
-- ==========================================
DO $$
DECLARE
    v_initial numeric;
    v_current numeric;
BEGIN
    SELECT total INTO v_initial FROM initial_sum;
    SELECT SUM(balance) INTO v_current FROM accounts;
    IF v_initial = v_current THEN
        RAISE NOTICE '✅ PASS: Total balance unchanged (%).', v_current;
    ELSE
        RAISE EXCEPTION '❌ FAIL: Total balance changed! (% -> %)', v_initial, v_current;
    END IF;
END $$;

-- ==========================================
-- 11. INVARIANT: EVERY ACCOUNT RECONCILES
-- ==========================================
DO $$
DECLARE
    v_count int;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM (
        SELECT a.id
        FROM accounts a
        LEFT JOIN transactions t ON a.id = t.account_id
        GROUP BY a.id, a.balance
        HAVING a.balance != COALESCE(SUM(t.amount), 0)
    ) AS bad_accounts;

    IF v_count = 0 THEN
        RAISE NOTICE '✅ PASS: All accounts reconcile with transactions.';
    ELSE
        RAISE EXCEPTION '❌ FAIL: % accounts do not reconcile.', v_count;
    END IF;
END $$;

ROLLBACK;
