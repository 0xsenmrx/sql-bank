# SQL Notes & Interview Cheat Sheet

## Clause Evaluation Order
In SQL, the clauses are evaluated in this exact order:
1. `FROM` (and `JOIN`)
2. `WHERE`
3. `GROUP BY`
4. `HAVING`
5. `SELECT`
6. `ORDER BY`
7. `LIMIT`

**Why this matters:**
* You **cannot** use a column alias in `WHERE` because `SELECT` (where the alias is created) runs *after* `WHERE`.
* You **can** use a column alias in `ORDER BY` because it runs *after* `SELECT`.
* You cannot use aggregate functions (like `COUNT()`) in `WHERE` because grouping hasn't happened yet. You must use `HAVING`.

## Timezones and `date_trunc`
* `now()` returns the timestamp of the **start of the transaction**. If you insert 100 rows in one transaction, they all get the exact same `created_at`.
* `clock_timestamp()` returns the actual wall-clock time at the moment of execution.
* `date_trunc('month', created_at)` depends on the session's timezone. To make grouping deterministic across the world, always force UTC: `date_trunc('month', created_at AT TIME ZONE 'UTC')`.

## NULL and Aggregations
* `COUNT(*)` counts the number of rows.
* `COUNT(column)` counts only rows where `column` is not NULL.
* `SUM(column)` of zero rows returns `NULL`, not `0`. Use `COALESCE(SUM(column), 0)` to get a clean zero.

## Postgres Extensions
* Postgres allows you to use a `SELECT` alias inside `GROUP BY` (e.g., `GROUP BY tx_month`). This is a Postgres extension. In standard SQL (and other databases), you must write the full expression again.
