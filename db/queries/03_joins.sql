-- Query 1: Each transaction with its account’s currency and the owner’s full name (three tables).
-- Prediction: 6 rows
--   full_name   | currency |  amount
-----------------+----------+-----------
-- Alice Smith   | USD      | 1000.0000
-- Alice Smith   | USD      |  -50.0000
-- Alice Smith   | EUR      | 1200.5000
-- Bob Jones     | USD      |  250.0000
-- Charlie Brown | GBP      | 5000.0000
-- Charlie Brown | GBP      | 5000.0000
-- Results: My prediction is a bit wrong, because I did not follow ORDER BY there.
SELECT c.full_name, a.currency, t.amount
FROM transactions t
JOIN accounts a ON t.account_id = a.id
JOIN customers c ON a.customer_id = c.id
ORDER BY t.created_at DESC, t.id DESC;

-- Query 2: Customers with no accounts, written twice: with LEFT JOIN ... IS NULL and with NOT EXISTS. Do the results match?
-- Prediction: Both methods should give the same answer, and the answer should be 15

-- Method 1: LEFT JOIN
SELECT c.full_name
FROM customers c
LEFT JOIN accounts a ON c.id = a.customer_id
WHERE a.id IS NULL
ORDER BY c.full_name;

-- Method 2: NOT EXISTS
SELECT c.full_name
FROM customers c
WHERE NOT EXISTS (
	SELECT 1 FROM accounts a WHERE a.customer_id = c.id	
)
ORDER BY c.full_name;

-- Query 3: All 20 customers with their account count and total balance, including customers with none (LEFT JOIN plus COALESCE).
-- Prediction we should get all 20 customers with their account count (or 0 if none) and with the total balance (0 if no account)
SELECT c.id, c.full_name, COUNT(a.id) as number_of_accounts, COALESCE(SUM(a.balance), 0)::numeric(19,4) as total_balance
FROM customers c
LEFT JOIN accounts a ON c.id = a.customer_id
GROUP BY c.id
ORDER BY c.id;

-- Query 4: Accounts with no transactions.
-- Prediction: 2 rows, the accounts with id 5 and 6
SELECT a.id, c.full_name
FROM accounts a
JOIN customers c ON a.customer_id = c.id
LEFT JOIN transactions t ON t.account_id = a.id
WHERE t.id IS NULL;

-- Query 5: A new migration 0004_account_holders.sql: a many-to-many table account_holders (account_id, customer_id) with a composite primary key and foreign keys. Seed one joint account and write a query listing each account with all its holders’ names in one row (string_agg).
-- Preciction: We take the account join with the new table, then join the customers based on that new table and finally use string_agg to connect the names, it should be 6 rows. Account 1 will be 'Alice Smith, Bob Jones'
-- Note: I noticed that we still have customer_id in the accounts table, which I believe should be deleted, but will be left here just for the learning track, it doesnt yet give any problems
SELECT
	a.id AS account_id,
	STRING_AGG(c.full_name, ', ' ORDER BY c.full_name) as holders
FROM accounts a
JOIN account_holders ah ON a.id = ah.account_id
JOIN customers c ON ah.customer_id = c.id
GROUP BY a.id
ORDER BY a.id;

-- Query 6: A self-join: pairs of different accounts with the same currency, each pair once (a.id < b.id).
-- Prediction: Here we have 4 accounts with USD 1 with EUR and 1 with something else, so the only pair would be in USD, that is 4*3/2=6 pairs
SELECT
	a.currency AS currency,
	a.id AS first_account_id,
	b.id AS second_account_id
FROM accounts a
JOIN accounts b ON a.currency = b.currency AND a.id < b.id
ORDER BY a.id, b.id;

-- Query 7: The Fan-Out Trap
-- Prediction: 3 rows.
-- Alice shows 3100.50 instead of 2150.50 (2 transactions on USD).
-- Charlie shows 20000 instead of 10000 (2 transactions on GBP).
-- Bob shows 250.
-- Diana and Edward vanish because their accounts have no transactions.
SELECT c.full_name, SUM(a.balance) AS fan_out_total
FROM customers c
JOIN accounts a ON c.id = a.customer_id
JOIN transactions t ON a.id = t.account_id
GROUP BY c.id, c.full_name
ORDER BY c.id;

-- The Fix: Pre-aggregate transactions first, then join
WITH tx_counts AS (
    SELECT account_id, COUNT(*) AS num_transactions
    FROM transactions
    GROUP BY account_id
)
SELECT
    c.full_name,
    SUM(a.balance) AS real_balance,
    SUM(COALESCE(tx.num_transactions, 0)) AS total_transactions
FROM customers c
JOIN accounts a ON c.id = a.customer_id
LEFT JOIN tx_counts tx ON a.id = tx.account_id
GROUP BY c.id, c.full_name
ORDER BY c.id;

-- Query 8: every customer with the count of their USD accounts.
-- Method 1: Filter in the ON clause
-- predicted: 20 rows. Most will have 0 USD accounts.
SELECT c.full_name, COUNT(a.id) AS usd_accounts
FROM customers c
LEFT JOIN accounts a ON c.id = a.customer_id AND a.currency = 'USD'
GROUP BY c.id, c.full_name
ORDER BY c.id;

-- Method 2: Filter in the WHERE clause
-- predicted: 4 rows. Only customers who actually have USD accounts.
SELECT c.full_name, COUNT(a.id) AS usd_accounts
FROM customers c
LEFT JOIN accounts a ON c.id = a.customer_id
WHERE a.currency = 'USD'
GROUP BY c.id, c.full_name
ORDER BY c.id;
