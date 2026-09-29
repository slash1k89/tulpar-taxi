import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test, { after, before } from 'node:test';

import {
  assertConnectedToSafeTestDatabase,
  createIntegrationPool,
} from './test-db.js';

const pool = createIntegrationPool('migration-025-postgres');
const deletedUserId = 'a1000000-0000-4000-8000-000000000001';
const activeUserId = 'a1000000-0000-4000-8000-000000000002';
const orderId = 'a2000000-0000-4000-8000-000000000001';
const stopId = 'a3000000-0000-4000-8000-000000000001';
const rideId = 'a4000000-0000-4000-8000-000000000001';
const expiredOtpId = 'a5000000-0000-4000-8000-000000000001';
const activeOtpId = 'a5000000-0000-4000-8000-000000000002';
let beforeCounts;

async function counts() {
  const result = await pool.query(
    `SELECT
       (SELECT count(*) FROM users)::int AS users,
       (SELECT count(*) FROM orders)::int AS orders,
       (SELECT count(*) FROM order_stops)::int AS order_stops,
       (SELECT count(*) FROM order_messages)::int AS messages,
       (SELECT count(*) FROM ratings)::int AS reviews,
       (SELECT count(*) FROM driver_profiles)::int AS driver_profiles,
       (SELECT count(*) FROM auth_otp_challenges)::int AS otp_records,
       (SELECT count(*) FROM auth_password_verifications)::int AS password_records`,
  );
  return result.rows[0];
}

before(async () => {
  await assertConnectedToSafeTestDatabase(pool, process.env.POSTGRES_DB);
  const nullable = await pool.query(
    `SELECT column_name, is_nullable
       FROM information_schema.columns
      WHERE table_schema='public' AND table_name='order_stops'
        AND column_name=ANY($1::text[])
      ORDER BY column_name`,
    [['address', 'latitude', 'longitude']],
  );
  assert.deepEqual(nullable.rows, [
    { column_name: 'address', is_nullable: 'NO' },
    { column_name: 'latitude', is_nullable: 'NO' },
    { column_name: 'longitude', is_nullable: 'NO' },
  ]);
  assert.equal((await pool.query(
    `SELECT 1 FROM pg_constraint
      WHERE conname='order_stops_location_complete'`,
  )).rowCount, 0);

  await pool.query(
    `INSERT INTO service_types (code, name)
     VALUES ('city', 'Taxi'), ('intercity', 'Intercity')
     ON CONFLICT (code) DO NOTHING`,
  );
  await pool.query(
    `INSERT INTO users (
       id, firebase_uid, phone, name, account_status, deleted_at
     ) VALUES
       ($1, NULL, NULL, NULL, 'deleted', now()),
       ($2, 'migration-active-user', '+77000000002', 'Active Fixture', 'active', NULL)`,
    [deletedUserId, activeUserId],
  );
  await pool.query(
    `INSERT INTO driver_profiles (user_id, status, car_model)
     VALUES ($1, 'active', 'Migration Fixture Car')`,
    [activeUserId],
  );
  await pool.query(
    `INSERT INTO orders (
       id, passenger_id, driver_id, status, passenger_price, agreed_price,
       pickup_address,
       destination_address, pickup_lat, pickup_lng, destination_lat,
       destination_lng, service_type, completed_at
     ) VALUES ($1, $2, $3, 'completed', 1500, 1500,
       'Already deleted pickup', 'Already deleted destination',
       51, 71, 52, 72, 'city', now())`,
    [orderId, deletedUserId, activeUserId],
  );
  await pool.query(
    `INSERT INTO order_stops (
       id, order_id, sequence, address, latitude, longitude
     ) VALUES ($1, $2, 0, 'Backfill private stop', 51.5, 71.5)`,
    [stopId, orderId],
  );
  await pool.query(
    `INSERT INTO intercity_rides (
       id, driver_id, origin_city, origin_city_key, destination_city,
       destination_city_key, origin_lat, origin_lng, destination_lat,
       destination_lng, departure_at, total_seats, available_seats,
       price_per_seat, comment, status, completed_at
     ) VALUES ($1, $2, 'A', 'a', 'B', 'b', 51.1, 71.1, 52.2, 72.2,
       now() - interval '1 day', 3, 3, 2000, 'Backfill private comment',
       'completed', now())`,
    [rideId, deletedUserId],
  );
  await pool.query(
    `INSERT INTO auth_otp_challenges (
       id, phone_normalized, code_hash, purpose, created_at, expires_at,
       max_attempts, resend_available_at
     ) VALUES
       ($1, '+77000000003', repeat('a', 64), 'reset', now()-interval '2 hours',
        now()-interval '1 hour', 5, now()-interval '90 minutes'),
       ($2, '+77000000004', repeat('b', 64), 'reset', now(),
        now()+interval '10 minutes', 5, now()+interval '1 minute')`,
    [expiredOtpId, activeOtpId],
  );
  await pool.query(
    `INSERT INTO auth_password_verifications (
       challenge_id, user_id, phone_normalized, purpose, token_hash,
       created_at, expires_at
     ) VALUES
       ($1, $2, '+77000000003', 'reset', repeat('c', 64),
        now()-interval '2 hours', now()-interval '1 hour'),
       ($3, $2, '+77000000004', 'reset', repeat('d', 64),
        now(), now()+interval '10 minutes')`,
    [expiredOtpId, activeUserId, activeOtpId],
  );
  beforeCounts = await counts();
  console.log(`MIGRATION025_COUNTS_BEFORE=${JSON.stringify(beforeCounts)}`);

  const sql = await readFile(
    new URL('../migrations/20260929_025_account_deletion_privacy_cleanup.sql', import.meta.url),
    'utf8',
  );
  await pool.query(sql);
});

after(async () => pool.end());

test('migration 025 commits the nullable stop contract and preserves history rows', async () => {
  const nullable = await pool.query(
    `SELECT column_name, is_nullable
       FROM information_schema.columns
      WHERE table_schema='public' AND table_name='order_stops'
        AND column_name=ANY($1::text[])
      ORDER BY column_name`,
    [['address', 'latitude', 'longitude']],
  );
  assert.deepEqual(nullable.rows, [
    { column_name: 'address', is_nullable: 'YES' },
    { column_name: 'latitude', is_nullable: 'YES' },
    { column_name: 'longitude', is_nullable: 'YES' },
  ]);
  assert.equal((await pool.query(
    `SELECT 1 FROM pg_constraint
      WHERE conname='order_stops_location_complete' AND convalidated`,
  )).rowCount, 1);

  const afterCounts = await counts();
  console.log(`MIGRATION025_COUNTS_AFTER=${JSON.stringify(afterCounts)}`);
  for (const table of [
    'users', 'orders', 'order_stops', 'messages', 'reviews', 'driver_profiles',
  ]) {
    assert.equal(afterCounts[table], beforeCounts[table], table);
  }
  assert.equal(afterCounts.otp_records, beforeCounts.otp_records - 1);
  assert.equal(afterCounts.password_records, beforeCounts.password_records - 1);
});

test('migration 025 backfills deleted-account PII without deleting history', async () => {
  const stop = (await pool.query(
    'SELECT address, latitude, longitude FROM order_stops WHERE id=$1',
    [stopId],
  )).rows[0];
  assert.deepEqual(stop, { address: null, latitude: null, longitude: null });
  const ride = (await pool.query(
    `SELECT origin_lat, origin_lng, destination_lat, destination_lng, comment
       FROM intercity_rides WHERE id=$1`,
    [rideId],
  )).rows[0];
  assert.deepEqual(ride, {
    origin_lat: null,
    origin_lng: null,
    destination_lat: null,
    destination_lng: null,
    comment: null,
  });
  assert.equal((await pool.query('SELECT 1 FROM orders WHERE id=$1', [orderId])).rowCount, 1);
  assert.equal((await pool.query('SELECT 1 FROM order_stops WHERE id=$1', [stopId])).rowCount, 1);
  assert.equal((await pool.query('SELECT 1 FROM auth_otp_challenges WHERE id=$1', [activeOtpId])).rowCount, 1);
  assert.equal((await pool.query('SELECT 1 FROM auth_password_verifications WHERE challenge_id=$1', [activeOtpId])).rowCount, 1);
});

test('order stop constraint accepts only complete or fully scrubbed locations', async () => {
  await assert.rejects(
    pool.query(
      `INSERT INTO order_stops (order_id, sequence, address, latitude, longitude)
       VALUES ($1, 1, NULL, 51, NULL)`,
      [orderId],
    ),
    /order_stops_location_complete/,
  );
  await pool.query(
    `INSERT INTO order_stops (order_id, sequence, address, latitude, longitude)
     VALUES ($1, 1, NULL, NULL, NULL)`,
    [orderId],
  );
});
