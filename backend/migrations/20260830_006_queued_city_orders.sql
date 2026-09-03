-- Schema foundation for one queued CITY order after a driver's current order.
-- Runtime acceptance and promotion logic is intentionally implemented later.

BEGIN;

ALTER TABLE public.orders
  DROP CONSTRAINT orders_status_check,
  ADD COLUMN queued_after_order_id uuid,
  ADD CONSTRAINT orders_queued_after_order_id_fkey
    FOREIGN KEY (queued_after_order_id)
    REFERENCES public.orders(id)
    ON DELETE RESTRICT,
  ADD CONSTRAINT orders_queued_not_self_check
    CHECK (queued_after_order_id IS NULL OR queued_after_order_id <> id),
  ADD CONSTRAINT orders_queued_invariants_check
    CHECK (
      (
        status = 'queued'
        AND service_type = 'city'
        AND driver_id IS NOT NULL
        AND agreed_price IS NOT NULL
        AND queued_after_order_id IS NOT NULL
      )
      OR (
        status <> 'queued'
        AND queued_after_order_id IS NULL
      )
    ),
  ADD CONSTRAINT orders_status_check
    CHECK (
      status IN (
        'searching',
        'queued',
        'accepted',
        'driver_arrived',
        'in_progress',
        'completed',
        'cancelled',
        'expired'
      )
    );

CREATE UNIQUE INDEX idx_one_queued_order_per_driver
  ON public.orders (driver_id)
  WHERE driver_id IS NOT NULL AND status = 'queued';

DROP INDEX public.idx_one_active_order_per_passenger;

CREATE UNIQUE INDEX idx_one_active_order_per_passenger
  ON public.orders (passenger_id)
  WHERE status IN (
    'searching',
    'queued',
    'accepted',
    'driver_arrived',
    'in_progress'
  );

CREATE INDEX idx_orders_queued_after
  ON public.orders (queued_after_order_id)
  WHERE queued_after_order_id IS NOT NULL;

COMMIT;
