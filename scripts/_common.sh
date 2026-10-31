#!/usr/bin/env bash
# Common setup for migrate.sh and reset.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# 1. Define the variables with defaults
ENV_FILE="${ENV_FILE:-.env}"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-db/migrations}"

# 2. Check the variable, not ".env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found (cp .env.example .env)" >&2
    exit 1
fi

# 3. Source the variable, not ".env"
set -a; source "$ENV_FILE"; set +a

: "${POSTGRES_USER:?missing POSTGRES_USER}"
: "${POSTGRES_PASSWORD:?missing POSTGRES_PASSWORD}"
: "${POSTGRES_DB:?missing POSTGRES_DB}"
: "${PGHOST:?missing PGHOST}"
: "${PGPORT:?missing PGPORT}"
export PGPASSWORD="$POSTGRES_PASSWORD"

PSQL=(psql -X -q -v ON_ERROR_STOP=1 \
    -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB")
