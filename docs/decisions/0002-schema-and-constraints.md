# 0002: Schema and constraints (Module 1)

## Context

The project models a small bank with three tables: `customers`, `accounts` and
`transactions`. The goal of Module 1 is that the database itself defends its data, so
bad rows are rejected even if an application or a manual query tries to write them.

## Decisions

| Decision | Choice | Reason | Trade-off |
| --- | --- | --- | --- |
| Primary keys | `bigint GENERATED ALWAYS AS IDENTITY` | Compact and index-friendly. `ALWAYS` stops anyone supplying ids by hand. | Ids are not unique across databases and reveal row counts. |
| Money | `numeric(19,4)`, never `float` | Exact decimal arithmetic. | Slower than integers; the currency lives on the account, not the amount. |
| Time | `timestamptz` with `DEFAULT now()` | An unambiguous instant, no time-zone bugs. | None worth noting here. |
| Foreign keys | `ON DELETE RESTRICT` | A customer with accounts, or an account with transactions, cannot be deleted by accident. | Deleting a customer needs an explicit cleanup step. |
| Non-negative balance | `CHECK (balance >= 0)` | No overdrafts at the data level. Zero is allowed. | Blocks a legitimate overdraft product later. |
| Currency format | `CHECK (currency ~ '^[A-Z]{3}$')` | Rejects `usd`, `BANANA` and `''`. | Does not prove the code is a real currency; a lookup table would (Module 8). |
| Non-empty name | `CHECK (btrim(full_name) <> '')` | `NOT NULL` alone accepts `''` and `'   '`. | None worth noting. |
| Email uniqueness | Unique index on `lower(email)` | `Alice@` and `alice@` are the same person. The plain `UNIQUE` is dropped because this index already covers it. | Queries must use `lower(email)` to benefit from the index. |
| Non-zero amount | `CHECK (amount <> 0)` | A zero-value transaction carries no information. | None worth noting. |

## Why RESTRICT

We chose `RESTRICT` because it checks the constraint immediately when the `DELETE` command is executed. `NO ACTION` (the default) checks at the end of the statement, and at the end of the transaction only if `DEFERRABLE INITIALLY DEFERRED`. We want to prevent deleting a customer who still has accounts, period. We didn't use `CASCADE` because cascading deletes could silently erase transaction history.

## Why four decimal places

`numeric(19,4)` means 19 total digits, with 4 digits after the decimal point. We use 4 decimals because financial systems often need to handle fractional cents (like stock prices or interest calculations) without losing precision.

## The stored balance question

`accounts.balance` repeats information that already exists in `transactions`, so the two
can drift apart. The seed data showed this: balances and transaction sums disagreed
until they were reconciled by hand.

My lean for Module 8 is to keep the stored balance but ensure it is updated safely inside transactions. Deriving the balance from transactions on every read is slow for large accounts, but storing it means we must use the double-entry ledger pattern to guarantee it never drifts.

## How it is tested

Every constraint above has a test in `db/tests/constraints.sql`. The file runs inside a
transaction that ends with `ROLLBACK`, builds its own fixtures, raises an exception when
a check fails, and includes boundary tests (a balance of exactly 0 and the valid currency
`USD` are accepted), so a schema that rejects everything cannot pass.

## Known gaps

- No email format check.
- No indexes on `accounts(customer_id)` or `transactions(account_id)`; Postgres does not
  create them for foreign keys (Module 9).
- `transactions` has no type, description or reference.
- Some negative tests use a hard-coded id; they pass because column checks run before
  foreign-key checks.
