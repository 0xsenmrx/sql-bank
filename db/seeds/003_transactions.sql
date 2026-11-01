-- All timestamps are fixed (not relative to now()) so predictions never change
INSERT INTO transactions (account_id, amount, created_at) VALUES
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'), 1000.00, '2026-09-10 10:00:00+00'),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'),  -50.00, '2026-09-12 11:00:00+00'),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'EUR'), 1200.50, '2026-09-15 09:00:00+00'),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD'), 250.00, '2026-09-20 14:00:00+00'),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'charlie@example.com') AND currency = 'GBP'), 5000.00, '2026-09-25 16:00:00+00'),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'charlie@example.com') AND currency = 'GBP'), 5000.00, '2026-09-28 18:00:00+00');
