BEGIN;

CREATE TABLE public.auth_otp_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_normalized varchar(12) NOT NULL,
  code_hash char(64) NOT NULL,
  purpose varchar(30) NOT NULL DEFAULT 'login',
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  attempts_count smallint NOT NULL DEFAULT 0,
  max_attempts smallint NOT NULL,
  resend_available_at timestamptz NOT NULL,
  request_ip inet,
  device_id varchar(200),
  CONSTRAINT auth_otp_phone_check CHECK (
    phone_normalized ~ '^\+7[67][0-9]{9}$'
  ),
  CONSTRAINT auth_otp_purpose_check CHECK (purpose IN ('login')),
  CONSTRAINT auth_otp_attempts_check CHECK (
    max_attempts BETWEEN 1 AND 20
    AND attempts_count BETWEEN 0 AND max_attempts
  ),
  CONSTRAINT auth_otp_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT auth_otp_resend_check CHECK (resend_available_at >= created_at),
  CONSTRAINT auth_otp_consumed_check CHECK (
    consumed_at IS NULL OR consumed_at >= created_at
  )
);

CREATE INDEX idx_auth_otp_phone_active
  ON public.auth_otp_challenges (
    phone_normalized, purpose, created_at DESC
  )
  WHERE consumed_at IS NULL;

COMMIT;
