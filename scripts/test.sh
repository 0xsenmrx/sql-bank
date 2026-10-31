#!/usr/bin/env bash
#
# Runs the Module 0 proof checks.
# Usage: ./scripts/test.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# Ensure .env has APP_ENV and DEV_DATABASE for reset.sh
if [[ -z "${APP_ENV:-}" || -z "${DEV_DATABASE:-}" ]]; then
    echo "ERROR: test.sh requires APP_ENV=dev and DEV_DATABASE=bank in .env" >&2
    exit 1
fi

# Helper to count rows in schema_migrations
count_migrations() {
    "${PSQL[@]}" -tA <<< "SELECT count(*) FROM schema_migrations;"
}

echo "========================================"
echo "TEST 1: Fresh reset builds the database"
echo "========================================"
"$SCRIPT_DIR/reset.sh" --yes >/dev/null
COUNT=$(count_migrations)
if [[ "$COUNT" -eq 0 ]]; then
    echo "✅ PASS: Fresh reset created an empty, valid database."
else
    echo "❌ FAIL: Expected 0 migrations on fresh DB, found $COUNT."
    exit 1
fi

echo "========================================"
echo "TEST 2: Apply migrations, run twice"
echo "========================================"
# Create a dummy migration
echo "CREATE TABLE test_mod0 (id serial primary key);" > db/migrations/0001_mod0_test.sql
"$SCRIPT_DIR/migrate.sh" >/dev/null
COUNT=$(count_migrations)
if [[ "$COUNT" -ne 1 ]]; then
    echo "❌ FAIL: Expected 1 migration applied, found $COUNT."
    exit 1
fi

# Run again, should say "skip"
OUTPUT=$("$SCRIPT_DIR/migrate.sh")
if [[ "$OUTPUT" != *"skip     0001_mod0_test.sql"* ]]; then
    echo "❌ FAIL: Second run did not skip the already applied migration."
    exit 1
fi
echo "✅ PASS: Migrations apply once and skip on subsequent runs."

echo "========================================"
echo "TEST 3: Edited migration fails loudly"
echo "========================================"
# Modify the applied migration file
echo "-- hacked edit" >> db/migrations/0001_mod0_test.sql

# This should fail and exit 1
set +e
OUTPUT=$("$SCRIPT_DIR/migrate.sh" 2>&1)
EXIT_CODE=$?
set -e

if [[ "$EXIT_CODE" -eq 1 && "$OUTPUT" == *"contents have changed"* ]]; then
    echo "✅ PASS: Checksum mismatch detected and failed correctly."
else
    echo "❌ FAIL: Modified migration did not trigger checksum failure."
    echo "Output: $OUTPUT"
    exit 1
fi

# Revert the edit
echo "CREATE TABLE test_mod0 (id serial primary key);" > db/migrations/0001_mod0_test.sql
"$SCRIPT_DIR/migrate.sh" >/dev/null

echo "========================================"
echo "TEST 4: Broken migration rolls back entirely"
echo "========================================"
# Create a migration with a deliberate syntax error
echo "CREATE TABLE broken_table (id serial primary key;" > db/migrations/0002_broken.sql

# This should fail
set +e
"$SCRIPT_DIR/migrate.sh" >/dev/null 2>&1
EXIT_CODE=$?
set -e

if [[ "$EXIT_CODE" -eq 0 ]]; then
    echo "❌ FAIL: Broken migration did not cause an error."
    exit 1
fi

# Check that 0002 is NOT in schema_migrations, and the table does not exist
COUNT=$(count_migrations)
if [[ "$COUNT" -ne 1 ]]; then
    echo "❌ FAIL: Expected 1 migration in schema_migrations after failure, found $COUNT."
    exit 1
fi

TABLE_EXISTS=$("${PSQL[@]}" -tA <<< "SELECT count(*) FROM pg_tables WHERE tablename = 'broken_table';")
if [[ "$TABLE_EXISTS" -ne 0 ]]; then
    echo "❌ FAIL: broken_table was created despite the syntax error!"
    exit 1
fi
echo "✅ PASS: Broken migration left no partial changes and no schema_migrations row."

# Cleanup
rm db/migrations/0001_mod0_test.sql db/migrations/0002_broken.sql
"$SCRIPT_DIR/reset.sh" --yes >/dev/null

echo "========================================"
echo "🎉 ALL MODULE 0 TESTS PASSED!"
echo "========================================"
