-- Tulpar Intercity Rides, phase 1. Does not modify legacy intercity orders.
BEGIN;

CREATE TABLE public.intercity_rides (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  driver_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  origin_city varchar(120) NOT NULL,
  origin_city_key varchar(120) NOT NULL,
  origin_lat double precision,
  origin_lng double precision,
  destination_city varchar(120) NOT NULL,
  destination_city_key varchar(120) NOT NULL,
  destination_lat double precision,
  destination_lng double precision,
  departure_at timestamptz NOT NULL,
  total_seats smallint NOT NULL,
  available_seats smallint NOT NULL,
  price_per_seat integer NOT NULL,
  allows_luggage boolean NOT NULL DEFAULT false,
  comment varchar(1000),
  status varchar(20) NOT NULL DEFAULT 'scheduled',
  cancelled_at timestamptz,
  departed_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT intercity_rides_cities_different CHECK (origin_city_key <> destination_city_key),
  CONSTRAINT intercity_rides_origin_pair CHECK ((origin_lat IS NULL) = (origin_lng IS NULL)),
  CONSTRAINT intercity_rides_destination_pair CHECK ((destination_lat IS NULL) = (destination_lng IS NULL)),
  CONSTRAINT intercity_rides_origin_lat CHECK (origin_lat IS NULL OR (origin_lat BETWEEN -90 AND 90 AND origin_lat::text NOT IN ('NaN','Infinity','-Infinity'))),
  CONSTRAINT intercity_rides_origin_lng CHECK (origin_lng IS NULL OR (origin_lng BETWEEN -180 AND 180 AND origin_lng::text NOT IN ('NaN','Infinity','-Infinity'))),
  CONSTRAINT intercity_rides_destination_lat CHECK (destination_lat IS NULL OR (destination_lat BETWEEN -90 AND 90 AND destination_lat::text NOT IN ('NaN','Infinity','-Infinity'))),
  CONSTRAINT intercity_rides_destination_lng CHECK (destination_lng IS NULL OR (destination_lng BETWEEN -180 AND 180 AND destination_lng::text NOT IN ('NaN','Infinity','-Infinity'))),
  CONSTRAINT intercity_rides_seats CHECK (total_seats BETWEEN 1 AND 7 AND available_seats BETWEEN 0 AND total_seats),
  CONSTRAINT intercity_rides_price CHECK (price_per_seat BETWEEN 1 AND 1000000),
  CONSTRAINT intercity_rides_status CHECK (status IN ('scheduled','departed','completed','cancelled'))
);

CREATE TABLE public.intercity_ride_bookings (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  ride_id uuid NOT NULL REFERENCES public.intercity_rides(id) ON DELETE CASCADE,
  passenger_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  seats smallint NOT NULL CHECK (seats BETWEEN 1 AND 7),
  price_per_seat integer NOT NULL CHECK (price_per_seat BETWEEN 1 AND 1000000),
  total_price integer GENERATED ALWAYS AS (seats * price_per_seat) STORED,
  status varchar(20) NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed','cancelled','completed')),
  client_request_id uuid NOT NULL,
  cancelled_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT intercity_ride_bookings_idempotency UNIQUE (passenger_id, client_request_id)
);

CREATE UNIQUE INDEX idx_intercity_ride_booking_active_passenger
  ON public.intercity_ride_bookings (ride_id, passenger_id) WHERE status = 'confirmed';

CREATE TABLE public.intercity_ride_requests (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  passenger_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  origin_city varchar(120) NOT NULL,
  origin_city_key varchar(120) NOT NULL,
  destination_city varchar(120) NOT NULL,
  destination_city_key varchar(120) NOT NULL,
  travel_date date NOT NULL,
  seats smallint NOT NULL CHECK (seats BETWEEN 1 AND 7),
  status varchar(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','cancelled','expired')),
  cancelled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT intercity_ride_requests_cities_different CHECK (origin_city_key <> destination_city_key)
);

CREATE TABLE public.intercity_ride_request_notifications (
  request_id uuid NOT NULL REFERENCES public.intercity_ride_requests(id) ON DELETE CASCADE,
  ride_id uuid NOT NULL REFERENCES public.intercity_rides(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT intercity_ride_request_notifications_unique UNIQUE (request_id, ride_id)
);

CREATE INDEX idx_intercity_rides_search ON public.intercity_rides
  (origin_city_key, destination_city_key, departure_at) WHERE status = 'scheduled';
CREATE INDEX idx_intercity_rides_driver ON public.intercity_rides (driver_id, departure_at DESC);
CREATE INDEX idx_intercity_ride_bookings_ride_status ON public.intercity_ride_bookings (ride_id, status);
CREATE INDEX idx_intercity_ride_bookings_passenger ON public.intercity_ride_bookings (passenger_id, created_at DESC);
CREATE INDEX idx_intercity_ride_requests_match ON public.intercity_ride_requests
  (origin_city_key, destination_city_key, travel_date) WHERE status = 'active';
CREATE INDEX idx_intercity_ride_requests_passenger ON public.intercity_ride_requests (passenger_id, created_at DESC);
CREATE INDEX idx_intercity_ride_notifications_ride ON public.intercity_ride_request_notifications (ride_id);

COMMIT;
