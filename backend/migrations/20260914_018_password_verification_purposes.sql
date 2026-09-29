ALTER TABLE public.auth_otp_challenges
  DROP CONSTRAINT auth_otp_purpose_check;

ALTER TABLE public.auth_otp_challenges
  ADD CONSTRAINT auth_otp_purpose_check
  CHECK (purpose IN ('login', 'setup', 'reset'));
