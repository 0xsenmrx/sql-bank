-- 1. All customers, ordered by full_name.
SELECT full_name, email FROM customers ORDER BY full_name;

-- 2. Customers whose email starts with “a”, case-insensitive.
SELECT id, email FROM customers WHERE email ILIKE 'a%';

-- 3. Accounts with a balance between 200 and 1500.
SELECT id, balance FROM accounts WHERE balance BETWEEN 200 AND 1500;

-- 4. Accounts in USD or EUR, using IN.
SELECT id, currency FROM accounts WHERE currency IN ('USD', 'EUR');

-- 5. The three accounts with the highest balance.
SELECT id, balance FROM accounts ORDER BY balance DESC, id LIMIT 3;

-- 6. Every currency in use, once each.
SELECT DISTINCT currency FROM accounts ORDER BY currency;

-- 7. Withdrawals (negative amounts), newest first.
SELECT id, amount, created_at FROM transactions WHERE amount < 0 ORDER BY created_at DESC, id DESC;

-- 8. Page 2 of the customers, with 5 per page and a stable order.
SELECT id, full_name FROM customers ORDER BY id LIMIT 5 OFFSET 5;

-- TRAP 1: What does this return?
-- Prediciton: It will most probably be empty, because = NULL doesnt work like that
SELECT id, full_name, phone FROM customers WHERE phone = NULL;

-- TRAP 2: What does this return?
-- Prediction: It will return all the ones that have different number, but are not NULL, again NULL is not compared like that 
SELECT id, full_name, phone FROM customers WHERE phone <> '555-0101';

-- TRAP 3: What does this return?
-- Prediction: This should work, because IS NULL is exactly for checking nullity
SELECT id, full_name, phone FROM customers WHERE phone IS NULL;

-- TRAP 4: What does this return?
-- Prediction: The coalesce will return the phone number, or if it is NULL it will return n/a
SELECT id, full_name, COALESCE(phone, 'n/a') AS phone_status FROM customers;

-- TRAP 5: What does this return?
-- Prediction: Distinct I believe will work not like <>, but also will account for the NULLs
SELECT id, full_name, phone FROM customers WHERE phone IS DISTINCT FROM '555-0101';

-- TRAP 6: What does this return?
-- Prediction: I am guessing it will work like <>A AND <>B, and the B will give false, so empty
SELECT id, full_name, phone FROM customers WHERE phone NOT IN ('555-0101', NULL);


