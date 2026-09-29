BEGIN;

-- Preserve stop sequence/history while allowing exact address and coordinates
-- to be erased when either participant deletes their account.
ALTER TABLE public.order_stops
  ALTER COLUMN address DROP NOT NULL,
  ALTER COLUMN latitude DROP NOT NULL,
  ALTER COLUMN longitude DROP NOT NULL;

ALTER TABLE public.order_stops
  ADD CONSTRAINT order_stops_location_complete CHECK (
    (address IS NULL AND latitude IS NULL AND longitude IS NULL)
    OR
    (address IS NOT NULL AND latitude IS NOT NULL AND longitude IS NOT NULL)
  );

-- Backfill privacy cleanup for accounts deleted before this migration.
UPDATE public.order_stops s
   SET address = NULL, latitude = NULL, longitude = NULL
  FROM public.orders o
 WHERE s.order_id = o.id
   AND EXISTS (
     SELECT 1
       FROM public.users u
      WHERE u.account_status = 'deleted'
        AND u.id IN (o.passenger_id, o.driver_id)
   );

UPDATE public.intercity_rides r
   SET origin_lat = NULL, origin_lng = NULL,
       destination_lat = NULL, destination_lng = NULL,
       comment = NULL, updated_at = now()
  FROM public.users u
 WHERE r.driver_id = u.id
   AND u.account_status = 'deleted';

-- Password verification rows have a direct user reference and can be removed
-- for existing deleted-account tombstones.
DELETE FROM public.auth_password_verifications v
 USING public.users u
 WHERE v.user_id = u.id
   AND u.account_status = 'deleted';

-- Expiry previously disabled use but did not remove PII. Remove only records
-- that are no longer usable and no longer protect an active resend/password
-- verification window. New account deletions also remove matching live rows.
DELETE FROM public.auth_password_verifications
 WHERE consumed_at IS NOT NULL OR expires_at <= now();

DELETE FROM public.auth_otp_challenges c
 WHERE c.expires_at <= now()
   AND c.resend_available_at <= now()
   AND NOT EXISTS (
     SELECT 1 FROM public.auth_password_verifications v
      WHERE v.challenge_id = c.id
   );

DELETE FROM public.auth_sessions WHERE expires_at <= now();

COMMIT;
