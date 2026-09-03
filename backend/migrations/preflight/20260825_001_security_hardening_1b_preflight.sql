-- READ-ONLY preflight for 20260825_001_security_hardening_1b.sql.
-- Every query must return zero rows before the migration is applied.

SELECT id
FROM public.orders
WHERE (pickup_lat IS NULL) <> (pickup_lng IS NULL)
   OR (destination_lat IS NULL) <> (destination_lng IS NULL)
   OR pickup_lat < -90 OR pickup_lat > 90
   OR destination_lat < -90 OR destination_lat > 90
   OR driver_lat < -90 OR driver_lat > 90
   OR pickup_lng < -180 OR pickup_lng > 180
   OR destination_lng < -180 OR destination_lng > 180
   OR driver_lng < -180 OR driver_lng > 180
   OR pickup_lat::text IN ('NaN', 'Infinity', '-Infinity')
   OR destination_lat::text IN ('NaN', 'Infinity', '-Infinity')
   OR driver_lat::text IN ('NaN', 'Infinity', '-Infinity')
   OR pickup_lng::text IN ('NaN', 'Infinity', '-Infinity')
   OR destination_lng::text IN ('NaN', 'Infinity', '-Infinity')
   OR driver_lng::text IN ('NaN', 'Infinity', '-Infinity');

SELECT id
FROM public.orders
WHERE passenger_price > 1000000
   OR agreed_price > 1000000
   OR distance_meters > 5000000;

SELECT id
FROM public.orders
WHERE (status = 'searching' AND driver_id IS NOT NULL)
   OR (
     status IN ('accepted', 'driver_arrived', 'in_progress', 'completed')
     AND driver_id IS NULL
   )
   OR (status = 'driver_arrived' AND driver_arrived_at IS NULL)
   OR (status = 'in_progress' AND started_at IS NULL)
   OR (status = 'completed' AND completed_at IS NULL)
   OR (status = 'completed' AND agreed_price IS NULL)
   OR (status = 'cancelled' AND cancelled_at IS NULL);

SELECT driver_id, count(*)
FROM public.driver_subscriptions
WHERE payment_status = 'pending'
GROUP BY driver_id
HAVING count(*) > 1;
