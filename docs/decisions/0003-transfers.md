# 0003: Transfers and Double-Entry

## Context
A transfer must atomically debit one account and credit another. We need to decide how to model and link these two transactions.

## Decision: Transfer ID
I will add a `transfer_id` column to the `transactions` table. 

## Why?
Without a `transfer_id`, if a customer complains their transfer didn't arrive, we cannot easily prove which debit belongs to which credit. An auditor could falsely pair Alice's debit with Charlie's credit. Adding a `transfer_id` makes audits, reversals, and reconciliation easy.

## Trade-offs
- It requires a new migration and slightly more data in the transactions table.
- We must ensure both inserts use the same UUID.

## Ordering and Locking
To prevent deadlocks, we will always lock the two accounts in ascending `id` order using `SELECT ... FOR UPDATE`.

## Atomicity: when it actually matters
A transfer runs inside one database transaction. If the guarded `UPDATE` fails (insufficient funds), no row was written, so there is nothing to roll back. Atomicity matters when a failure happens **after** the debit. The test in `transfer.sql` (Section 9) simulates this: a trigger on `transactions` raises an error, the debit has already been applied, and the transaction aborts. The database rolls back the debit, so Alice's balance is unchanged. That is atomicity.

## What `transfer_id` does NOT enforce
- It does not guarantee the two rows have opposite signs.
- It does not guarantee they sum to zero.
- It does not guarantee there are exactly two rows.
Those properties must be checked by a trigger or a ledger invariant query.
