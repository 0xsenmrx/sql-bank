#!/usr/bin/env bash
#
# Runs the Module 0 proof checks.
# Uses isolated temporary folders so it never touches real dev data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# 1. Set up a temporary environment
TEMP_DIR="$(mktemp -d)"
TEST_DB="bank_test"

# 2. Guarantee cleanup, using host psql just like reset.sh
cleanup() {
    rm -rf "$TEMP_DIR"
    psql -X -q -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d postgres \
         -c "DROP DATABASE IF EXISTS $TEST_DB;" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# 3. Create a test .env file BEFORE sourcing _common.sh
cat > "$TEMP_DIR/.env.test" <<EOF
POSTGRES_USER=bank
POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
POSTGRES_DB=$TEST_DB
PGHOST=localhost
PGPORT=5432
APP_ENV=dev
DEV_DATABASE=$TEST_DB
EOF

# 4. Export the test variables, THEN source _common.sh
export ENV_FILE="$TEMP_DIR/.env.test"
export MIGRATIONS_DIR="$TEMP_DIR/migrations"
mkdir -p "$MIGRATIONS_DIR"

source "$SCRIPT_DIR/_common.sh"

# 5. Safety Assertion
if [[ "$POSTGRES_DB" != "$TEST_DB" ]]; then
    echo "CRITICAL ERROR: test.sh is pointing at database '$POSTGRES_DB', expected '$TEST_DB'." >&2
    echo "Aborting to prevent destruction of the dev database!" >&2
    exit 1
fi

# Helper to count rows in the test database
count_migrations() {
    psql -X -q -tA -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
         <<< "SELECT count(*) FROM schema_migrations;"
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
echo "CREATE TABLE test_mod0 (id serial primary key);" > "$MIGRATIONS_DIR/0001_mod0_test.sql"

"$SCRIPT_DIR/migrate.sh" >/dev/null
COUNT=$(count_migrations)
if [[ "$COUNT" -ne 1 ]]; then
    echo "❌ FAIL: Expected 1 migration applied, found $COUNT."
    exit 1
fi

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

COUNT=$(count_migrations)
if [[ "$COUNT" -ne 1 ]]; then
    echo "❌ FAIL: Expected 1 migration after failure, found $COUNT."
    exit 1
fi

TABLE_EXISTS=$(psql -X -q -tA -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d "$TEST_DB" \
               <<< "SELECT count(*) FROM pg_tables WHERE tablename = 'broken_table';")
if [[ "$TABLE_EXISTS" -ne 0 ]]; then
    echo "❌ FAIL: broken_table was created despite the syntax error!"
    exit 1
fi
echo "✅ PASS: Broken migration left no partial changes."

echo "========================================"
echo "Preparing database for constraint tests"
echo "========================================"

# 1. Delete the dummy files from the previous tests
rm -rf "$TEMP_DIR/migrations"

# 2. Point MIGRATIONS_DIR back to the REAL migrations
export MIGRATIONS_DIR="db/migrations"

# 3. Reset bank_test using the real migrations and seeds
"$SCRIPT_DIR/reset.sh" --yes --seed

echo "========================================"
echo "Running constraint tests against bank_test"
echo "========================================"
psql -X -q -v ON_ERROR_STOP=1 -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d "$TEST_DB" -f db/tests/constraints.sql

echo "========================================"
echo "🎉 ALL MODULE 0 AND CONSTRAINT TESTS PASSED!"
echo "========================================"

