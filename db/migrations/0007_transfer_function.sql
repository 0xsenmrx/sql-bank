CREATE OR REPLACE FUNCTION transfer_funds(
    p_from_id bigint, 
    p_to_id bigint, 
    p_amount numeric
) RETURNS void AS $$
DECLARE
    v_transfer_id uuid := gen_random_uuid();
    v_sender_balance numeric(19,4);
    v_from_currency text;
    v_to_currency text;
    v_lower_id bigint;
    v_higher_id bigint;
BEGIN
    -- 1. NULL Guards
    IF p_from_id IS NULL OR p_to_id IS NULL OR p_amount IS NULL THEN
        RAISE EXCEPTION 'Arguments cannot be NULL';
    END IF;

    -- 2. Basic Guards
    IF p_from_id = p_to_id THEN RAISE EXCEPTION 'Cannot transfer to same account'; END IF;
    IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;
    IF p_amount != ROUND(p_amount, 4) THEN RAISE EXCEPTION 'Amount must have at most 4 decimal places'; END IF;

    -- 3. Locking
    v_lower_id := LEAST(p_from_id, p_to_id);
    v_higher_id := GREATEST(p_from_id, p_to_id);
    PERFORM id FROM accounts WHERE id = v_lower_id FOR UPDATE;
    PERFORM id FROM accounts WHERE id = v_higher_id FOR UPDATE;

    -- 4. Currency check
    SELECT currency INTO v_from_currency FROM accounts WHERE id = p_from_id;
    SELECT currency INTO v_to_currency FROM accounts WHERE id = p_to_id;
    IF v_from_currency IS NULL THEN RAISE EXCEPTION 'Sender account % not found', p_from_id; END IF;
    IF v_to_currency IS NULL THEN RAISE EXCEPTION 'Receiver account % not found', p_to_id; END IF;
    IF v_from_currency != v_to_currency THEN
        RAISE EXCEPTION 'Currency mismatch: % -> %', v_from_currency, v_to_currency;
    END IF;

    -- 5. Guarded update (sender)
    UPDATE accounts SET balance = balance - p_amount
    WHERE id = p_from_id AND balance >= p_amount
    RETURNING balance INTO v_sender_balance;
    IF v_sender_balance IS NULL THEN RAISE EXCEPTION 'Insufficient funds'; END IF;

    -- 6. Update receiver
    UPDATE accounts SET balance = balance + p_amount WHERE id = p_to_id;

    -- 7. Transactions
    INSERT INTO transactions (account_id, amount, transfer_id) VALUES (p_from_id, -p_amount, v_transfer_id);
    INSERT INTO transactions (account_id, amount, transfer_id) VALUES (p_to_id, p_amount, v_transfer_id);
END;
$$ LANGUAGE plpgsql;
