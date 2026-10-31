#!/usr/bin/env bash
# Common setup for migrate.sh and reset.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="${ENV_FILE:-.env}"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-db/migrations}"

if [[ ! -f .env ]]; then
    echo "ERROR: .env not found in $ROOT_DIR (cp .env.example .env)" >&2
    exit 1
fi

set -a; source .env; set +a

: "${POSTGRES_USER:?.env is missing POSTGRES_USER}"
: "${POSTGRES_PASSWORD:?.env is missing POSTGRES_PASSWORD}"
: "${POSTGRES_DB:?.env is missing POSTGRES_DB}"
: "${PGHOST:?.env is missing PGHOST}"
: "${PGPORT:?.env is missing PGPORT}"
export PGPASSWORD="$POSTGRES_PASSWORD"

PSQL=(psql -X -q -v ON_ERROR_STOP=1 \
    -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB")
