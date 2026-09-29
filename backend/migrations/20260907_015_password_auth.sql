BEGIN;

ALTER TABLE public.users ADD COLUMN password_hash text;

CREATE TABLE public.auth_password_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL UNIQUE REFERENCES public.auth_otp_challenges(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  phone_normalized varchar(12) NOT NULL,
  purpose varchar(20) NOT NULL CHECK (purpose IN ('setup', 'reset')),
  token_hash char(64) NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  CHECK (phone_normalized ~ '^\+7[67][0-9]{9}$'),
  CHECK (expires_at > created_at)
);

CREATE INDEX idx_auth_password_verifications_active
  ON public.auth_password_verifications (token_hash, expires_at)
  WHERE consumed_at IS NULL;

COMMIT;
