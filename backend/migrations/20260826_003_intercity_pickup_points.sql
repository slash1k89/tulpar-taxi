-- Nullable pickup data for backwards-compatible intercity rollout.
BEGIN;

ALTER TABLE public.intercity_ride_bookings
  ADD COLUMN pickup_address varchar(500),
  ADD COLUMN pickup_lat double precision,
  ADD COLUMN pickup_lng double precision,
  ADD COLUMN passenger_comment varchar(1000),
  ADD CONSTRAINT intercity_ride_bookings_pickup_complete CHECK (
    (pickup_address IS NULL AND pickup_lat IS NULL AND pickup_lng IS NULL)
    OR
    (pickup_address IS NOT NULL AND pickup_lat IS NOT NULL AND pickup_lng IS NOT NULL
      AND btrim(pickup_address) <> '')
  ),
  ADD CONSTRAINT intercity_ride_bookings_pickup_lat CHECK (
    pickup_lat IS NULL OR (
      pickup_lat BETWEEN -90 AND 90
      AND pickup_lat::text NOT IN ('NaN', 'Infinity', '-Infinity')
    )
  ),
  ADD CONSTRAINT intercity_ride_bookings_pickup_lng CHECK (
    pickup_lng IS NULL OR (
      pickup_lng BETWEEN -180 AND 180
      AND pickup_lng::text NOT IN ('NaN', 'Infinity', '-Infinity')
    )
  );

ALTER TABLE public.intercity_ride_requests
  ADD COLUMN pickup_address varchar(500),
  ADD COLUMN pickup_lat double precision,
  ADD COLUMN pickup_lng double precision,
  ADD COLUMN passenger_comment varchar(1000),
  ADD CONSTRAINT intercity_ride_requests_pickup_complete CHECK (
    (pickup_address IS NULL AND pickup_lat IS NULL AND pickup_lng IS NULL)
    OR
    (pickup_address IS NOT NULL AND pickup_lat IS NOT NULL AND pickup_lng IS NOT NULL
      AND btrim(pickup_address) <> '')
  ),
  ADD CONSTRAINT intercity_ride_requests_pickup_lat CHECK (
    pickup_lat IS NULL OR (
      pickup_lat BETWEEN -90 AND 90
      AND pickup_lat::text NOT IN ('NaN', 'Infinity', '-Infinity')
    )
  ),
  ADD CONSTRAINT intercity_ride_requests_pickup_lng CHECK (
    pickup_lng IS NULL OR (
      pickup_lng BETWEEN -180 AND 180
      AND pickup_lng::text NOT IN ('NaN', 'Infinity', '-Infinity')
    )
  );

COMMIT;
