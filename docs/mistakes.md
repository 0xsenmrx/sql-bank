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
**The lesson:** `RESTRICT` blocks a delete *immediately*. `NO ACTION` (the default) blocks it at the *end of the transaction*, which allows for deferred checks. Also, `ON DELETE` only belongs on foreign key columns.

## 5. Hardcoded IDs in Seeds
**What happened:** I hardcoded `customer_id = 1` in my accounts seed file.
**The mistake:** If the database sequence changes, or if I delete Alice from the seed file, `1` might point to the wrong person.
**The fix:** I learned how to use a **subquery**: `(SELECT id FROM customers WHERE email = 'alice@example.com')`. This tells the database to find the correct ID dynamically.

## 6. Editing an Applied Migration
**What happened:** I fixed a typo in `0001_create_customers.sql` after I had already run it.
**The mistake:** Migrations are append-only. If you edit a file that has already been applied, your database and your files drift apart. My `migrate.sh` caught this because it stores a SHA-256 checksum.
**The fix:** Reverted the edit, and created a new migration file (`0004_...`) to make the change.

## 7. The Dangerous `rm` Variable
**What happened:** In `test.sh`, I did `rm -f "$MIGRATIONS_DIR"/*.sql` while the variable pointed to my temp folder, and then immediately changed the variable to point to `db/migrations`.
**The mistake:** This works *today*, but if anyone reorders those lines, the script will delete all of my real migration files.
**The fix:** Used an absolute path to the temp folder: `rm -rf "$TEMP_DIR/migrations"`.

## 8. The Redundant Index
**What happened:** I added a `UNIQUE` constraint on `email`, but I also created a `UNIQUE INDEX` on `LOWER(email)`.
**The mistake:** The `LOWER(email)` index already enforces exact uniqueness (because if `Alice@` and `alice@` are duplicates, then `alice@` and `alice@` are definitely duplicates). The plain `UNIQUE` constraint was a waste of disk space and slowed down inserts.
**The fix:** Dropped the plain `UNIQUE` constraint.
