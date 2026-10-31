# sql-bank

A PostgreSQL practice database for learning SQL and professional database workflow.
It is built module by module. Each module ends with a proof (a script or a written
check) that you can run or read before moving on.

## Requirements

- Docker and Docker Compose
- `psql` (the PostgreSQL client; the server runs in Docker)
- Bash and `sha256sum`

## Quick start

```bash
cp .env.example .env        # then set POSTGRES_PASSWORD to something of your own
docker compose up -d        # start PostgreSQL
./scripts/reset.sh --yes    # build the database from the migrations
```

Add `--seed` to `reset.sh` to load the sample data from `db/seeds`.

## Scripts

| Script | What it does | Safety |
| --- | --- | --- |
| `scripts/migrate.sh` | Applies new files from `db/migrations` in filename order, each in one transaction, and records a SHA-256 checksum per file. | Fails loudly if an applied file was edited. |
| `scripts/reset.sh` | Drops and recreates the database, then runs `migrate.sh` (and seeds with `--seed`). | Refuses unless `APP_ENV=dev`, `POSTGRES_DB` equals `DEV_DATABASE`, and `PGHOST` is local. Asks for confirmation unless `--yes`. |
| `scripts/test.sh` | Runs the Module 0 proof checks. | See "Tests" below. |

## Conventions

- Migrations are numbered (`0001_create_customers.sql`) and append-only. To change
  the schema, add a new file. Never edit an applied one.
- Migration files must not contain their own `BEGIN`, `COMMIT` or `ROLLBACK`; the
  script wraps each file in a transaction.
- Secrets live in `.env`, which is never committed. `.env.example` is the template.
- Rules and reasoning: see `docs/decisions/`.

## Tests

`./scripts/test.sh` checks that:

1. a fresh reset builds the database,
2. migrations apply once and are skipped on the second run,
3. an edited migration fails with a checksum error,
4. a broken migration leaves no partial changes.

## Progress

| Module | Status |
| --- | --- |
| 0. Environment and repository | In progress |
| 1. Tables and constraints | Not started |
