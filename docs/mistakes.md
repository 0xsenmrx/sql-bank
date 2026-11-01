# Mistakes Log & Lessons Learned

## 1. The `source .env` Blindspot
**What happened:** I assumed that passing `ENV_FILE="$TEMP_DIR/.env.test"` to my scripts would automatically redirect them to my test database. 
**The mistake:** My `_common.sh` had `source .env` hardcoded, so it ignored the `ENV_FILE` variable completely. This caused my test script to drop and rebuild my *real* development database instead of the test one.
**The fix:** Changed the script to `source "$ENV_FILE"`. I also learned that `set -a` is required before sourcing so that child processes (like `psql`) actually inherit the password variables.

## 2. Tests That Couldn't Fail
**What happened:** I wrote my constraint tests using `RAISE NOTICE '❌ FAIL'`. 
**The mistake:** `RAISE NOTICE` just prints a message to the terminal. The script still exited with code `0` (Success). A CI/CD pipeline would have shown a green checkmark even if the database allowed terrible data.
**The fix:** Switched to `RAISE EXCEPTION`. This forces the transaction to fail and `ON_ERROR_STOP` ensures the script exits with an error code.

## 3. Seed Data Contradicted the Schema
**What happened:** I assigned arbitrary balances to accounts in my seed files. Account 5 had a balance of `0.00` but a transaction of `-10.00`.
**The mistake:** The stored `balance` in the `accounts` table must exactly equal the sum of the `transactions`. My data was mathematically inconsistent, which would break the reconciliation query in Module 7.
**The fix:** Rewrote the seed files so the math perfectly aligns.

## 4. The `ON DELETE RESTRICT` Misunderstanding
**What happened:** I thought `ON DELETE RESTRICT` and `NO ACTION` were basically the same thing, and I didn't understand why my placement of it on a non-foreign-key column caused a syntax error.
**The lesson:** `NO ACTION` checks at the end of the statement by default, and at the end of the transaction only if the constraint is `DEFERRABLE INITIALLY DEFERRED`.

## 5. Hardcoded IDs in Seeds
**What happened:** I hardcoded `customer_id = 1` in my accounts seed file.
**The mistake:** If the database sequence changes, or if I delete Alice from the seed file, `1` might point to the wrong person.
**The fix:** I learned how to use a **subquery**: `(SELECT id FROM customers WHERE email = 'alice@example.com')`. This tells the database to find the correct ID dynamically.

## 6. Editing a Migration In Place Before the First Commit
**What happened:** Before the first commit, I added a constraint to `0001_create_customers.sql`, then dropped and re-added it in the same file. It worked only because `reset.sh` rebuilds the database every time.
**The rule:** Once a migration is committed, every schema change is a new numbered file (`0004_add_phone.sql`), never an edit to the original.

## 7. The Dangerous `rm` Variable
**What happened:** In `test.sh`, I did `rm -f "$MIGRATIONS_DIR"/*.sql` while the variable pointed to my temp folder, and then immediately changed the variable to point to `db/migrations`.
**The mistake:** This works *today*, but if anyone reorders those lines, the script will delete all of my real migration files.
**The fix:** Used an absolute path to the temp folder: `rm -rf "$TEMP_DIR/migrations"`.

## 8. The Redundant Index
**What happened:** I added a `UNIQUE` constraint on `email`, but I also created a `UNIQUE INDEX` on `LOWER(email)`.
**The mistake:** The `LOWER(email)` index already enforces exact uniqueness (because if `Alice@` and `alice@` are duplicates, then `alice@` and `alice@` are definitely duplicates). The plain `UNIQUE` constraint was a waste of disk space and slowed down inserts.
**The fix:** Dropped the plain `UNIQUE` constraint.

## 9. `now()` vs `clock_timestamp()`
I learned that `now()` returns the timestamp of the *start of the transaction*. If I insert 100 rows in one transaction, they all get the exact same `created_at` time. If I need the actual time each row was inserted (wall-clock time), I must use `clock_timestamp()`. Also, using `id DESC` as a tie-breaker works because IDs follow insertion order, but it is not strictly commit order under concurrency.

## 10. UNKNOWN is not FALSE
I learned that `NULL` comparisons return `UNKNOWN`, not `FALSE`. In a `WHERE` clause, both `UNKNOWN` and `FALSE` are dropped, so they look the same. But `NOT UNKNOWN` is still `UNKNOWN`! So `WHERE NOT (phone = '555-0101')` will *still* skip the rows where `phone` is `NULL`.

## 11. WHEN OTHERS swallows the FAIL signal
I put `RAISE EXCEPTION 'FAIL'` inside a `BEGIN ... EXCEPTION WHEN OTHERS` block. The handler caught my own failure signal. The fix is to set a boolean flag in the handler, then check the flag *outside* the block and raise there.

## 12. NULL slipping past an IF guard
I wrote `IF p_amount <= 0` to reject invalid amounts. When `p_amount` is `NULL`, the comparison evaluates to `NULL`, so the guard didn't fire. I must write `IF p_amount IS NULL OR p_amount <= 0`.

## 13. psql variables don't work inside $$ blocks
I put `:from_id` inside a `DO $$ ... $$` block expecting psql to substitute it. It didn't. The fix is to wrap the function call in the plain SQL layer: `SELECT transfer_funds(:from_id, :to_id, :amount);`.
