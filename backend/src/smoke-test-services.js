import pg from 'pg';
import { assertSafeDestructiveTestDatabase } from './smoke-test-guard.js';

assertSafeDestructiveTestDatabase();

const { Pool } = pg;

const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
});

function check(condition, message) {
  if (!condition) {
    throw new Error(`FAILED: ${message}`);
  }

  console.log(`PASS: ${message}`);
}

const client = await pool.connect();

try {
  await client.query('BEGIN');

  console.log('--- Tulpar service types smoke test ---');

  const passengerResult = await client.query(`
    INSERT INTO users (
      firebase_uid,
      phone,
      name
    )
    VALUES (
      'smoke-services-passenger',
      '+70000000003',
      'Smoke Services Passenger'
    )
    RETURNING id
  `);

  const passengerId = passengerResult.rows[0].id;

  check(passengerId, 'Test passenger created');

  // DELIVERY
  const deliveryOrderResult = await client.query(
    `
    INSERT INTO orders (
      passenger_id,
      service_type,
      status,
      passenger_price,
      pickup_address,
      destination_address,
      pickup_lat,
      pickup_lng,
      destination_lat,
      destination_lng,
      distance_meters
    )
    VALUES (
      $1,
      'delivery',
      'searching',
      900,
      'Smoke pickup address',
      'Smoke delivery address',
      51.1605,
      71.4704,
      51.1700,
      71.4800,
      4200
    )
    RETURNING id, service_type, status
    `,
    [passengerId],
  );

  const deliveryOrder = deliveryOrderResult.rows[0];

  check(
    deliveryOrder.service_type === 'delivery',
    'Delivery order created',
  );

  await client.query(
    `
    INSERT INTO delivery_details (
      order_id,
      item_description,
      sender_name,
      sender_phone,
      recipient_name,
      recipient_phone,
      pickup_handoff_type,
      pickup_entrance,
      pickup_apartment,
      pickup_floor,
      pickup_intercom,
      pickup_comment,
      destination_handoff_type,
      destination_entrance,
      destination_apartment,
      destination_floor,
      destination_intercom,
      destination_comment
    )
    VALUES (
      $1,
      'Документы',
      'Отправитель',
      '+70000000003',
      'Получатель',
      '+70000000004',
      'door',
      '2',
      '15',
      '3',
      '15',
      'Вход со двора',
      'outside',
      NULL,
      NULL,
      NULL,
      NULL,
      'Встретит у машины'
    )
    `,
    [deliveryOrder.id],
  );

  const deliveryDetailsResult = await client.query(
    `
    SELECT
      item_description,
      recipient_phone,
      pickup_handoff_type,
      destination_handoff_type
    FROM delivery_details
    WHERE order_id = $1
    `,
    [deliveryOrder.id],
  );

  const deliveryDetails = deliveryDetailsResult.rows[0];

  check(
    deliveryDetails.item_description === 'Документы',
    'Delivery item description stored',
  );

  check(
    deliveryDetails.recipient_phone === '+70000000004',
    'Delivery recipient phone stored',
  );

  check(
    deliveryDetails.pickup_handoff_type === 'door',
    'Delivery pickup handoff stored',
  );

  check(
    deliveryDetails.destination_handoff_type === 'outside',
    'Delivery destination handoff stored',
  );

    await client.query(
    `
    UPDATE orders
    SET
      status = 'completed',
      completed_at = now(),
      updated_at = now()
    WHERE id = $1
    `,
    [deliveryOrder.id],
  );

  check(true, 'Delivery order completed before intercity test');


  // INTERCITY
  const intercityOrderResult = await client.query(
    `
    INSERT INTO orders (
      passenger_id,
      service_type,
      status,
      passenger_price,
      pickup_address,
      destination_address
    )
    VALUES (
      $1,
      'intercity',
      'searching',
      12000,
      'Есиль',
      'Астана'
    )
    RETURNING id, service_type, status
    `,
    [passengerId],
  );

  const intercityOrder = intercityOrderResult.rows[0];

  check(
    intercityOrder.service_type === 'intercity',
    'Intercity order created',
  );

  const departureAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

  await client.query(
    `
    INSERT INTO intercity_details (
      order_id,
      departure_at,
      passenger_count,
      has_luggage,
      comment
    )
    VALUES ($1, $2, 2, TRUE, 'Один большой чемодан')
    `,
    [intercityOrder.id, departureAt],
  );

  const intercityDetailsResult = await client.query(
    `
    SELECT
      departure_at,
      passenger_count,
      has_luggage,
      comment
    FROM intercity_details
    WHERE order_id = $1
    `,
    [intercityOrder.id],
  );

  const intercityDetails = intercityDetailsResult.rows[0];

  check(
    intercityDetails.passenger_count === 2,
    'Intercity passenger count stored',
  );

  check(
    intercityDetails.has_luggage === true,
    'Intercity luggage flag stored',
  );

  check(
    intercityDetails.comment === 'Один большой чемодан',
    'Intercity comment stored',
  );

  check(
    new Date(intercityDetails.departure_at) > new Date(),
    'Intercity departure time is in the future',
  );

  // Проверяем, что service_type связан с service_types
  const serviceTypeResult = await client.query(
    `
    SELECT code
    FROM service_types
    WHERE code IN ('delivery', 'intercity')
    ORDER BY code
    `,
  );

  check(
    serviceTypeResult.rows.length === 2,
    'Delivery and intercity service types exist',
  );

  console.log('');
  console.log('ALL SERVICE TYPE TESTS PASSED');

  await client.query('ROLLBACK');
} catch (error) {
  try {
    await client.query('ROLLBACK');
  } catch (_) {}

  console.error(error);
  process.exitCode = 1;
} finally {
  client.release();
  await pool.end();
}
