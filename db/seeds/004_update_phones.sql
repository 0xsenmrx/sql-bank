UPDATE customers SET phone = '555-0101' WHERE email = 'alice@example.com';
UPDATE customers SET phone = '555-0102' WHERE email = 'bob@example.com';
UPDATE customers SET phone = '555-0103' WHERE email = 'charlie@example.com';
-- Everyone else has a NULL phone!
