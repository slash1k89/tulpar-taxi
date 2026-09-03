BEGIN;

CREATE TABLE public.auth_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  refresh_token_hash char(64) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  last_used_at timestamptz,
  device_id varchar(200),
  device_name varchar(200),
  ip_created inet,
  user_agent varchar(500),
  CONSTRAINT auth_sessions_refresh_token_hash_unique UNIQUE (refresh_token_hash),
  CONSTRAINT auth_sessions_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT auth_sessions_revocation_check CHECK (
    revoked_at IS NULL OR revoked_at >= created_at
  )
);

CREATE INDEX idx_auth_sessions_user_active
  ON public.auth_sessions (user_id, expires_at DESC)
  WHERE revoked_at IS NULL;

COMMIT;
