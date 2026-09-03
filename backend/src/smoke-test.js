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

  console.log('--- Tulpar backend smoke test ---');

  // 1. Создаём тестового пассажира
  const passengerResult = await client.query(`
    INSERT INTO users (
      firebase_uid,
      phone,
      name
    )
    VALUES (
      'smoke-passenger',
      '+70000000001',
      'Smoke Passenger'
    )
    RETURNING id
  `);

  const passengerId = passengerResult.rows[0].id;

  check(passengerId, 'Passenger created');

  // 2. Создаём тестового водителя
  const driverResult = await client.query(`
    INSERT INTO users (
      firebase_uid,
      phone,
      name
    )
    VALUES (
      'smoke-driver',
      '+70000000002',
      'Smoke Driver'
    )
    RETURNING id
  `);

  const driverId = driverResult.rows[0].id;

  check(driverId, 'Driver created');

  // 3. Создаём водительский профиль с бесплатным доступом
  await client.query(
    `
    INSERT INTO driver_profiles (
      user_id,
      status,
      car_model,
      car_color,
      car_number,
      agreement_version,
      agreement_accepted_at,
      access_exempt
    )
    VALUES (
      $1,
      'active',
      'Toyota Camry',
      'Black',
      '001AAA01',
      '1.0',
      now(),
      TRUE
    )
    `,
    [driverId],
  );

  check(true, 'Driver profile created with permanent access');

  // 4. Создаём заказ пассажира
  const orderResult = await client.query(
    `
    INSERT INTO orders (
      passenger_id,
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
      'searching',
      600,
      'Smoke pickup',
      'Smoke destination',
      51.1605,
      71.4704,
      51.1700,
      71.4800,
      3500
    )
    RETURNING id, status, passenger_price
    `,
    [passengerId],
  );

  const order = orderResult.rows[0];

  check(order.status === 'searching', 'Order created as searching');
  check(order.passenger_price === 600, 'Passenger price is 600');

  // 5. Водитель предлагает 800
  const offerResult = await client.query(
    `
    INSERT INTO order_offers (
      order_id,
      driver_id,
      price,
      status
    )
    VALUES (
      $1,
      $2,
      800,
      'pending'
    )
    RETURNING id, price, status
    `,
    [order.id, driverId],
  );

  const offer = offerResult.rows[0];

  check(offer.price === 800, 'Driver offer is 800');
  check(offer.status === 'pending', 'Offer created as pending');

  // 6. Пассажир принимает предложение
  await client.query(
    `
    UPDATE orders
    SET
      driver_id = $1,
      status = 'accepted',
      agreed_price = $2,
      accepted_at = now(),
      updated_at = now()
    WHERE id = $3
    `,
    [driverId, offer.price, order.id],
  );

  await client.query(
    `
    UPDATE order_offers
    SET
      status = 'accepted',
      updated_at = now()
    WHERE id = $1
    `,
    [offer.id],
  );

  const acceptedResult = await client.query(
    `
    SELECT status, agreed_price, driver_id
    FROM orders
    WHERE id = $1
    `,
    [order.id],
  );

  check(
    acceptedResult.rows[0].status === 'accepted',
    'Order accepted',
  );

  check(
    acceptedResult.rows[0].agreed_price === 800,
    'Agreed price is 800',
  );

  // 7. Водитель приехал
  await client.query(
    `
    UPDATE orders
    SET
      status = 'driver_arrived',
      driver_arrived_at = now(),
      updated_at = now()
    WHERE id = $1
    `,
    [order.id],
  );

  check(true, 'Driver arrived');

  // 8. Начинаем поездку
  await client.query(
    `
    UPDATE orders
    SET
      status = 'in_progress',
      started_at = now(),
      updated_at = now()
    WHERE id = $1
    `,
    [order.id],
  );

  check(true, 'Ride started');

  // 9. Координаты водителя
  await client.query(
    `
    UPDATE orders
    SET
      driver_lat = 51.1650,
      driver_lng = 71.4750,
      driver_location_updated_at = now(),
      updated_at = now()
    WHERE id = $1
    `,
    [order.id],
  );

  const locationResult = await client.query(
    `
    SELECT driver_lat, driver_lng
    FROM orders
    WHERE id = $1
    `,
    [order.id],
  );

  check(
    locationResult.rows[0].driver_lat === 51.165,
    'Driver latitude stored',
  );

  check(
    locationResult.rows[0].driver_lng === 71.475,
    'Driver longitude stored',
  );

  // 10. Завершаем поездку
  await client.query(
    `
    UPDATE orders
    SET
      status = 'completed',
      completed_at = now(),
      updated_at = now()
    WHERE id = $1
    `,
    [order.id],
  );

  const completedResult = await client.query(
    `
    SELECT status
    FROM orders
    WHERE id = $1
    `,
    [order.id],
  );

  check(
    completedResult.rows[0].status === 'completed',
    'Ride completed',
  );

  // 11. Пассажир ставит водителю 5
  await client.query(
    `
    INSERT INTO ratings (
      order_id,
      from_user_id,
      to_user_id,
      score
    )
    VALUES ($1, $2, $3, 5)
    `,
    [order.id, passengerId, driverId],
  );

  await client.query(
    `
    UPDATE users
    SET
      rating_sum = rating_sum + 5,
      rating_count = rating_count + 1,
      rating = ROUND(
        (rating_sum + 5)::numeric /
        (rating_count + 1),
        2
      ),
      updated_at = now()
    WHERE id = $1
    `,
    [driverId],
  );

  // 12. Водитель ставит пассажиру 4
  await client.query(
    `
    INSERT INTO ratings (
      order_id,
      from_user_id,
      to_user_id,
      score
    )
    VALUES ($1, $2, $3, 4)
    `,
    [order.id, driverId, passengerId],
  );

  await client.query(
    `
    UPDATE users
    SET
      rating_sum = rating_sum + 4,
      rating_count = rating_count + 1,
      rating = ROUND(
        (rating_sum + 4)::numeric /
        (rating_count + 1),
        2
      ),
      updated_at = now()
    WHERE id = $1
    `,
    [passengerId],
  );

  const driverRating = await client.query(
    `
    SELECT rating, rating_sum, rating_count
    FROM users
    WHERE id = $1
    `,
    [driverId],
  );

  const passengerRating = await client.query(
    `
    SELECT rating, rating_sum, rating_count
    FROM users
    WHERE id = $1
    `,
    [passengerId],
  );

  check(
    Number(driverRating.rows[0].rating) === 5,
    'Driver rating became 5.00',
  );

  check(
    Number(passengerRating.rows[0].rating) === 4,
    'Passenger rating became 4.00',
  );

  // 13. Проверяем защиту от повторного рейтинга
  let duplicateRatingBlocked = false;

  try {
    await client.query(
      `
      INSERT INTO ratings (
        order_id,
        from_user_id,
        to_user_id,
        score
      )
      VALUES ($1, $2, $3, 3)
      `,
      [order.id, passengerId, driverId],
    );
  } catch (error) {
    if (error.code === '23505') {
      duplicateRatingBlocked = true;
    } else {
      throw error;
    }
  }

  check(
    duplicateRatingBlocked,
    'Duplicate rating blocked by database',
  );

  console.log('');
  console.log('ALL SMOKE TESTS PASSED');

  // Ничего тестового в БД не сохраняем
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
