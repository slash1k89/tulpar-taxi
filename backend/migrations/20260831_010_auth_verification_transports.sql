BEGIN;

ALTER TABLE public.auth_otp_challenges
  ADD COLUMN method varchar(20) NOT NULL DEFAULT 'sms',
  ADD COLUMN provider varchar(30),
  ADD COLUMN provider_request_id varchar(200);

ALTER TABLE public.auth_otp_challenges
  ADD CONSTRAINT auth_otp_method_check
    CHECK (method IN ('sms', 'flash_call')),
  ADD CONSTRAINT auth_otp_provider_metadata_check CHECK (
    (method = 'sms')
    OR (
      method = 'flash_call'
      AND provider IS NOT NULL
      AND provider_request_id IS NOT NULL
    )
  );

CREATE INDEX idx_auth_otp_phone_method_active
  ON public.auth_otp_challenges (
    phone_normalized, purpose, method, created_at DESC
  )
  WHERE consumed_at IS NULL;

COMMIT;
