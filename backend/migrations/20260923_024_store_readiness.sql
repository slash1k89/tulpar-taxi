BEGIN;

CREATE TABLE public.user_terms_acceptances (
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  terms_version varchar(32) NOT NULL,
  accepted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, terms_version),
  CONSTRAINT user_terms_acceptances_version_check
    CHECK (terms_version ~ '^[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)?$')
);

CREATE INDEX idx_user_terms_acceptances_version
  ON public.user_terms_acceptances (terms_version, accepted_at DESC);

CREATE TABLE public.user_blocks (
  blocker_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  blocked_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_user_id, blocked_user_id),
  CONSTRAINT user_blocks_not_self CHECK (blocker_user_id <> blocked_user_id)
);

CREATE INDEX idx_user_blocks_blocked
  ON public.user_blocks (blocked_user_id, blocker_user_id);

CREATE TABLE public.moderation_admins (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  granted_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.content_reports (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  reported_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  context_type varchar(32) NOT NULL,
  reason_code varchar(32) NOT NULL,
  reason_text varchar(500),
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  booking_id uuid REFERENCES public.intercity_ride_bookings(id) ON DELETE SET NULL,
  order_message_id uuid REFERENCES public.order_messages(id) ON DELETE SET NULL,
  intercity_message_id uuid REFERENCES public.intercity_booking_messages(id) ON DELETE SET NULL,
  review_id uuid REFERENCES public.ratings(id) ON DELETE SET NULL,
  status varchar(16) NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  CONSTRAINT content_reports_not_self CHECK (reporter_user_id <> reported_user_id),
  CONSTRAINT content_reports_context_check CHECK (
    context_type IN ('user', 'city_chat', 'intercity_chat', 'review')
  ),
  CONSTRAINT content_reports_reason_check CHECK (
    reason_code IN ('abuse', 'harassment', 'spam', 'unsafe_behavior', 'inappropriate_content', 'other')
  ),
  CONSTRAINT content_reports_reason_text_check CHECK (
    reason_text IS NULL OR char_length(btrim(reason_text)) BETWEEN 1 AND 500
  ),
  CONSTRAINT content_reports_status_check CHECK (status IN ('open', 'resolved', 'dismissed')),
  CONSTRAINT content_reports_resolution_check CHECK (
    (status = 'open' AND resolved_at IS NULL AND resolved_by IS NULL)
    OR (status IN ('resolved', 'dismissed') AND resolved_at IS NOT NULL AND resolved_by IS NOT NULL)
  )
);

CREATE INDEX idx_content_reports_open
  ON public.content_reports (created_at)
  WHERE status = 'open';
CREATE INDEX idx_content_reports_reported
  ON public.content_reports (reported_user_id, created_at DESC);
CREATE INDEX idx_content_reports_reporter
  ON public.content_reports (reporter_user_id, created_at DESC);

COMMIT;
