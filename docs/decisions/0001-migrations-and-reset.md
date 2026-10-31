# 0001: Migrations and the reset script

## Context

Migrations are necessary to guarantee that the database schema is reproducible. If a developer changes the database by hand in `psql`, a teammate who clones the repository will not have those changes, and the schema will drift. By tracking changes in numbered files, anyone can rebuild the exact same database state from scratch.

## Decision

- Schema changes live only in numbered files in `db/migrations`.
- `migrate.sh` applies each file and its bookkeeping row in one transaction.
- `migrate.sh` stores a SHA-256 checksum per file.
- `reset.sh` drops and recreates the database, then migrates.

On a new machine, a developer only needs to run `./scripts/reset.sh`. This script drops any existing database, creates a fresh one, and immediately applies all migrations in order. At the end, the developer has a database that perfectly matches the code in the repository.

## Why each safety check in reset.sh exists

| Check | What it protects against |
| --- | --- |
| `APP_ENV` must be `dev` | Prevents accidentally running the reset script against a production or staging environment. |
| `POSTGRES_DB` must equal `DEV_DATABASE` | Prevents accidentally wiping the wrong database if the `.env` file is misconfigured. |
| `PGHOST` must be local | Prevents dropping a remote database if the `.env` was changed to point to a cloud server for testing. |
| Confirmation prompt unless `--yes` | Prevents accidental deletion from muscle memory or a typo in the terminal. |

## Why the checksum

The checksum detects if a file that has already been applied has been modified. Without it, if you edited an applied migration file, the script would silently skip it, and your database would be out of sync with the repo. The rule is "add a new file, never edit an applied one" because the database has already executed the old version; editing the file breaks the history.

## Alternatives considered

| Option | Why not (for now) |
| --- | --- |
| Run SQL by hand | Not reproducible. A teammate cannot clone the repo and get the same database. |
| Delete the Docker volume to reset | Too destructive. It deletes all data and requires manually running migrations afterward. `reset.sh` is safer and automatic. |
| A framework tool (Flyway, EF Core migrations) | Writing the script manually teaches us exactly how migrations work under the hood. We will use EF Core later in Step 4. |

## Consequences and known limits

- No "down" migrations: you fix forward with a new file.
- Two `migrate.sh` runs at the same time are not protected by a lock.
- The script relies on the host having `psql` installed, and it requires a `.env` file, which makes it harder to run in some automated CI/CD pipelines without extra setup.
