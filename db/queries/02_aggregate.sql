-- Query 1: Total balance per customer, grouped on accounts.customer_id.
-- Predicted: 5 rows (1,2150.5000),(2,250),(3,10000),(4,0),(5,0)         
-- What changed after running: I noticed the IDs are not ordered, but random, so I added order by
SELECT customer_id, SUM(balance) as total_balance FROM accounts
GROUP BY customer_id
ORDER BY customer_id;

-- Query 2: Number of accounts per currency.
-- Predicted: 3 rows ('GBP', 1) ('EUR', 1) ('USD', 4)
SELECT currency, COUNT(*) as number_of_accounts FROM accounts
GROUP BY currency
ORDER BY number_of_accounts, currency;

-- Query 3: Average, minimum and maximum balance per currency.
-- Predicted:
--  currency |    max     |    min     |     avg
-- ----------+------------+------------+-------------
--  EUR      |  1200.5000 |  1200.5000 |  1200.5000
--  GBP      | 10000.0000 | 10000.0000 | 10000.0000
--  USD      |   950.0000 |     0.0000 |   300.0000
-- What changed after running: I noticed the AVG keeps too many numbers after the . and decided to keep 4
SELECT currency, MAX(balance) as max_balance, MIN(balance) as min_balance, ROUND(AVG(balance), 4) as avg_balance FROM accounts
GROUP BY currency
ORDER BY currency;

-- Query 4: Total transaction amount per account, per month, using date_trunc('month', created_at).
-- Predicted: 
--  account_id | tx_month |    sum
-- ------------+----------+------------
--           1 |       11 |   950.0000
--           2 |       11 |  1200.5000
--           3 |       11 |   250.0000
--           4 |       11 | 10000.0000
-- What changed after running: I noticed the tx_month format is different than I expected, but still works
SELECT account_id, date_trunc('month', created_at AT TIME ZONE 'UTC') as tx_month, SUM(amount) as total_amount FROM transactions
GROUP BY account_id, date_trunc('month', created_at AT TIME ZONE 'UTC')
ORDER BY account_id, tx_month;

-- Query 5: Accounts with more than one transaction, using HAVING.
-- Predicted:
--  account_id | count
-- ------------+-------
--           1 |     2
--           4 |     2
SELECT account_id, COUNT(*) as number_of_transactions FROM transactions
GROUP BY account_id HAVING COUNT(*) > 1
ORDER BY account_id;

-- Query 6: How COUNT(*) and COUNT(phone) differ on customers.
-- Prediction: 1 row, where the first count will just give the number of all customers, and the phone will return only non null ones
--  total_customers | phones_provided
-- -----------------+-----------------
--               20 |               3
SELECT COUNT(*) AS total_customers, COUNT(phone) AS phones_provided FROM customers;

-- Query 7: Deposits and withdrawals counted in one query, using FILTER.
-- Prediction: 
--  account_id | deposits | withdrawals
-- ------------+----------+-------------
--           1 |        1 |           1
--           2 |        1 |           0
--           3 |        1 |           0
--           4 |        2 |           0
SELECT 
	account_id,
	COUNT(*) FILTER (WHERE amount > 0) as deposits,
	COUNT(*) FILTER (WHERE amount < 0) as withdrawals
FROM transactions
GROUP BY account_id
ORDER BY account_id;
