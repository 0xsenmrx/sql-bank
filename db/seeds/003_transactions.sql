INSERT INTO transactions (account_id, amount) VALUES
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'), 1000.00),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'), -50.00),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'EUR'), 1200.50),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'bob@example.com') AND currency = 'USD'), 250.00),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'charlie@example.com') AND currency = 'GBP'), 5000.00),
((SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'charlie@example.com') AND currency = 'GBP'), 5000.00);
