BEGIN;

-- Repair profiles approved by the earlier whitelist flow. Do not approve
-- draft/pending/suspended profiles or change manually granted exemptions.
UPDATE public.driver_profiles dp
SET access_exempt = TRUE, updated_at = now()
WHERE dp.status = 'active'
  AND dp.access_exempt = FALSE
  AND EXISTS (
    SELECT 1
    FROM public.auth_phone_identities identity
    JOIN public.driver_phone_whitelist whitelist
      ON whitelist.phone_normalized = identity.phone_normalized
    WHERE identity.user_id = dp.user_id
  );

COMMIT;
