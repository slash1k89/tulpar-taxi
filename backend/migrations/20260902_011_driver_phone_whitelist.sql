BEGIN;

CREATE TABLE public.driver_phone_whitelist (
  phone_normalized varchar(12) PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT driver_phone_whitelist_phone_check CHECK (
    phone_normalized ~ '^\+7[67][0-9]{9}$'
  )
);

INSERT INTO public.driver_phone_whitelist (phone_normalized)
VALUES ('+77085305640')
ON CONFLICT (phone_normalized) DO NOTHING;

COMMIT;
