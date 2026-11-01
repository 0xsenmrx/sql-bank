-- Copy all current owners from accounts to holders.
-- This seed populates the holders for the newly seeded accounts.
INSERT INTO account_holders (account_id, customer_id)
SELECT id, customer_id FROM accounts
ON CONFLICT DO NOTHING;

-- Add Bob as a joint holder to Alice's USD account.
INSERT INTO account_holders (account_id, customer_id)
SELECT
    (SELECT id FROM accounts WHERE customer_id = (SELECT id FROM customers WHERE email = 'alice@example.com') AND currency = 'USD'),
    (SELECT id FROM customers WHERE email = 'bob@example.com')
ON CONFLICT DO NOTHING;
