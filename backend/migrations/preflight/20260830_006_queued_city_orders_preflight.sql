-- READ-ONLY preflight for 20260830_006_queued_city_orders.sql.
-- Every query must return zero rows before the migration is applied.

SELECT id, status
FROM public.orders
WHERE status NOT IN (
  'searching', 'accepted', 'driver_arrived', 'in_progress',
  'completed', 'cancelled', 'expired'
);

SELECT driver_id, count(*)
FROM public.orders
WHERE driver_id IS NOT NULL
  AND status IN ('accepted', 'driver_arrived', 'in_progress')
GROUP BY driver_id
HAVING count(*) > 1;

SELECT passenger_id, count(*)
FROM public.orders
WHERE status IN ('searching', 'accepted', 'driver_arrived', 'in_progress')
GROUP BY passenger_id
HAVING count(*) > 1;

SELECT 'orders.queued_after_order_id already exists' AS problem
WHERE EXISTS (
  SELECT 1
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'orders'
    AND column_name = 'queued_after_order_id'
);

SELECT 'orders_status_check prerequisite differs' AS problem
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE n.nspname = 'public'
    AND t.relname = 'orders'
    AND c.conname = 'orders_status_check'
    AND c.contype = 'c'
    AND pg_get_constraintdef(c.oid) LIKE '%searching%'
    AND pg_get_constraintdef(c.oid) LIKE '%accepted%'
    AND pg_get_constraintdef(c.oid) LIKE '%driver_arrived%'
    AND pg_get_constraintdef(c.oid) LIKE '%in_progress%'
    AND pg_get_constraintdef(c.oid) LIKE '%completed%'
    AND pg_get_constraintdef(c.oid) LIKE '%cancelled%'
    AND pg_get_constraintdef(c.oid) LIKE '%expired%'
    AND pg_get_constraintdef(c.oid) NOT LIKE '%queued%'
);

SELECT 'idx_one_active_order_per_driver prerequisite differs' AS problem
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND tablename = 'orders'
    AND indexname = 'idx_one_active_order_per_driver'
    AND indexdef LIKE 'CREATE UNIQUE INDEX%'
    AND indexdef LIKE '%accepted%'
    AND indexdef LIKE '%driver_arrived%'
    AND indexdef LIKE '%in_progress%'
    AND indexdef NOT LIKE '%queued%'
);

SELECT 'idx_one_active_order_per_passenger prerequisite differs' AS problem
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND tablename = 'orders'
    AND indexname = 'idx_one_active_order_per_passenger'
    AND indexdef LIKE 'CREATE UNIQUE INDEX%'
    AND indexdef LIKE '%searching%'
    AND indexdef LIKE '%accepted%'
    AND indexdef LIKE '%driver_arrived%'
    AND indexdef LIKE '%in_progress%'
    AND indexdef NOT LIKE '%queued%'
);

SELECT 'orders primary key prerequisite differs' AS problem
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE n.nspname = 'public'
    AND t.relname = 'orders'
    AND c.conname = 'orders_pkey'
    AND c.contype = 'p'
);

SELECT 'required orders column prerequisite differs' AS problem
WHERE EXISTS (
  SELECT expected.column_name
  FROM (VALUES
    ('id', 'uuid'),
    ('passenger_id', 'uuid'),
    ('driver_id', 'uuid'),
    ('status', 'character varying'),
    ('agreed_price', 'integer'),
    ('service_type', 'character varying')
  ) AS expected(column_name, data_type)
  LEFT JOIN information_schema.columns actual
    ON actual.table_schema = 'public'
    AND actual.table_name = 'orders'
    AND actual.column_name = expected.column_name
    AND actual.data_type = expected.data_type
  WHERE actual.column_name IS NULL
);

SELECT 'city service type prerequisite is missing' AS problem
WHERE NOT EXISTS (
  SELECT 1 FROM public.service_types WHERE code = 'city'
);
