-- NOTE: These transactions change the net sums per account, so the
-- final UPDATE statements adjust accounts.balance to match. If you edit
-- the amounts here, you must also update the corresponding
-- accounts.balance UPDATE below. The reconciliation proof will catch
-- any mismatch.
--
-- Two transactions share the same timestamp ('2026-10-10 12:00:00')
-- to demonstrate the "peers" behavior in window functions.

-- Account 1 (Alice USD): October activity
INSERT INTO transactions (account_id, amount, created_at) VALUES
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'), -20.00, '2026-10-05 10:00:00+00'),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'), +30.00, '2026-10-20 15:00:00+00');

-- Account 1 (Alice USD): two peer transactions with the SAME timestamp
INSERT INTO transactions (account_id, amount, created_at) VALUES
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'), +15.00, '2026-10-10 12:00:00+00'),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'), -5.00,  '2026-10-10 12:00:00+00');

-- Account 1 (Alice USD): November activity
INSERT INTO transactions (account_id, amount, created_at) VALUES
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'), +70.00, '2026-11-03 09:00:00+00'),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'), -20.00, '2026-11-15 18:00:00+00');

-- Adjust Account 1's balance to match the new transactions.
-- Net change: -20 + 30 + 15 - 5 + 70 - 20 = +70
UPDATE accounts SET balance = balance + 70.00
WHERE id = (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD');
