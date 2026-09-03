BEGIN;

-- A temporary claim must not be confused with successful FCM delivery.
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS driver_approaching_claim_id uuid,
  ADD COLUMN IF NOT EXISTS driver_approaching_claimed_at timestamptz;

COMMIT;
