-- READ-ONLY preflight. Every query must return zero rows.
SELECT current_setting('server_version') AS unsupported_postgresql_version
WHERE current_setting('server_version_num')::integer < 170000;

SELECT required_table AS missing_migration_002_table
FROM (VALUES
  ('intercity_rides'),
  ('intercity_ride_bookings'),
  ('intercity_ride_requests'),
  ('intercity_ride_request_notifications')
) AS required(required_table)
WHERE to_regclass('public.' || required_table) IS NULL;

SELECT required_constraint AS missing_migration_002_constraint
FROM (VALUES
  ('intercity_ride_bookings_idempotency'),
  ('intercity_ride_requests_cities_different')
) AS required(required_constraint)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_constraint WHERE conname = required_constraint
);

SELECT table_name, column_name AS conflicting_migration_003_column
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('intercity_ride_bookings', 'intercity_ride_requests')
  AND column_name IN (
    'pickup_address', 'pickup_lat', 'pickup_lng', 'passenger_comment'
  );

SELECT conrelid::regclass::text AS table_name,
       conname AS conflicting_migration_003_constraint
FROM pg_constraint
WHERE conname IN (
  'intercity_ride_bookings_pickup_complete',
  'intercity_ride_bookings_pickup_lat',
  'intercity_ride_bookings_pickup_lng',
  'intercity_ride_requests_pickup_complete',
  'intercity_ride_requests_pickup_lat',
  'intercity_ride_requests_pickup_lng'
);
