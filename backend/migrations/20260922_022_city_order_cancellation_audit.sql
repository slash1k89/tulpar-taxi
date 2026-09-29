BEGIN;

ALTER TABLE public.orders
  ADD COLUMN cancelled_by_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN cancelled_by_role text,
  ADD COLUMN cancellation_reason_code text,
  ADD COLUMN cancellation_reason_text text;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_cancelled_by_role_check
    CHECK (cancelled_by_role IS NULL OR cancelled_by_role IN ('passenger', 'driver')),
  ADD CONSTRAINT orders_cancellation_reason_text_length_check
    CHECK (cancellation_reason_text IS NULL OR char_length(cancellation_reason_text) <= 500);

CREATE INDEX idx_orders_city_cancellation_audit
  ON public.orders (cancelled_by_user_id, cancelled_at DESC)
  WHERE service_type = 'city' AND status = 'cancelled';

COMMIT;
