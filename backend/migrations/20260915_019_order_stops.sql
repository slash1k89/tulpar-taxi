BEGIN;

CREATE TABLE public.order_stops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  sequence smallint NOT NULL CHECK (sequence BETWEEN 0 AND 3),
  type text NOT NULL DEFAULT 'destination' CHECK (type = 'destination'),
  address text NOT NULL CHECK (length(btrim(address)) BETWEEN 1 AND 500),
  latitude double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  reached_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (order_id, sequence)
);

CREATE INDEX idx_order_stops_order_sequence
  ON public.order_stops (order_id, sequence);

COMMIT;
