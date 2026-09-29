BEGIN;

CREATE TABLE public.intercity_booking_messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id uuid NOT NULL REFERENCES public.intercity_ride_bookings(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  text text NOT NULL CHECK (char_length(btrim(text)) BETWEEN 1 AND 2000),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.intercity_booking_chat_reads (
  booking_id uuid NOT NULL REFERENCES public.intercity_ride_bookings(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (booking_id, user_id)
);

CREATE INDEX idx_intercity_booking_messages_timeline
  ON public.intercity_booking_messages (booking_id, created_at, sender_id);

COMMIT;
