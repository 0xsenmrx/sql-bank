-- scripts/transfer.sql
BEGIN;
SELECT transfer_funds(:from_id, :to_id, :amount);
COMMIT;
