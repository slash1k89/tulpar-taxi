import assert from 'node:assert/strict';
import test, { after, before } from 'node:test';

import {
  beginAccountDeletion,
  firebaseUidHash,
} from '../src/account-deletion.js';
import {
  assertConnectedToSafeTestDatabase,
  createIntegrationPool,
} from './test-db.js';

const pool = createIntegrationPool('account-deletion-postgres');
const deletedId = '91000000-0000-4000-8000-000000000001';
const otherId = '91000000-0000-4000-8000-000000000002';
const passengerOrderId = '92000000-0000-4000-8000-000000000001';
const otherOrderId = '92000000-0000-4000-8000-000000000002';
const offerOrderId = '92000000-0000-4000-8000-000000000003';
const rideId = '93000000-0000-4000-8000-000000000001';

before(async () => {
  await assertConnectedToSafeTestDatabase(pool, process.env.POSTGRES_DB);
  await pool.query(
    `INSERT INTO service_types (code, name)
     VALUES ('city', 'Taxi'), ('delivery', 'Delivery')
     ON CONFLICT (code) DO NOTHING`,
  );
  await pool.query(
    `INSERT INTO users (id, firebase_uid, phone, name)
     VALUES ($1, 'delete-fixture-uid', '+70000000001', 'Delete Me'),
            ($2, 'other-fixture-uid', '+70000000002', 'Other Person')`,
    [deletedId, otherId],
  );
  await pool.query(
    `INSERT INTO driver_profiles (user_id, status, car_model)
     VALUES ($1, 'active', 'Private Vehicle')`,
    [deletedId],
  );
  await pool.query(
    `INSERT INTO driver_subscriptions (
       driver_id, amount, starts_at, valid_until, status, payment_status,
       payment_reference
     ) VALUES ($1, 1000, now() - interval '1 day', now() + interval '1 day',
       'active', 'paid', 'financial-reference-retained')`,
    [deletedId],
  );
  await pool.query(
    `INSERT INTO user_push_tokens (user_id, token) VALUES ($1, 'secret-push')`,
    [deletedId],
  );
  await pool.query(
    `INSERT INTO orders (
       id, passenger_id, driver_id, status, passenger_price, agreed_price,
       pickup_address, destination_address, pickup_lat, pickup_lng,
       destination_lat, destination_lng, service_type, completed_at,
       driver_lat, driver_lng, driver_location_updated_at
     ) VALUES
       ($1, $2, $3, 'completed', 1000, 1000, 'Deleted pickup',
        'Deleted destination', 51, 71, 52, 72, 'delivery', now(), 51, 71, now()),
       ($4, $3, $2, 'completed', 1000, 1000, 'Other pickup',
        'Other destination', 53, 73, 54, 74, 'city', now(), 53, 73, now()),
       ($5, $3, NULL, 'searching', 1000, NULL, 'Offer pickup',
        'Offer destination', 53, 73, 54, 74, 'city', NULL, NULL, NULL, NULL)`,
    [passengerOrderId, deletedId, otherId, otherOrderId, offerOrderId],
  );
  await pool.query(
    `INSERT INTO order_offers (order_id, driver_id, price, status)
     VALUES ($1, $2, 1200, 'pending')`,
    [offerOrderId, deletedId],
  );
  await pool.query(
    `INSERT INTO delivery_details (
       order_id, item_description, sender_name, sender_phone,
       recipient_name, recipient_phone, pickup_comment, destination_comment
     ) VALUES ($1, 'Private parcel', 'Sender', '+711', 'Recipient', '+722',
       'Private pickup', 'Private destination')`,
    [passengerOrderId],
  );
  await pool.query(
    `INSERT INTO order_messages (order_id, sender_id, text)
     VALUES ($1, $2, 'Deleted private chat'),
            ($1, $3, 'Other user chat')`,
    [passengerOrderId, deletedId, otherId],
  );
  await pool.query(
    `INSERT INTO ratings (order_id, from_user_id, to_user_id, score, comment)
     VALUES ($1, $2, $3, 5, 'Deleted authored comment'),
            ($1, $3, $2, 5, 'Other authored comment')`,
    [passengerOrderId, deletedId, otherId],
  );
  await pool.query(
    `INSERT INTO intercity_rides (
       id, driver_id, origin_city, origin_city_key, destination_city,
       destination_city_key, departure_at, total_seats, available_seats,
       price_per_seat, comment, status, completed_at
     ) VALUES ($1, $2, 'A', 'a', 'B', 'b', now() - interval '1 day',
       3, 2, 1000, 'Driver private comment', 'completed', now())`,
    [rideId, deletedId],
  );
  await pool.query(
    `INSERT INTO intercity_ride_bookings (
       ride_id, passenger_id, seats, price_per_seat, status,
       client_request_id, completed_at, pickup_address, pickup_lat,
       pickup_lng, passenger_comment
     ) VALUES ($1, $2, 1, 1000, 'completed',
       '94000000-0000-4000-8000-000000000001', now(), 'Private pickup',
       51, 71, 'Private booking comment')`,
    [rideId, deletedId],
  );
  await pool.query(
    `INSERT INTO intercity_ride_requests (
       passenger_id, origin_city, origin_city_key, destination_city,
       destination_city_key, travel_date, seats, status, cancelled_at,
       pickup_address, pickup_lat, pickup_lng, passenger_comment
     ) VALUES ($1, 'A', 'a', 'B', 'b', current_date + 1, 1, 'cancelled',
       now(), 'Private request pickup', 51, 71, 'Private request comment')`,
    [deletedId],
  );
});

after(async () => pool.end());

test('migration 004 has tombstone constraints and retry index', async () => {
  const columns = await pool.query(
    `SELECT column_name FROM information_schema.columns
      WHERE table_schema='public' AND table_name='users'
        AND column_name IN ('deleted_at','account_status')`,
  );
  assert.equal(columns.rowCount, 2);
  const objects = await pool.query(
    `SELECT to_regclass('public.account_deletion_jobs') AS jobs,
            to_regclass('public.idx_account_deletion_jobs_retry') AS retry_index`,
  );
  assert.ok(objects.rows[0].jobs);
  assert.ok(objects.rows[0].retry_index);
  const leaseColumns = await pool.query(
    `SELECT column_name FROM information_schema.columns
      WHERE table_schema='public' AND table_name='account_deletion_jobs'
        AND column_name IN ('claimed_at','lease_until','claim_token')`,
  );
  assert.equal(leaseColumns.rowCount, 3);
});

test('deletion transaction anonymizes own PII and preserves history and other user PII', async () => {
  const result = await beginAccountDeletion({
    pool,
    firebaseUid: 'delete-fixture-uid',
  });
  assert.equal(result.kind, 'created');

  const user = (await pool.query('SELECT * FROM users WHERE id=$1', [deletedId])).rows[0];
  assert.equal(user.account_status, 'deleted');
  assert.equal(user.firebase_uid, null);
  assert.equal(user.phone, null);
  assert.equal(user.name, null);
  assert.ok(user.deleted_at);
  assert.equal((await pool.query('SELECT 1 FROM user_push_tokens WHERE user_id=$1', [deletedId])).rowCount, 0);
  assert.equal((await pool.query('SELECT 1 FROM driver_profiles WHERE user_id=$1', [deletedId])).rowCount, 0);

  const subscription = (await pool.query(
    'SELECT status, payment_reference FROM driver_subscriptions WHERE driver_id=$1',
    [deletedId],
  )).rows[0];
  assert.equal(subscription.status, 'cancelled');
  assert.equal(subscription.payment_reference, 'financial-reference-retained');
  assert.equal(
    (await pool.query(
      'SELECT status FROM order_offers WHERE order_id=$1 AND driver_id=$2',
      [offerOrderId, deletedId],
    )).rows[0].status,
    'withdrawn',
  );

  const ownOrder = (await pool.query('SELECT * FROM orders WHERE id=$1', [passengerOrderId])).rows[0];
  assert.equal(ownOrder.pickup_address, null);
  assert.equal(ownOrder.destination_address, null);
  const otherOrder = (await pool.query('SELECT * FROM orders WHERE id=$1', [otherOrderId])).rows[0];
  assert.equal(otherOrder.pickup_address, 'Other pickup');
  assert.equal(otherOrder.destination_address, 'Other destination');
  assert.equal(otherOrder.driver_lat, null);

  const messages = await pool.query(
    'SELECT sender_id, text FROM order_messages WHERE order_id=$1 ORDER BY sender_id',
    [passengerOrderId],
  );
  assert.equal(messages.rows.find((row) => row.sender_id === deletedId).text, '[сообщение удалено]');
  assert.equal(messages.rows.find((row) => row.sender_id === otherId).text, 'Other user chat');
  const ratings = await pool.query(
    'SELECT from_user_id, comment FROM ratings WHERE order_id=$1',
    [passengerOrderId],
  );
  assert.equal(ratings.rows.find((row) => row.from_user_id === deletedId).comment, null);
  assert.equal(ratings.rows.find((row) => row.from_user_id === otherId).comment, 'Other authored comment');

  const delivery = (await pool.query('SELECT * FROM delivery_details WHERE order_id=$1', [passengerOrderId])).rows[0];
  assert.equal(delivery.recipient_phone, null);
  assert.equal(delivery.sender_name, null);
  assert.equal(delivery.item_description, '[удалено]');
  assert.equal((await pool.query('SELECT comment FROM intercity_rides WHERE id=$1', [rideId])).rows[0].comment, null);
  assert.equal((await pool.query('SELECT pickup_address FROM intercity_ride_bookings WHERE passenger_id=$1', [deletedId])).rows[0].pickup_address, null);
  assert.equal((await pool.query('SELECT pickup_address FROM intercity_ride_requests WHERE passenger_id=$1', [deletedId])).rows[0].pickup_address, null);

  const job = (await pool.query('SELECT * FROM account_deletion_jobs WHERE user_id=$1', [deletedId])).rows[0];
  assert.equal(job.firebase_uid_hash, firebaseUidHash('delete-fixture-uid'));
  assert.equal(job.status, 'pending');
  assert.equal(job.firebase_uid, 'delete-fixture-uid');
});

test('repeated deletion finds the same durable job', async () => {
  const repeated = await beginAccountDeletion({
    pool,
    firebaseUid: 'delete-fixture-uid',
  });
  assert.equal(repeated.kind, 'existing');
  const count = await pool.query(
    'SELECT count(*)::int AS count FROM account_deletion_jobs WHERE user_id=$1',
    [deletedId],
  );
  assert.equal(count.rows[0].count, 1);
});

test('historical foreign keys remain valid after tombstoning', async () => {
  const refs = await pool.query(
    `SELECT
       (SELECT count(*) FROM orders WHERE passenger_id=$1 OR driver_id=$1)::int AS orders,
       (SELECT count(*) FROM ratings WHERE from_user_id=$1 OR to_user_id=$1)::int AS ratings,
       (SELECT count(*) FROM intercity_rides WHERE driver_id=$1)::int AS rides,
       (SELECT count(*) FROM intercity_ride_bookings WHERE passenger_id=$1)::int AS bookings`,
    [deletedId],
  );
  assert.deepEqual(refs.rows[0], { orders: 2, ratings: 2, rides: 1, bookings: 1 });
});
