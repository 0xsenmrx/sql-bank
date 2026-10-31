#!/usr/bin/env bash
#
# Runs the Module 0 proof checks.
# Uses isolated temporary folders so it never touches real dev data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# 1. Set up a temporary environment
TEMP_DIR="$(mktemp -d)"
export MIGRATIONS_DIR="$TEMP_DIR/migrations"
mkdir -p "$MIGRATIONS_DIR"

# 2. Create a test .env so we don't touch the dev DB
cat > "$TEMP_DIR/.env.test" <<EOF
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=bank_test
PGHOST=$PGHOST
PGPORT=$PGPORT
APP_ENV=dev
DEV_DATABASE=bank_test
EOF
export ENV_FILE="$TEMP_DIR/.env.test"

# 3. TRAP: This guarantees cleanup even if a test fails and exits early
trap 'rm -rf "$TEMP_DIR"; docker compose exec -T db psql -U bank -d postgres -c "DROP DATABASE IF EXISTS bank_test;" >/dev/null 2>&1 || true' EXIT

# Helper to count rows in the test database
count_migrations() {
    PGPASSWORD="$POSTGRES_PASSWORD" psql -X -q -tA -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d bank_test <<< "SELECT count(*) FROM schema_migrations;"
}

echo "========================================"
echo "TEST 1: Fresh reset builds the database"
echo "========================================"
"$SCRIPT_DIR/reset.sh" --yes >/dev/null
COUNT=$(count_migrations)
if [[ "$COUNT" -eq 0 ]]; then
    echo "✅ PASS: Fresh reset created an empty, valid database."
else
    echo "❌ FAIL: Expected 0 migrations, found $COUNT."
    exit 1
fi

echo "========================================"
echo "TEST 2: Apply migrations, run twice"
echo "========================================"
# Write a dummy migration to the TEMP folder
echo "CREATE TABLE test_mod0 (id serial primary key);" > "$MIGRATIONS_DIR/0001_mod0_test.sql"

"$SCRIPT_DIR/migrate.sh" >/dev/null
COUNT=$(count_migrations)
if [[ "$COUNT" -ne 1 ]]; then
    echo "❌ FAIL: Expected 1 migration applied, found $COUNT."
    exit 1
fi

# Run again, should skip
OUTPUT=$("$SCRIPT_DIR/migrate.sh")
if [[ "$OUTPUT" != *"skip     0001_mod0_test.sql"* ]]; then
    echo "❌ FAIL: Second run did not skip."
    exit 1
fi
echo "✅ PASS: Migrations apply once and skip on subsequent runs."

echo "========================================"
echo "TEST 3: Edited migration fails loudly"
echo "========================================"
echo "-- hacked edit" >> "$MIGRATIONS_DIR/0001_mod0_test.sql"

set +e
OUTPUT=$("$SCRIPT_DIR/migrate.sh" 2>&1)
EXIT_CODE=$?
set -e

if [[ "$EXIT_CODE" -eq 1 && "$OUTPUT" == *"contents have changed"* ]]; then
    echo "✅ PASS: Checksum mismatch detected."
else
    echo "❌ FAIL: Modified migration did not fail."
    echo "Output: $OUTPUT"
    exit 1
fi

# Revert the edit
echo "CREATE TABLE test_mod0 (id serial primary key);" > "$MIGRATIONS_DIR/0001_mod0_test.sql"
"$SCRIPT_DIR/migrate.sh" >/dev/null

echo "========================================"
echo "TEST 4: Broken migration rolls back entirely"
echo "========================================"
echo "CREATE TABLE broken_table (id serial primary key;" > "$MIGRATIONS_DIR/0002_broken.sql"

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
    echo "❌ FAIL: Expected 1 migration after failure, found $COUNT."
    exit 1
fi

TABLE_EXISTS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -X -q -tA -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d bank_test <<< "SELECT count(*) FROM pg_tables WHERE tablename = 'broken_table';")
if [[ "$TABLE_EXISTS" -ne 0 ]]; then
    echo "❌ FAIL: broken_table was created despite the syntax error!"
    exit 1
fi
echo "✅ PASS: Broken migration left no partial changes."

echo "========================================"
echo "🎉 ALL MODULE 0 TESTS PASSED!"
echo "========================================"
