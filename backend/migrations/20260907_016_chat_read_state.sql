BEGIN;

CREATE TABLE public.order_chat_reads (
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (order_id, user_id)
);

CREATE INDEX idx_order_messages_unread
  ON public.order_messages (order_id, created_at, sender_id);

COMMIT;
