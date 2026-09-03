-- Account deletion tombstones and durable Firebase deletion retry jobs.
BEGIN;

ALTER TABLE public.users
  ADD COLUMN deleted_at timestamptz,
  ADD COLUMN account_status varchar(20) NOT NULL DEFAULT 'active',
  ADD CONSTRAINT users_account_status_check
    CHECK (account_status IN ('active', 'deleted')),
  ADD CONSTRAINT users_deleted_state_check
    CHECK (
      (account_status = 'active' AND deleted_at IS NULL)
      OR
      (account_status = 'deleted' AND deleted_at IS NOT NULL
        AND firebase_uid IS NULL AND phone IS NULL AND name IS NULL)
    );

CREATE TABLE public.account_deletion_jobs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  firebase_uid_hash char(64) NOT NULL,
  firebase_uid varchar(128),
  status varchar(20) NOT NULL DEFAULT 'pending',
  attempt_count integer NOT NULL DEFAULT 0,
  last_error_code varchar(100),
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  claimed_at timestamptz,
  lease_until timestamptz,
  claim_token uuid,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT account_deletion_jobs_user_unique UNIQUE (user_id),
  CONSTRAINT account_deletion_jobs_uid_hash_unique UNIQUE (firebase_uid_hash),
  CONSTRAINT account_deletion_jobs_status_check
    CHECK (status IN ('pending', 'completed', 'failed')),
  CONSTRAINT account_deletion_jobs_attempt_count_check CHECK (attempt_count >= 0),
  CONSTRAINT account_deletion_jobs_state_check CHECK (
    (status = 'completed' AND firebase_uid IS NULL AND completed_at IS NOT NULL
      AND claimed_at IS NULL AND lease_until IS NULL AND claim_token IS NULL)
    OR (status = 'failed' AND firebase_uid IS NOT NULL AND completed_at IS NULL
      AND claimed_at IS NULL AND lease_until IS NULL AND claim_token IS NULL)
    OR (status = 'pending' AND firebase_uid IS NOT NULL AND completed_at IS NULL
      AND (
        (claimed_at IS NULL AND lease_until IS NULL AND claim_token IS NULL)
        OR (claimed_at IS NOT NULL AND lease_until IS NOT NULL
          AND claim_token IS NOT NULL AND lease_until > claimed_at)
      ))
  )
);

CREATE INDEX idx_account_deletion_jobs_retry
  ON public.account_deletion_jobs (next_attempt_at, lease_until, created_at)
  WHERE status = 'pending';

COMMIT;
