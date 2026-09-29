BEGIN;

ALTER TABLE public.intercity_ride_bookings
  ADD COLUMN pickup_reached_at timestamptz;

CREATE INDEX idx_intercity_ride_bookings_remaining_pickups
  ON public.intercity_ride_bookings (ride_id, created_at, id)
  WHERE status = 'confirmed'
    AND pickup_reached_at IS NULL
    AND pickup_address IS NOT NULL;

COMMIT;
