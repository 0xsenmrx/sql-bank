-- ==========================================
-- Task 1: Running balance per account over time
-- Prediction for Account 1 (USD):
--   Sep 10 +1000 → 1000
--   Sep 12 -50   → 950
--   Oct 5  -20   → 930
--   Oct 10 +15   → 945
--   Oct 10 -5    → 940
--   Oct 20 +30   → 970
--   Nov 3  +70   → 1040
--   Nov 15 -20   → 1020
-- Account 2: single transaction → 1200.50
-- Account 3: single transaction → 250
-- Account 4: two transactions → 5000, 10000
-- ==========================================
SELECT account_id, created_at, id, amount,
       SUM(amount) OVER (PARTITION BY account_id ORDER BY created_at, id) AS running_balance
FROM transactions
ORDER BY account_id, created_at, id;

-- ==========================================
-- Task 1b: The peers trap — WITHOUT ", id" tie-breaker
-- Prediction: the two 2026-10-10 transactions are peers (same created_at).
--   Both show the same running balance: 940 (930 + 15 - 5).
--   In Task 1 (with ", id"), they advanced one at a time: 945 then 940.
-- ==========================================
SELECT account_id, created_at, id, amount,
       SUM(amount) OVER (PARTITION BY account_id ORDER BY created_at) AS running_balance
FROM transactions
ORDER BY account_id, created_at;

-- ==========================================
-- Task 2: Latest transaction per account (ROW_NUMBER)
-- Prediction: 4 rows (one per account).
--   Account 1 → id from Nov 15
--   Account 2 → id from Sep 15
--   Account 3 → id from Sep 20
--   Account 4 → id from Sep 28
-- ==========================================
WITH numbered AS (
    SELECT account_id, id, amount, created_at,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY created_at DESC, id DESC) AS rn
    FROM transactions
)
SELECT account_id, id, amount, created_at
FROM numbered
WHERE rn = 1
ORDER BY account_id;

-- ==========================================
-- Task 3: RANK, DENSE_RANK, ROW_NUMBER — ASCENDING
-- Prediction (the tie is now FIRST, so the difference shows):
--   id 5 (0)      → rn 1, rnk 1, dense_rnk 1
--   id 6 (0)      → rn 2, rnk 1, dense_rnk 1
--   id 3 (250)    → rn 3, rnk 3, dense_rnk 2   ← RANK skips 2, DENSE_RANK does not
--   id 1 (1020)   → rn 4, rnk 4, dense_rnk 3
--   id 2 (1200.50)→ rn 5, rnk 5, dense_rnk 4
--   id 4 (10000)  → rn 6, rnk 6, dense_rnk 5
-- ==========================================
SELECT id, balance,
       ROW_NUMBER() OVER (ORDER BY balance ASC, id ASC) AS rn,
       RANK()       OVER (ORDER BY balance ASC)         AS rnk,
       DENSE_RANK() OVER (ORDER BY balance ASC)         AS dense_rnk
FROM accounts
ORDER BY balance ASC, id;

-- ==========================================
-- Task 4: Change between consecutive transactions (LAG)
-- Prediction for Account 1:
--   Sep 10 → NULL
--   Sep 12 → -1050
--   Oct 5  → +30
--   Oct 10 (+15) → +35
--   Oct 10 (-5)  → -20
--   Oct 20 → +35
--   Nov 3  → +40
--   Nov 15 → -90
-- Account 2: NULL
-- Account 3: NULL
-- Account 4: NULL, then 0
-- ==========================================
SELECT account_id, created_at, id, amount,
       LAG(amount) OVER (PARTITION BY account_id ORDER BY created_at, id) AS previous_amount,
       amount - LAG(amount) OVER (PARTITION BY account_id ORDER BY created_at, id) AS change
FROM transactions
ORDER BY account_id, created_at, id;

-- ==========================================
-- Task 5: Month-over-month totals per account
-- Prediction for Account 1:
--   September: +950, change NULL
--   October:   +20, change -930
--   November:  +50, change +30
-- Other accounts: single month each → change NULL
-- ==========================================
WITH monthly AS (
    SELECT account_id,
           date_trunc('month', created_at AT TIME ZONE 'UTC') AS month,
           SUM(amount) AS month_total
    FROM transactions
    GROUP BY account_id, month
)
SELECT account_id, month, month_total,
       month_total - LAG(month_total) OVER (PARTITION BY account_id ORDER BY month) AS change_from_prev_month
FROM monthly
ORDER BY account_id, month;

-- ==========================================
-- Reconciliation proof: last running balance vs stored balance
-- Prediction: (0 rows)
-- ==========================================
WITH running AS (
    SELECT account_id, created_at, id,
           SUM(amount) OVER (PARTITION BY account_id ORDER BY created_at, id) AS running_balance
    FROM transactions
),
last_running AS (
    SELECT account_id, running_balance,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY created_at DESC, id DESC) AS rn
    FROM running
)
SELECT a.id, a.balance, lr.running_balance
FROM accounts a
LEFT JOIN last_running lr ON a.id = lr.account_id AND lr.rn = 1
WHERE a.balance != COALESCE(lr.running_balance, 0);

-- ==========================================
-- Stronger invariant: no running balance ever goes negative
-- Prediction: (0 rows)
-- ==========================================
WITH running AS (
    SELECT account_id, created_at, id,
           SUM(amount) OVER (PARTITION BY account_id ORDER BY created_at, id) AS running_balance
    FROM transactions
)
SELECT *
FROM running
WHERE running_balance < 0;
