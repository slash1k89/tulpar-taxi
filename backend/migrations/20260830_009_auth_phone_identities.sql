BEGIN;

CREATE TABLE public.auth_phone_identities (
  phone_normalized varchar(12) PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  verified_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT auth_phone_identities_user_unique UNIQUE (user_id),
  CONSTRAINT auth_phone_identities_phone_check CHECK (
    phone_normalized ~ '^\+7[67][0-9]{9}$'
  )
);

COMMIT;
