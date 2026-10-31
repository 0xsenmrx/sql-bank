# SQL Bank Backend Infrastructure

An enterprise-grade banking backend database infrastructure built to satisfy Step 1 of the Backend Development Engineering Roadmap.

## Technology Stack
- **Database:** PostgreSQL 16 (Alpine)
- **Containerization:** Docker Compose
- **Environment:** WSL 2 (Ubuntu)

## Local Development Setup

1. Clone the repository to your local system.
2. Copy the environment template:
   ```bash
   cp .env.example .env
   ```
3. Open `.env` and configure your development database password.
4. Launch the local containerized infrastructure services:
   ```bash
   docker compose up -d
   ```

## Repository Architecture Verification
- `db/migrations/`: Sequential database evolution files.
- `db/tests/`: Automated structural validation test scripts.
- `docs/`: Explicit architecture design notes, performance metrics, and learning summaries.

