-- Old Query 3: All 20 customers with their account count and total balance, including customers with none (LEFT JOIN plus COALESCE).
-- SELECT c.id, c.full_name, COUNT(a.id) as number_of_accounts, COALESCE(SUM(a.balance), 0)::numeric(19,4) as total_balance
-- FROM customers c
-- LEFT JOIN accounts a ON c.id = a.customer_id
-- GROUP BY c.id

-- Query 1: Q3 rewritten as a CTE pipeline
-- Prediction: 20 rows. Alice has 2 accounts (2150.50), Bob has 1 (250.00), Charlie 1 (10000.00), Diana 1 (0.00), Edward 1 (0.00). The other 15 have 0 accounts and 0.00 balance.
WITH account_aggregates AS (
	SELECT
		customer_id,
		COUNT(id) AS num_accounts,
		SUM(balance) AS total_balance
	FROM accounts
	GROUP BY customer_id
)
SELECT
	c.id,
	c.full_name,
	COALESCE(agg.num_accounts, 0) AS number_of_accounts,
	COALESCE(agg.total_balance, 0)::numeric(19,4) AS total_balance
FROM customers c
LEFT JOIN account_aggregates agg ON c.id = agg.customer_id
ORDER BY c.id;

-- Query 2: Fan-out fix with two CTEs
-- Prediction: 20 rows. Alice 2150.50/3 tx, Bob 250/1 tx, Charlie 10000/2 tx. Everyone else 0/0.
-- Note: This differs from the earlier fix which returned 5 rows because it used INNER JOIN.
-- This one uses LEFT JOIN from customers, so it includes all 20 customers.
WITH account_totals AS (
	SELECT customer_id, SUM(balance) AS total_balance
	FROM accounts
	GROUP BY customer_id
),
transaction_counts AS (
	SELECT a.customer_id, COUNT(t.id) AS num_transactions
	FROM transactions t
	JOIN accounts a ON a.id = t.account_id
	GROUP BY a.customer_id
)
SELECT c.full_name, COALESCE(totals.total_balance, 0)::numeric(19,4) AS total_balance, COALESCE(tc.num_transactions, 0) AS num_transactions
FROM customers c
LEFT JOIN account_totals totals ON totals.customer_id = c.id
LEFT JOIN transaction_counts tc ON tc.customer_id = c.id
ORDER BY c.id;

-- Query 3: The top five customers by total balance, using a CTE.
-- Prediction: 5 rows. Charlie (10000), Alice (2150.50), Bob (250), Diana (0), Edward (0). 
-- (Diana and Edward tie for 0, but ID is the tie-breaker, so Diana comes before Edward).
WITH account_totals AS (
    SELECT customer_id, SUM(balance) AS total_balance
    FROM accounts
    GROUP BY customer_id
)
SELECT c.full_name, COALESCE(totals.total_balance, 0)::numeric(19,4) AS total_balance
FROM customers c
LEFT JOIN account_totals totals ON c.id = totals.customer_id
ORDER BY total_balance DESC, c.id
LIMIT 5;

-- Query 4: Customers with no accounts (The NULL trap)
BEGIN;

CREATE TEMP TABLE t_accounts (customer_id bigint);
INSERT INTO t_accounts (customer_id) VALUES (1), (2), (NULL);

-- Method 1: NOT IN
-- Prediction: 0 rows (because of the NULL).
SELECT c.full_name 
FROM customers c 
WHERE c.id NOT IN (SELECT customer_id FROM t_accounts);

-- Method 2: NOT EXISTS
-- Prediction: 18 rows (it correctly ignores the NULL).
SELECT c.full_name 
FROM customers c 
WHERE NOT EXISTS (SELECT 1 FROM t_accounts t WHERE t.customer_id = c.id);

-- Method 3: LEFT JOIN ... IS NULL
-- Prediction: 18 rows.
SELECT c.full_name 
FROM customers c 
LEFT JOIN t_accounts t ON c.id = t.customer_id 
WHERE t.customer_id IS NULL;

ROLLBACK;

-- Query 5: A correlated subquery
-- Prediction: 6 rows. Accounts 1-4 have a timestamp. Accounts 5 and 6 return NULL.
SELECT 
    a.id AS account_id, 
    a.currency, 
    (SELECT MAX(t.created_at) FROM transactions t WHERE t.account_id = a.id) AS latest_transaction
FROM accounts a
ORDER BY a.id;

-- Proof Way 1: CTE on top, compare old vs new
WITH account_aggregates AS (
    SELECT customer_id, COUNT(id) AS num_accounts, SUM(balance) AS total_balance
    FROM accounts
    GROUP BY customer_id
),
old_query AS (
    SELECT c.id, c.full_name, COUNT(a.id) as num_accounts, COALESCE(SUM(a.balance), 0)::numeric(19,4) as total_balance
    FROM customers c
    LEFT JOIN accounts a ON c.id = a.customer_id
    GROUP BY c.id, c.full_name
),
new_query AS (
    SELECT c.id, c.full_name, COALESCE(agg.num_accounts, 0) AS num_accounts, COALESCE(agg.total_balance, 0)::numeric(19,4) AS total_balance
    FROM customers c
    LEFT JOIN account_aggregates agg ON c.id = agg.customer_id
)
SELECT * FROM old_query
EXCEPT ALL
SELECT * FROM new_query;

-- Proof Way 2: Parentheses

(
    WITH account_aggregates AS (
        SELECT customer_id, COUNT(id) AS num_accounts, SUM(balance) AS total_balance
        FROM accounts
        GROUP BY customer_id
    )
    SELECT c.id, c.full_name, COALESCE(agg.num_accounts, 0) AS num_accounts, COALESCE(agg.total_balance, 0)::numeric(19,4) AS total_balance
    FROM customers c
    LEFT JOIN account_aggregates agg ON c.id = agg.customer_id
)
EXCEPT ALL
(
    SELECT c.id, c.full_name, COUNT(a.id) as num_accounts, COALESCE(SUM(a.balance), 0)::numeric(19,4) as total_balance
    FROM customers c
    LEFT JOIN accounts a ON c.id = a.customer_id
    GROUP BY c.id, c.full_name
);

