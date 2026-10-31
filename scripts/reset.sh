#!/usr/bin/env bash
#
# Drops and recreates the dev database, then applies all migrations
# (and optionally seeds).
#
# Required .env keys:
#   POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB,
#   PGHOST, PGPORT, APP_ENV (must be "dev"), DEV_DATABASE (must equal POSTGRES_DB)
#
# Usage: ./scripts/reset.sh [--yes] [--seed]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

ASSUME_YES=0
RUN_SEED=0
for arg in "$@"; do
    case "$arg" in
        --yes)  ASSUME_YES=1 ;;
        --seed) RUN_SEED=1 ;;
        *) echo "Unknown argument: $arg" >&2; echo "Usage: $0 [--yes] [--seed]" >&2; exit 2 ;;
    esac
done

# --- safety guards --------------------------------------------------------
if [[ "$APP_ENV" != "dev" ]]; then
    echo "REFUSING TO RESET: APP_ENV is '$APP_ENV', expected 'dev'." >&2; exit 1
fi
if [[ "$POSTGRES_DB" != "$DEV_DATABASE" ]]; then
    echo "REFUSING TO RESET: POSTGRES_DB is '$POSTGRES_DB', expected '$DEV_DATABASE'." >&2; exit 1
fi
if [[ "$PGHOST" != "localhost" && "$PGHOST" != "127.0.0.1" && "$PGHOST" != "::1" ]]; then
    echo "REFUSING TO RESET: PGHOST is '$PGHOST', expected localhost/127.0.0.1." >&2; exit 1
fi

if [[ "$ASSUME_YES" -ne 1 ]]; then
    read -r -p "This deletes all data in '$POSTGRES_DB'. Continue? (y/N) " answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Aborted."; exit 1 ;;
    esac
fi

# --- admin connection: use the "postgres" maintenance database ----------
ADMIN=(psql -X -q -v ON_ERROR_STOP=1 \
    -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d postgres)

echo "Dropping and recreating database '$POSTGRES_DB'..."
"${ADMIN[@]}" >/dev/null <<SQL
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '$POSTGRES_DB' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS "$POSTGRES_DB";
CREATE DATABASE "$POSTGRES_DB";
SQL

echo "Running migrations..."
"$SCRIPT_DIR/migrate.sh"

MIGRATION_COUNT="$(psql -X -q -tA -v ON_ERROR_STOP=1 \
    -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -c 'SELECT count(*) FROM schema_migrations;')"

SEED_STATUS="no"
if [[ "$RUN_SEED" -eq 1 ]]; then
    shopt -s nullglob
    seeds=(db/seeds/*.sql)
    for seed in "${seeds[@]}"; do
        echo "seeding  $(basename "$seed")"
        { echo 'BEGIN;'; cat "$seed"; echo 'COMMIT;'; } | \
            psql -X -q -v ON_ERROR_STOP=1 \
                -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
                -f -
    done
    (( ${#seeds[@]} > 0 )) && SEED_STATUS="yes"
fi

echo "Database rebuilt: $MIGRATION_COUNT migrations, seeds: $SEED_STATUS"
