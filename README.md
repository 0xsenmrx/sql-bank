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
./scripts/reset.sh --yes --seed   # build the database and load the sample data
./scripts/test.sh           # run every proof check
```

Leave out `--seed` to get an empty schema.

## Repository layout

```text
scripts/          migrate.sh, reset.sh, test.sh, _common.sh (shared setup)
db/migrations/    numbered, append-only schema changes
db/seeds/         sample data
db/queries/       practice queries, one file per module
db/tests/         SQL tests (constraints.sql, transfer.sql)
db/demos/         manual demos (not part of the automated test run)
docs/             decisions/ (why), mistakes.md (what I got wrong), sql-notes.md (cheat sheet)
```

## Scripts

| Script | What it does | Safety |
| --- | --- | --- |
| `scripts/migrate.sh` | Applies new files from `db/migrations` in filename order, each in one transaction, and records a SHA-256 checksum per file. | Fails loudly if an applied file was edited. |
| `scripts/reset.sh` | Drops and recreates the database, then runs `migrate.sh` (and loads seeds with `--seed`). | Refuses unless `APP_ENV=dev`, `POSTGRES_DB` equals `DEV_DATABASE`, and `PGHOST` is local. Asks for confirmation unless `--yes`. |
| `scripts/test.sh` | Runs migrations, constraints, query smoke, and transfer tests in `bank_test`. | Never touches the dev database: it asserts the target is `bank_test` before anything destructive, and drops `bank_test` when it finishes. |

## Schema

```text
customers 1 ---- * accounts 1 ---- * transactions
customers * ---- * accounts (via account_holders)
transactions has a nullable transfer_id (uuid) linking debits and credits.
A PL/pgSQL transfer_funds() function performs atomic transfers.
```

- `customers`: unique email (case-insensitive), non-empty name.
- `accounts`: belongs to a customer, three-letter uppercase currency, non-negative balance.
- `transactions`: belongs to an account, non-zero signed amount.
- Foreign keys use `ON DELETE RESTRICT`, so history cannot disappear silently.

Reasoning for each choice: `docs/decisions/0002-schema-and-constraints.md`.

## Conventions

- Migrations are numbered (`0001_create_customers.sql`) and append-only. Once a
  migration is committed, never edit it; add a new file.
- Migration files must not contain their own `BEGIN`, `COMMIT` or `ROLLBACK`; the
  script wraps each file in a transaction.
- Name every constraint and index: `uq_<table>_<column>`, `chk_<table>_<rule>`, `pk_<table>`, `fk_<table>_<column>`.
- Money is `numeric(19,4)`, never `float`. Times are `timestamptz`.
- Seeds look rows up by natural keys (such as email), never by hard-coded ids.
- Tests run inside a transaction that ends with `ROLLBACK`, and a failed check raises
  an exception, so the runner exits with an error.
- Secrets live in `.env`, which is never committed. `.env.example` is the template.

## Tests

`./scripts/test.sh` checks that:

1. a fresh reset builds the database,
2. migrations apply once and are skipped on the second run,
3. an edited migration fails with a checksum error,
4. a broken migration leaves no partial changes,
5. every constraint in `db/tests/constraints.sql` rejects bad data (NOT NULL, UNIQUE,
   CHECK, FOREIGN KEY, ON DELETE RESTRICT, DEFAULT) and accepts the boundary cases.
6. every query file in `db/queries` runs without a syntax error.
7. every transfer test in `db/tests/transfer.sql` passes (normal, insufficient, atomicity, guards, invariants).

## Progress

| Module | Status |
| --- | --- |
| 0. Environment and repository | Done |
| 1. Tables and constraints | Done |
| 2. Reading data and NULL | Done |
| 3. Aggregation | Done |
| 4. Joins | Done |
| 5. Subqueries and CTEs | Done |
| 6. Changing data and transactions | Done |
| 7. Window functions | Not started |
| 8. Schema design | Not started |
| 9. Indexes and EXPLAIN | Not started |
