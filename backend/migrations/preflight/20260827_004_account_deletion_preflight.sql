-- READ-ONLY preflight. A clean baseline ready for migration 004 returns zero rows.
SELECT current_setting('server_version') AS unsupported_postgresql_version
WHERE current_setting('server_version_num')::integer < 170000;

SELECT required_table AS missing_baseline_table
FROM (VALUES
  ('users'), ('orders'), ('driver_profiles'), ('driver_subscriptions'),
  ('user_push_tokens'), ('order_messages'), ('order_offers'), ('ratings'),
  ('delivery_details'), ('intercity_details'), ('intercity_rides'),
  ('intercity_ride_bookings'), ('intercity_ride_requests'),
  ('intercity_ride_request_notifications')
) AS required(required_table)
WHERE to_regclass('public.' || required_table) IS NULL;

-- Exact columns used by account deletion and its active-resource blockers.
SELECT required.table_name, required.column_name,
       required.udt_name AS expected_type,
       required.is_nullable AS expected_nullable
FROM (VALUES
  ('users','id','uuid','NO'), ('users','firebase_uid','varchar','YES'),
  ('users','phone','varchar','YES'), ('users','name','varchar','YES'),
  ('users','rating','numeric','NO'), ('users','rating_sum','int4','NO'),
  ('users','rating_count','int4','NO'), ('users','updated_at','timestamptz','NO'),
  ('driver_profiles','user_id','uuid','NO'),
  ('driver_subscriptions','driver_id','uuid','NO'),
  ('driver_subscriptions','status','varchar','NO'),
  ('user_push_tokens','user_id','uuid','NO'),
  ('orders','id','uuid','NO'), ('orders','passenger_id','uuid','NO'),
  ('orders','driver_id','uuid','YES'), ('orders','status','varchar','NO'),
  ('orders','pickup_address','text','YES'),
  ('orders','destination_address','text','YES'),
  ('orders','pickup_lat','float8','YES'), ('orders','pickup_lng','float8','YES'),
  ('orders','destination_lat','float8','YES'),
  ('orders','destination_lng','float8','YES'),
  ('orders','driver_lat','float8','YES'), ('orders','driver_lng','float8','YES'),
  ('orders','driver_location_updated_at','timestamptz','YES'),
  ('orders','updated_at','timestamptz','NO'),
  ('order_messages','sender_id','uuid','NO'), ('order_messages','text','text','NO'),
  ('order_offers','driver_id','uuid','NO'), ('order_offers','status','varchar','NO'),
  ('order_offers','updated_at','timestamptz','NO'),
  ('ratings','from_user_id','uuid','NO'), ('ratings','comment','text','YES'),
  ('delivery_details','order_id','uuid','NO'),
  ('delivery_details','item_description','text','NO'),
  ('delivery_details','sender_name','varchar','YES'),
  ('delivery_details','sender_phone','varchar','YES'),
  ('delivery_details','recipient_name','varchar','YES'),
  ('delivery_details','recipient_phone','varchar','YES'),
  ('delivery_details','pickup_entrance','varchar','YES'),
  ('delivery_details','pickup_apartment','varchar','YES'),
  ('delivery_details','pickup_floor','varchar','YES'),
  ('delivery_details','pickup_intercom','varchar','YES'),
  ('delivery_details','pickup_comment','text','YES'),
  ('delivery_details','destination_entrance','varchar','YES'),
  ('delivery_details','destination_apartment','varchar','YES'),
  ('delivery_details','destination_floor','varchar','YES'),
  ('delivery_details','destination_intercom','varchar','YES'),
  ('delivery_details','destination_comment','text','YES'),
  ('delivery_details','updated_at','timestamptz','NO'),
  ('intercity_details','order_id','uuid','NO'),
  ('intercity_details','comment','text','YES'),
  ('intercity_details','updated_at','timestamptz','NO'),
  ('intercity_rides','id','uuid','NO'), ('intercity_rides','driver_id','uuid','NO'),
  ('intercity_rides','status','varchar','NO'),
  ('intercity_rides','comment','varchar','YES'),
  ('intercity_rides','updated_at','timestamptz','NO'),
  ('intercity_ride_bookings','ride_id','uuid','NO'),
  ('intercity_ride_bookings','passenger_id','uuid','NO'),
  ('intercity_ride_bookings','status','varchar','NO'),
  ('intercity_ride_bookings','pickup_address','varchar','YES'),
  ('intercity_ride_bookings','pickup_lat','float8','YES'),
  ('intercity_ride_bookings','pickup_lng','float8','YES'),
  ('intercity_ride_bookings','passenger_comment','varchar','YES'),
  ('intercity_ride_bookings','updated_at','timestamptz','NO'),
  ('intercity_ride_requests','passenger_id','uuid','NO'),
  ('intercity_ride_requests','status','varchar','NO'),
  ('intercity_ride_requests','pickup_address','varchar','YES'),
  ('intercity_ride_requests','pickup_lat','float8','YES'),
  ('intercity_ride_requests','pickup_lng','float8','YES'),
  ('intercity_ride_requests','passenger_comment','varchar','YES'),
  ('intercity_ride_requests','updated_at','timestamptz','NO')
) AS required(table_name, column_name, udt_name, is_nullable)
LEFT JOIN information_schema.columns actual
  ON actual.table_schema = 'public'
 AND actual.table_name = required.table_name
 AND actual.column_name = required.column_name
WHERE actual.column_name IS NULL
   OR actual.udt_name <> required.udt_name
   OR actual.is_nullable <> required.is_nullable;

-- Named constraints introduced by prerequisite migrations 001-003.
SELECT required_constraint AS missing_prerequisite_constraint
FROM (VALUES
  ('orders_pickup_lat_bounds_check'), ('orders_destination_lat_bounds_check'),
  ('orders_driver_lat_bounds_check'), ('orders_pickup_lng_bounds_check'),
  ('orders_destination_lng_bounds_check'), ('orders_driver_lng_bounds_check'),
  ('orders_pickup_coordinate_pair_check'),
  ('orders_destination_coordinate_pair_check'),
  ('orders_passenger_price_upper_bound_check'),
  ('orders_agreed_price_upper_bound_check'),
  ('orders_distance_upper_bound_check'), ('orders_searching_driver_check'),
  ('orders_active_driver_check'), ('orders_driver_arrived_timestamp_check'),
  ('orders_in_progress_timestamp_check'), ('orders_completed_timestamp_check'),
  ('orders_completed_price_check'), ('orders_cancelled_timestamp_check'),
  ('intercity_rides_status_check'), ('intercity_rides_seats'),
  ('intercity_ride_bookings_idempotency'),
  ('intercity_ride_requests_cities_different'),
  ('intercity_ride_request_notifications_unique'),
  ('intercity_ride_bookings_pickup_complete'),
  ('intercity_ride_bookings_pickup_lat'),
  ('intercity_ride_bookings_pickup_lng'),
  ('intercity_ride_requests_pickup_complete'),
  ('intercity_ride_requests_pickup_lat'),
  ('intercity_ride_requests_pickup_lng')
) AS required(required_constraint)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_constraint c
  JOIN pg_namespace n ON n.oid = c.connamespace
  WHERE n.nspname = 'public' AND c.conname = required.required_constraint
);

SELECT required_index AS missing_prerequisite_index
FROM (VALUES
  ('idx_one_pending_subscription_per_driver'),
  ('idx_user_push_tokens_user_updated'), ('idx_order_messages_sender'),
  ('idx_ratings_from_user'), ('idx_intercity_rides_search'),
  ('idx_intercity_rides_driver'), ('idx_intercity_ride_bookings_ride_status'),
  ('idx_intercity_ride_bookings_passenger'),
  ('idx_intercity_ride_requests_match'),
  ('idx_intercity_ride_requests_passenger'),
  ('idx_intercity_ride_notifications_ride')
) AS required(required_index)
WHERE to_regclass('public.' || required_index) IS NULL;

-- Distinguish a clean baseline from a fully applied or partial/conflicting 004.
WITH markers AS (
  SELECT
    (SELECT count(*) FROM information_schema.columns
      WHERE table_schema='public' AND table_name='users'
        AND column_name IN ('deleted_at','account_status')) AS user_columns,
    (to_regclass('public.account_deletion_jobs') IS NOT NULL)::int AS jobs_table,
    (to_regclass('public.idx_account_deletion_jobs_retry') IS NOT NULL)::int AS retry_index,
    (SELECT count(*) FROM information_schema.columns
      WHERE table_schema='public' AND table_name='account_deletion_jobs'
        AND column_name IN ('id','user_id','firebase_uid_hash','firebase_uid',
          'status','attempt_count','last_error_code','next_attempt_at',
          'claimed_at','lease_until','claim_token','completed_at',
          'created_at','updated_at')) AS job_columns,
    (SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace
      WHERE n.nspname='public' AND c.conname IN (
        'users_account_status_check', 'users_deleted_state_check',
        'account_deletion_jobs_user_unique',
        'account_deletion_jobs_uid_hash_unique',
        'account_deletion_jobs_status_check',
        'account_deletion_jobs_attempt_count_check',
        'account_deletion_jobs_state_check')) AS constraints
)
SELECT CASE
  WHEN user_columns=2 AND jobs_table=1 AND retry_index=1
    AND job_columns=14 AND constraints=7
    THEN 'migration_004_already_applied'
  ELSE 'migration_004_partial_or_conflicting'
END AS migration_004_state
FROM markers
WHERE user_columns + jobs_table + retry_index + job_columns + constraints > 0;

-- If a conflicting jobs table exists, report exact structural differences.
SELECT required.column_name, required.udt_name AS expected_type,
       required.is_nullable AS expected_nullable
FROM (VALUES
  ('id','uuid','NO'), ('user_id','uuid','NO'),
  ('firebase_uid_hash','bpchar','NO'), ('firebase_uid','varchar','YES'),
  ('status','varchar','NO'), ('attempt_count','int4','NO'),
  ('last_error_code','varchar','YES'), ('next_attempt_at','timestamptz','NO'),
  ('claimed_at','timestamptz','YES'), ('lease_until','timestamptz','YES'),
  ('claim_token','uuid','YES'), ('completed_at','timestamptz','YES'),
  ('created_at','timestamptz','NO'), ('updated_at','timestamptz','NO')
) AS required(column_name, udt_name, is_nullable)
LEFT JOIN information_schema.columns actual
  ON actual.table_schema='public' AND actual.table_name='account_deletion_jobs'
 AND actual.column_name=required.column_name
WHERE to_regclass('public.account_deletion_jobs') IS NOT NULL
  AND (actual.column_name IS NULL OR actual.udt_name<>required.udt_name
    OR actual.is_nullable<>required.is_nullable);
