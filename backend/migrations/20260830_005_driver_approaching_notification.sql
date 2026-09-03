BEGIN;

ALTER TABLE public.orders
  ADD COLUMN driver_approaching_notified_at timestamptz;

COMMIT;
