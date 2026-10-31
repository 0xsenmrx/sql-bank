INSERT INTO accounts (customer_id, currency, balance) VALUES
((SELECT id FROM customers WHERE email = 'alice@example.com'), 'USD', 950.00),
((SELECT id FROM customers WHERE email = 'alice@example.com'), 'EUR', 1200.50),
((SELECT id FROM customers WHERE email = 'bob@example.com'), 'USD', 250.00),
((SELECT id FROM customers WHERE email = 'charlie@example.com'), 'GBP', 10000.00),
((SELECT id FROM customers WHERE email = 'diana@example.com'), 'USD', 0.00),
((SELECT id FROM customers WHERE email = 'edward@example.com'), 'USD', 0.00);
