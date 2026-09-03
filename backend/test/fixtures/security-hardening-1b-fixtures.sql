DO $$
BEGIN
IF current_database() <> 'tulpar_migration_test' THEN
RAISE EXCEPTION 'Refusing to load test fixtures into %', current_database();
END IF;
END $$;

SET search_path TO public, pg_catalog;

BEGIN;

-- Every identifier and value below is synthetic and reserved for local tests.
INSERT INTO service_types (code, name, enabled)
VALUES
  ('city', 'Fixture City', TRUE),
  ('delivery', 'Fixture Delivery', TRUE),
  ('intercity', 'Fixture Intercity', TRUE);

INSERT INTO app_settings (
  id,
  day_minimum_fare,
  night_minimum_fare,
  driver_access_fee,
  driver_access_hours,
  day_start_hour,
  night_start_hour
)
VALUES (
  1,
  600,
  700,
  1000,
  24,
  6,
  22
);

INSERT INTO service_tariffs (
  service_type,
  minimum_day_fare,
  minimum_night_fare,
  shift_fee,
  shift_hours,
  day_start_hour,
  night_start_hour
)
VALUES
  ('city', 600, 700, 1000, 24, 6, 22),
  ('delivery', 700, 800, 1000, 24, 6, 22),
  ('intercity', 2000, 2200, 1000, 24, 6, 22);

INSERT INTO users (id, firebase_uid)
VALUES
  ('00000000-0000-4000-8000-000000000001', 'fixture-passenger-001'),
  ('00000000-0000-4000-8000-000000000002', 'fixture-passenger-002'),
  ('00000000-0000-4000-8000-000000000003', 'fixture-passenger-003'),
  ('00000000-0000-4000-8000-000000000004', 'fixture-passenger-004'),
  ('00000000-0000-4000-8000-000000000005', 'fixture-passenger-005'),
  ('00000000-0000-4000-8000-000000000006', 'fixture-passenger-006'),
  ('00000000-0000-4000-8000-000000000007', 'fixture-passenger-007'),
  ('00000000-0000-4000-8000-000000000008', 'fixture-passenger-008'),
  ('00000000-0000-4000-8000-000000000101', 'fixture-driver-101'),
  ('00000000-0000-4000-8000-000000000102', 'fixture-driver-102'),
  ('00000000-0000-4000-8000-000000000103', 'fixture-driver-103'),
  ('00000000-0000-4000-8000-000000000104', 'fixture-driver-104');

INSERT INTO driver_profiles (
  user_id,
  status,
  car_model,
  car_color,
  car_number,
  agreement_version,
  agreement_accepted_at
)
VALUES
  (
    '00000000-0000-4000-8000-000000000101',
    'active',
    'Fixture Sedan 101',
    'Fixture Silver',
    'FIXTURE-101',
    'fixture-v1',
    CURRENT_TIMESTAMP - INTERVAL '30 days'
  ),
  (
    '00000000-0000-4000-8000-000000000102',
    'active',
    'Fixture Sedan 102',
    'Fixture Blue',
    'FIXTURE-102',
    'fixture-v1',
    CURRENT_TIMESTAMP - INTERVAL '30 days'
  ),
  (
    '00000000-0000-4000-8000-000000000103',
    'active',
    'Fixture Sedan 103',
    'Fixture Gray',
    'FIXTURE-103',
    'fixture-v1',
    CURRENT_TIMESTAMP - INTERVAL '30 days'
  ),
  (
    '00000000-0000-4000-8000-000000000104',
    'active',
    'Fixture Sedan 104',
    'Fixture White',
    'FIXTURE-104',
    'fixture-v1',
    CURRENT_TIMESTAMP - INTERVAL '30 days'
  );

INSERT INTO orders (
  id,
  passenger_id,
  driver_id,
  status,
  passenger_price,
  agreed_price,
  pickup_address,
  pickup_lat,
  pickup_lng,
  destination_address,
  destination_lat,
  destination_lng,
  distance_meters,
  created_at,
  accepted_at,
  driver_arrived_at,
  started_at,
  completed_at,
  cancelled_at,
  driver_lat,
  driver_lng,
  service_type
)
VALUES
  (
    '10000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000001',
    NULL,
    'searching',
    800,
    NULL,
    'Fixture City Pickup 1',
    51.100100,
    71.100100,
    'Fixture City Destination 1',
    51.120100,
    71.120100,
    3200,
    CURRENT_TIMESTAMP - INTERVAL '8 minutes',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    'city'
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000002',
    NULL,
    'searching',
    900,
    NULL,
    'Fixture Delivery Pickup 2',
    51.200200,
    71.200200,
    'Fixture Delivery Destination 2',
    51.230200,
    71.230200,
    4100,
    CURRENT_TIMESTAMP - INTERVAL '7 minutes',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    'delivery'
  ),
  (
    '10000000-0000-4000-8000-000000000003',
    '00000000-0000-4000-8000-000000000003',
    NULL,
    'searching',
    5000,
    NULL,
    'Fixture Intercity Pickup 3',
    50.300300,
    70.300300,
    'Fixture Intercity Destination 3',
    51.300300,
    71.300300,
    145000,
    CURRENT_TIMESTAMP - INTERVAL '6 minutes',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    'intercity'
  ),
  (
    '10000000-0000-4000-8000-000000000004',
    '00000000-0000-4000-8000-000000000004',
    '00000000-0000-4000-8000-000000000101',
    'accepted',
    1000,
    1100,
    'Fixture Accepted Pickup 4',
    51.400400,
    71.400400,
    'Fixture Accepted Destination 4',
    51.420400,
    71.420400,
    3500,
    CURRENT_TIMESTAMP - INTERVAL '10 minutes',
    CURRENT_TIMESTAMP - INTERVAL '5 minutes',
    NULL,
    NULL,
    NULL,
    NULL,
    51.405400,
    71.405400,
    'city'
  ),
  (
    '10000000-0000-4000-8000-000000000005',
    '00000000-0000-4000-8000-000000000005',
    '00000000-0000-4000-8000-000000000102',
    'driver_arrived',
    1200,
    1250,
    'Fixture Arrived Pickup 5',
    51.500500,
    71.500500,
    'Fixture Arrived Destination 5',
    51.530500,
    71.530500,
    4200,
    CURRENT_TIMESTAMP - INTERVAL '12 minutes',
    CURRENT_TIMESTAMP - INTERVAL '8 minutes',
    CURRENT_TIMESTAMP - INTERVAL '2 minutes',
    NULL,
    NULL,
    NULL,
    51.500500,
    71.500500,
    'delivery'
  ),
  (
    '10000000-0000-4000-8000-000000000006',
    '00000000-0000-4000-8000-000000000006',
    '00000000-0000-4000-8000-000000000103',
    'in_progress',
    6500,
    6800,
    'Fixture In Progress Pickup 6',
    50.600600,
    70.600600,
    'Fixture In Progress Destination 6',
    52.600600,
    72.600600,
    280000,
    CURRENT_TIMESTAMP - INTERVAL '30 minutes',
    CURRENT_TIMESTAMP - INTERVAL '25 minutes',
    CURRENT_TIMESTAMP - INTERVAL '15 minutes',
    CURRENT_TIMESTAMP - INTERVAL '10 minutes',
    NULL,
    NULL,
    51.400600,
    71.400600,
    'city'
  ),
  (
    '10000000-0000-4000-8000-000000000007',
    '00000000-0000-4000-8000-000000000007',
    '00000000-0000-4000-8000-000000000104',
    'completed',
    1400,
    1450,
    'Fixture Completed Pickup 7',
    51.700700,
    71.700700,
    'Fixture Completed Destination 7',
    51.730700,
    71.730700,
    4400,
    CURRENT_TIMESTAMP - INTERVAL '1 day',
    CURRENT_TIMESTAMP - INTERVAL '23 hours 55 minutes',
    CURRENT_TIMESTAMP - INTERVAL '23 hours 45 minutes',
    CURRENT_TIMESTAMP - INTERVAL '23 hours 40 minutes',
    CURRENT_TIMESTAMP - INTERVAL '23 hours 10 minutes',
    NULL,
    51.730700,
    71.730700,
    'city'
  ),
  (
    '10000000-0000-4000-8000-000000000008',
    '00000000-0000-4000-8000-000000000008',
    NULL,
    'cancelled',
    850,
    NULL,
    'Fixture Cancelled Pickup 8',
    51.800800,
    71.800800,
    'Fixture Cancelled Destination 8',
    51.820800,
    71.820800,
    3100,
    CURRENT_TIMESTAMP - INTERVAL '20 minutes',
    NULL,
    NULL,
    NULL,
    NULL,
    CURRENT_TIMESTAMP - INTERVAL '15 minutes',
    NULL,
    NULL,
    'city'
  );

INSERT INTO delivery_details (
  order_id,
  item_description,
  sender_name,
  sender_phone,
  recipient_name,
  recipient_phone,
  pickup_handoff_type,
  destination_handoff_type,
  pickup_comment,
  destination_comment
)
VALUES (
  '10000000-0000-4000-8000-000000000002',
  'Fixture sealed parcel',
  'Fixture Sender',
  'fixture-phone-sender-002',
  'Fixture Recipient',
  'fixture-phone-recipient-002',
  'outside',
  'door',
  'Fixture pickup comment',
  'Fixture destination comment'
);

INSERT INTO intercity_details (
  order_id,
  departure_at,
  passenger_count,
  has_luggage,
  comment
)
VALUES
  (
    '10000000-0000-4000-8000-000000000003',
    CURRENT_TIMESTAMP + INTERVAL '7 days',
    3,
    TRUE,
    'Fixture scheduled intercity order'
  );

INSERT INTO driver_subscriptions (
  id,
  driver_id,
  amount,
  starts_at,
  valid_until,
  status,
  payment_reference,
  payment_status
)
VALUES (
  '20000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000101',
  1000,
  CURRENT_TIMESTAMP - INTERVAL '1 hour',
  CURRENT_TIMESTAMP + INTERVAL '23 hours',
  'active',
  'fixture-payment-reference-001',
  'paid'
);

INSERT INTO user_push_tokens (id, user_id, token, platform)
VALUES (
  '50000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000101',
  'fixture-fcm-token-not-valid-001',
  'android'
);

INSERT INTO order_messages (id, order_id, sender_id, text)
VALUES (
  '30000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000007',
  '00000000-0000-4000-8000-000000000007',
  'Fixture completed-order message'
);

INSERT INTO ratings (id, order_id, from_user_id, to_user_id, score)
VALUES (
  '40000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000007',
  '00000000-0000-4000-8000-000000000007',
  '00000000-0000-4000-8000-000000000104',
  4
);

UPDATE users
SET
  rating_sum = 4,
  rating_count = 1,
  rating = 4.00,
  updated_at = CURRENT_TIMESTAMP
WHERE id = '00000000-0000-4000-8000-000000000104';

COMMIT;

SELECT current_database();

SELECT
(SELECT count(*) FROM users) AS users,
(SELECT count(*) FROM driver_profiles) AS driver_profiles,
(SELECT count(*) FROM orders) AS orders,
(SELECT count(*) FROM delivery_details) AS delivery_details,
(SELECT count(*) FROM intercity_details) AS intercity_details,
(SELECT count(*) FROM driver_subscriptions) AS subscriptions,
(SELECT count(*) FROM ratings) AS ratings,
(SELECT count(*) FROM order_messages) AS messages,
(SELECT count(*) FROM user_push_tokens) AS push_tokens;

SELECT id, service_type, status, driver_id,
driver_arrived_at, started_at, completed_at, cancelled_at
FROM orders
ORDER BY created_at, id;
