-- Tulpar Security Hardening #1B.
-- One-time migration for PostgreSQL 17. Apply only after running the companion
-- preflight file against the target database and reviewing zero-row results.
-- This migration does not update or delete existing rows.

BEGIN;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_pickup_lat_bounds_check
    CHECK (
      pickup_lat IS NULL
      OR (
        pickup_lat BETWEEN -90 AND 90
        AND pickup_lat::text NOT IN ('NaN', 'Infinity', '-Infinity')
      )
    ),
  ADD CONSTRAINT orders_destination_lat_bounds_check
    CHECK (
      destination_lat IS NULL
      OR (
        destination_lat BETWEEN -90 AND 90
        AND destination_lat::text NOT IN ('NaN', 'Infinity', '-Infinity')
      )
    ),
  ADD CONSTRAINT orders_driver_lat_bounds_check
    CHECK (
      driver_lat IS NULL
      OR (
        driver_lat BETWEEN -90 AND 90
        AND driver_lat::text NOT IN ('NaN', 'Infinity', '-Infinity')
      )
    ),
  ADD CONSTRAINT orders_pickup_lng_bounds_check
    CHECK (
      pickup_lng IS NULL
      OR (
        pickup_lng BETWEEN -180 AND 180
        AND pickup_lng::text NOT IN ('NaN', 'Infinity', '-Infinity')
      )
    ),
  ADD CONSTRAINT orders_destination_lng_bounds_check
    CHECK (
      destination_lng IS NULL
      OR (
        destination_lng BETWEEN -180 AND 180
        AND destination_lng::text NOT IN ('NaN', 'Infinity', '-Infinity')
      )
    ),
  ADD CONSTRAINT orders_driver_lng_bounds_check
    CHECK (
      driver_lng IS NULL
      OR (
        driver_lng BETWEEN -180 AND 180
        AND driver_lng::text NOT IN ('NaN', 'Infinity', '-Infinity')
      )
    ),
  ADD CONSTRAINT orders_pickup_coordinate_pair_check
    CHECK ((pickup_lat IS NULL) = (pickup_lng IS NULL)),
  ADD CONSTRAINT orders_destination_coordinate_pair_check
    CHECK ((destination_lat IS NULL) = (destination_lng IS NULL)),
  ADD CONSTRAINT orders_passenger_price_upper_bound_check
    CHECK (passenger_price <= 1000000),
  ADD CONSTRAINT orders_agreed_price_upper_bound_check
    CHECK (agreed_price IS NULL OR agreed_price <= 1000000),
  ADD CONSTRAINT orders_distance_upper_bound_check
    CHECK (distance_meters IS NULL OR distance_meters <= 5000000),
  ADD CONSTRAINT orders_searching_driver_check
    CHECK (status <> 'searching' OR driver_id IS NULL),
  ADD CONSTRAINT orders_active_driver_check
    CHECK (
      status NOT IN ('accepted', 'driver_arrived', 'in_progress', 'completed')
      OR driver_id IS NOT NULL
    ),
  ADD CONSTRAINT orders_driver_arrived_timestamp_check
    CHECK (status <> 'driver_arrived' OR driver_arrived_at IS NOT NULL),
  ADD CONSTRAINT orders_in_progress_timestamp_check
    CHECK (status <> 'in_progress' OR started_at IS NOT NULL),
  ADD CONSTRAINT orders_completed_timestamp_check
    CHECK (status <> 'completed' OR completed_at IS NOT NULL),
  ADD CONSTRAINT orders_completed_price_check
    CHECK (status <> 'completed' OR agreed_price IS NOT NULL),
  ADD CONSTRAINT orders_cancelled_timestamp_check
    CHECK (status <> 'cancelled' OR cancelled_at IS NOT NULL);

-- This unique partial index also serves the current lookup for a driver's
-- single pending payment, so a second pending-specific index is unnecessary.
CREATE UNIQUE INDEX idx_one_pending_subscription_per_driver
  ON public.driver_subscriptions (driver_id)
  WHERE payment_status = 'pending';

CREATE INDEX idx_user_push_tokens_user_updated
  ON public.user_push_tokens (user_id, updated_at DESC);

-- PostgreSQL does not create indexes automatically for the referencing side
-- of foreign keys. These support FK checks/cascades and future per-user reads.
CREATE INDEX idx_order_messages_sender
  ON public.order_messages (sender_id);

CREATE INDEX idx_ratings_from_user
  ON public.ratings (from_user_id);

COMMIT;
