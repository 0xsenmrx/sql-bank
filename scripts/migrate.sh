#!/usr/bin/env bash
#
# Applies every file in db/migrations, in filename order, exactly once.
# Records a SHA-256 checksum per file and fails if an applied file changes.
# Each migration + its bookkeeping row run inside ONE transaction.
#
# Migration files must NOT contain their own BEGIN/COMMIT/ROLLBACK.
#
# Required .env keys: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, PGHOST, PGPORT
#
# Usage: ./scripts/migrate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# --- schema_migrations -----------------------------------------------------
"${PSQL[@]}" <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (
    version    text        PRIMARY KEY,
    checksum   text        NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
);
SQL

# --- apply each new migration, atomically --------------------------------
shopt -s nullglob
migrations=(db/migrations/*.sql)
applied_count=0

for file in "${migrations[@]}"; do
    version="$(basename "$file")"
    checksum="$(sha256sum "$file" | awk '{print $1}')"

    recorded="$("${PSQL[@]}" -tA -v version="$version" <<< "SELECT checksum FROM schema_migrations WHERE version = :'version';")"

    if [[ -n "$recorded" ]]; then
        if [[ "$recorded" != "$checksum" ]]; then
            echo "ERROR: '$version' was applied, but its contents have changed." >&2
            echo "       recorded: $recorded" >&2
            echo "       on disk : $checksum" >&2
            echo "       Migrations are append-only. Revert the edit and add a new file." >&2
            exit 1
        fi
        echo "skip     $version"
        continue
    fi

    echo "applying $version"

    if ! {
            echo "BEGIN;"
            cat "$file"
            printf "\nINSERT INTO schema_migrations (version, checksum) VALUES (:'version', :'checksum');\n"
            echo "COMMIT;"
        } | "${PSQL[@]}" -v version="$version" -v checksum="$checksum" -f - ; then
        echo "ERROR: migration failed: $version" >&2
        echo "       transaction was rolled back; nothing was applied" >&2
        exit 1
    fi

    applied_count=$((applied_count + 1))
done

echo "Migrations applied: $applied_count"
