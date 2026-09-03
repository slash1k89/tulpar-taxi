-- READ-ONLY preflight. Every query must return zero rows.
SELECT n.nspname AS schema_name, c.relname AS conflicting_relation
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname IN (
  'intercity_rides', 'intercity_ride_bookings', 'intercity_ride_requests',
  'intercity_ride_request_notifications', 'idx_intercity_rides_search',
  'idx_intercity_rides_driver', 'idx_intercity_ride_booking_active_passenger',
  'idx_intercity_ride_bookings_ride_status', 'idx_intercity_ride_bookings_passenger',
  'idx_intercity_ride_requests_match', 'idx_intercity_ride_requests_passenger',
  'idx_intercity_ride_notifications_ride'
);

SELECT 'gen_random_uuid() is unavailable' AS problem
WHERE to_regprocedure('gen_random_uuid()') IS NULL;

SELECT required_table AS missing_table
FROM (VALUES ('users'), ('driver_profiles'), ('driver_subscriptions')) AS required(required_table)
WHERE to_regclass('public.' || required_table) IS NULL;
