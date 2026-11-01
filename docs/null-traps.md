# NULL Traps

## 1. The `= NULL` trap
**What I expected:** I expected `WHERE phone = NULL` to return all customers who don't have a phone number.
**What actually happened:** It returned 0 rows.
**Why:** In SQL, `NULL` means "unknown". You cannot use the equals sign (`=`) to compare an unknown value. The result is `UNKNOWN`, so the row is filtered out.
**The fix:** Use `WHERE phone IS NULL`.

## 2. The `<>` trap
**What I expected:** I expected `WHERE phone <> '555-0101'` to return everyone except Alice.
**What actually happened:** It returned only Bob and Charlie. It skipped all the customers with `NULL` phones.
**Why:** Just like `= NULL`, `NULL <> '555-0101'` evaluates to `UNKNOWN`, so those rows are dropped.
**The fix:** Use `WHERE phone <> '555-0101' OR phone IS NULL` or use `IS DISTINCT FROM`.

## 3. The `IS DISTINCT FROM` comparison
**What I expected:** I expected it to behave like `<>` and ignore the NULLs.
**What actually happened:** It returned 19 rows (everyone except Alice).
**Why:** `IS DISTINCT FROM` is a special comparison operator that treats `NULL` as a valid value. It says "Is this value different from the other value?" and handles NULLs correctly.

## 4. The `NOT IN` trap
**What I expected:** I expected it to give all the phone numbers that are not NULL and '555-0101'.
**What actually happened:** It returned 0 rows.
**Why:** `NOT IN` is equivalent to a series of `AND` conditions (`phone <> '555-0101' AND phone <> NULL`). Since `phone <> NULL` evaluates to `UNKNOWN`, the entire `AND` condition becomes `UNKNOWN`. This is why `NOT IN` with a `NULL` in the list is one of the most dangerous traps in SQL.
