# SQL Notes & Interview Cheat Sheet

## Clause Evaluation Order
In SQL, the clauses are evaluated in this logical order:
1. `FROM` (and `JOIN`)
2. `WHERE`
3. `GROUP BY`
4. `HAVING`
5. `SELECT`
6. `DISTINCT`
7. `ORDER BY`
8. `LIMIT`

**Why this matters:**
* You **cannot** use a column alias in `WHERE` because `SELECT` (where the alias is created) runs *after* `WHERE`.
* You **can** use a column alias in `ORDER BY` because it runs *after* `SELECT`.
* You cannot use aggregate functions (like `COUNT()`) in `WHERE` because grouping hasn't happened yet. You must use `HAVING`.

## Timezones and `date_trunc`
* `now()` returns the timestamp of the **start of the transaction**. If you insert 100 rows in one transaction, they all get the exact same `created_at`.
* `clock_timestamp()` returns the actual wall-clock time at the moment of execution.
* `date_trunc('month', created_at)` depends on the session's timezone. To make grouping deterministic across the world, we can choose a common time-zone like UTC: `date_trunc('month', created_at AT TIME ZONE 'UTC')`.

## NULL and Aggregations
* `COUNT(*)` counts the number of rows.
* `COUNT(column)` counts only rows where `column` is not NULL.
* `SUM(column)` of zero rows returns `NULL`, not `0`. Use `COALESCE(SUM(column), 0)` to get a clean zero.

## Postgres Extensions
* Postgres allows you to use a `SELECT` alias inside `GROUP BY` (e.g., `GROUP BY tx_month`). This is a Postgres extension. In standard SQL (and some of the other databases), you must write the full expression again.

## Future Schema Design (Module 8)
* Currently, a `transaction` has one `account_id` and a signed `amount`. This means we can represent a deposit or a withdrawal, but we cannot represent a **transfer** between two accounts in a single row. 

To fix this, a transfer would either need:
1. Two rows (one negative for the sender, one positive for the receiver) linked by a shared `transfer_id`.
2. Or a redesign where a transaction has a `from_account_id` and a `to_account_id`.

- **Joint accounts and balances:** "Balance per customer" through `accounts.customer_id` ignores joint holders. Summing through `account_holders` counts the shared balance twice. A decision must be made: does a joint account's balance belong to all holders equally, or is it a pooled asset?

### Module 9 (Indexes)
- The composite primary key `(account_id, customer_id)` is great for looking up holders by account. But if we want to find all accounts held by a specific customer, we need a separate index on `customer_id`.

### Module 8 (Schema)
- Nothing currently forces an account to have at least one holder. In a real bank, you'd probably want a trigger or a check to ensure an account is never empty.

## Grouping by primary key
If you group by a primary key (like `c.id`), you can select other columns from that table (like `c.full_name`) without adding them to `GROUP BY`. This is valid standard SQL because the primary key uniquely identifies the row.

## Migration backfill
 **Migration backfill:** When adding a new relationship table, you must backfill existing data (`INSERT INTO ... SELECT ...`) so you don't lose ownership. However, on a fresh reset, the tables are empty when the migration runs, which is why the seeds must also populate the table explicitly.


