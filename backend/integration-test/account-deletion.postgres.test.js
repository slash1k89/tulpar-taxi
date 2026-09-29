import assert from 'node:assert/strict';
import test, { after, before } from 'node:test';

import {
  beginAccountDeletion,
  claimAccountDeletionJob,
  firebaseUidHash,
  processClaimedFirebaseDeletion,
} from '../src/account-deletion.js';
import { cleanupExpiredAuthHistory } from '../src/auth/auth-history-cleanup.js';
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
const stopId = '95000000-0000-4000-8000-000000000001';
const secondStopId = '95000000-0000-4000-8000-000000000002';
const otpId = '96000000-0000-4000-8000-000000000001';

async function privacyCounts() {
  return (await pool.query(
    `SELECT
       (SELECT count(*) FROM users)::int AS users,
       (SELECT count(*) FROM orders)::int AS orders,
       (SELECT count(*) FROM order_stops)::int AS order_stops,
       (SELECT count(*) FROM order_messages)::int AS messages,
       (SELECT count(*) FROM ratings)::int AS reviews,
       (SELECT count(*) FROM driver_profiles)::int AS driver_profiles,
       (SELECT count(*) FROM auth_otp_challenges)::int AS otp_records,
       (SELECT count(*) FROM auth_password_verifications)::int AS password_records`,
  )).rows[0];
}

before(async () => {
  await assertConnectedToSafeTestDatabase(pool, process.env.POSTGRES_DB);
  await pool.query(
    `INSERT INTO service_types (code, name)
     VALUES ('city', 'Taxi'), ('delivery', 'Delivery')
     ON CONFLICT (code) DO NOTHING`,
  );
  await pool.query(
    `INSERT INTO users (id, firebase_uid, phone, name)
     VALUES ($1, 'delete-fixture-uid', '+77000000001', 'Delete Me'),
            ($2, 'other-fixture-uid', '+77000000002', 'Other Person')`,
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
    `INSERT INTO auth_phone_identities (phone_normalized, user_id)
     VALUES ('+77000000001', $1)`,
    [deletedId],
  );
  await pool.query(
    `INSERT INTO auth_sessions (
       user_id, refresh_token_hash, expires_at, device_id, device_name,
       ip_created, user_agent
     ) VALUES ($1, repeat('a', 64), now() + interval '1 day',
       'private-device', 'private-name', '192.0.2.10', 'private-agent')`,
    [deletedId],
  );
  await pool.query(
    `INSERT INTO auth_otp_challenges (
       id, phone_normalized, code_hash, purpose, expires_at, max_attempts,
       resend_available_at, request_ip, device_id
     ) VALUES ($1, '+77000000001', repeat('b', 64), 'setup',
       now() + interval '5 minutes', 5, now() + interval '1 minute',
       '192.0.2.11', 'private-otp-device')`,
    [otpId],
  );
  await pool.query(
    `INSERT INTO auth_password_verifications (
       challenge_id, user_id, phone_normalized, purpose, token_hash, expires_at
     ) VALUES ($1, $2, '+77000000001', 'setup', repeat('c', 64),
       now() + interval '10 minutes')`,
    [otpId, deletedId],
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
    `INSERT INTO order_stops (
       id, order_id, sequence, address, latitude, longitude
     ) VALUES
       ($1, $3, 0, 'Private intermediate stop', 51.5, 71.5),
       ($2, $3, 1, 'Second private stop', 51.6, 71.6)`,
    [stopId, secondStopId, passengerOrderId],
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
       destination_city_key, origin_lat, origin_lng, destination_lat,
       destination_lng, departure_at, total_seats, available_seats,
       price_per_seat, comment, status, completed_at
      ) VALUES ($1, $2, 'A', 'a', 'B', 'b', 51.1, 71.1, 52.2, 72.2,
       now() - interval '1 day', 3, 2, 1000,
       'Driver private comment', 'completed', now())`,
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
  await pool.query(
    `INSERT INTO user_terms_acceptances (user_id, terms_version)
     VALUES ($1, '1.0')`,
    [deletedId],
  );
  await pool.query(
    `INSERT INTO user_blocks (blocker_user_id, blocked_user_id)
     VALUES ($1, $2)`,
    [deletedId, otherId],
  );
  await pool.query(
    `INSERT INTO content_reports (
       reporter_user_id, reported_user_id, context_type, reason_code,
       reason_text, order_id
     ) VALUES ($1, $2, 'user', 'unsafe_behavior',
       'Moderation evidence retained', $3)`,
    [deletedId, otherId, passengerOrderId],
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

test('account deletion transaction fully rolls back after a controlled cleanup failure', async () => {
  await pool.query(
    `CREATE FUNCTION fail_fixture_driver_delete() RETURNS trigger
       LANGUAGE plpgsql AS $$
       BEGIN
         IF OLD.user_id = '${deletedId}'::uuid THEN
           RAISE EXCEPTION 'controlled account deletion rollback fixture';
         END IF;
         RETURN OLD;
       END $$`,
  );
  await pool.query(
    `CREATE TRIGGER fail_fixture_driver_delete
       BEFORE DELETE ON driver_profiles
       FOR EACH ROW EXECUTE FUNCTION fail_fixture_driver_delete()`,
  );
  try {
    await assert.rejects(
      beginAccountDeletion({ pool, firebaseUid: 'delete-fixture-uid' }),
      /controlled account deletion rollback fixture/,
    );
  } finally {
    await pool.query('DROP TRIGGER fail_fixture_driver_delete ON driver_profiles');
    await pool.query('DROP FUNCTION fail_fixture_driver_delete()');
  }
  const user = (await pool.query(
    'SELECT account_status, phone, name FROM users WHERE id=$1',
    [deletedId],
  )).rows[0];
  assert.deepEqual(user, {
    account_status: 'active',
    phone: '+77000000001',
    name: 'Delete Me',
  });
  assert.equal((await pool.query('SELECT 1 FROM driver_profiles WHERE user_id=$1', [deletedId])).rowCount, 1);
  assert.equal((await pool.query('SELECT 1 FROM user_push_tokens WHERE user_id=$1', [deletedId])).rowCount, 1);
  assert.equal((await pool.query('SELECT 1 FROM auth_sessions WHERE user_id=$1', [deletedId])).rowCount, 1);
  assert.equal((await pool.query('SELECT 1 FROM account_deletion_jobs WHERE user_id=$1', [deletedId])).rowCount, 0);
  assert.equal((await pool.query('SELECT address FROM order_stops WHERE id=$1', [stopId])).rows[0].address, 'Private intermediate stop');
});

test('deletion transaction anonymizes own PII and preserves history and other user PII', async () => {
  const beforeCounts = await privacyCounts();
  console.log(`ACCOUNT_DELETION_COUNTS_BEFORE=${JSON.stringify(beforeCounts)}`);
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
  assert.equal((await pool.query('SELECT 1 FROM auth_phone_identities WHERE user_id=$1', [deletedId])).rowCount, 0);
  assert.equal((await pool.query('SELECT 1 FROM auth_sessions WHERE user_id=$1', [deletedId])).rowCount, 0);
  assert.equal((await pool.query('SELECT 1 FROM auth_password_verifications WHERE user_id=$1', [deletedId])).rowCount, 0);
  assert.equal((await pool.query("SELECT 1 FROM auth_otp_challenges WHERE phone_normalized='+77000000001'")).rowCount, 0);

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
  assert.equal(ownOrder.id, passengerOrderId);
  assert.equal(ownOrder.status, 'completed');
  assert.equal(ownOrder.passenger_price, 1000);
  assert.equal(ownOrder.agreed_price, 1000);
  assert.ok(ownOrder.created_at);
  assert.ok(ownOrder.completed_at);
  const stops = await pool.query(
    'SELECT id, order_id, address, latitude, longitude FROM order_stops WHERE id=ANY($1::uuid[]) ORDER BY id',
    [[stopId, secondStopId]],
  );
  assert.equal(stops.rowCount, 2);
  for (const stop of stops.rows) {
    assert.equal(stop.address, null);
    assert.equal(stop.latitude, null);
    assert.equal(stop.longitude, null);
    assert.equal(stop.order_id, passengerOrderId);
  }
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
  const ride = (await pool.query(
    `SELECT origin_lat, origin_lng, destination_lat, destination_lng, comment
       FROM intercity_rides WHERE id=$1`,
    [rideId],
  )).rows[0];
  assert.equal(ride.comment, null);
  assert.equal(ride.origin_lat, null);
  assert.equal(ride.origin_lng, null);
  assert.equal(ride.destination_lat, null);
  assert.equal(ride.destination_lng, null);
  assert.equal((await pool.query('SELECT pickup_address FROM intercity_ride_bookings WHERE passenger_id=$1', [deletedId])).rows[0].pickup_address, null);
  assert.equal((await pool.query('SELECT pickup_address FROM intercity_ride_requests WHERE passenger_id=$1', [deletedId])).rows[0].pickup_address, null);

  const job = (await pool.query('SELECT * FROM account_deletion_jobs WHERE user_id=$1', [deletedId])).rows[0];
  assert.equal(job.firebase_uid_hash, firebaseUidHash('delete-fixture-uid'));
  assert.equal(job.status, 'pending');
  assert.equal(job.firebase_uid, 'delete-fixture-uid');
  assert.equal((await pool.query(
    'SELECT count(*)::int AS count FROM ratings WHERE from_user_id=$1 OR to_user_id=$1',
    [deletedId],
  )).rows[0].count, 2);
  assert.equal((await pool.query(
    'SELECT count(*)::int AS count FROM content_reports WHERE reporter_user_id=$1 OR reported_user_id=$1',
    [deletedId],
  )).rows[0].count, 1);

  const afterCounts = await privacyCounts();
  console.log(`ACCOUNT_DELETION_COUNTS_AFTER=${JSON.stringify(afterCounts)}`);
  for (const table of ['users', 'orders', 'order_stops', 'messages', 'reviews']) {
    assert.equal(afterCounts[table], beforeCounts[table], table);
  }
  assert.equal(afterCounts.driver_profiles, beforeCounts.driver_profiles - 1);
  assert.equal(afterCounts.otp_records, beforeCounts.otp_records - 1);
  assert.equal(afterCounts.password_records, beforeCounts.password_records - 1);
});

test('successful Firebase deletion clears raw UID while transient failure remains retryable', async () => {
  const mainJob = (await pool.query(
    'SELECT * FROM account_deletion_jobs WHERE user_id=$1',
    [deletedId],
  )).rows[0];
  const claimedMain = await claimAccountDeletionJob({ pool, jobId: mainJob.id });
  const completed = await processClaimedFirebaseDeletion({
    pool,
    job: claimedMain,
    deleteFirebaseUser: async () => {},
  });
  assert.equal(completed.status, 'completed');
  assert.deepEqual((await pool.query(
    'SELECT status, firebase_uid FROM account_deletion_jobs WHERE id=$1',
    [mainJob.id],
  )).rows[0], { status: 'completed', firebase_uid: null });

  const retryUid = 'retryable-fixture-uid';
  const retryUser = (await pool.query(
    `INSERT INTO users (firebase_uid, phone, name)
     VALUES ($1, '+77000000005', 'Retry Fixture') RETURNING id`,
    [retryUid],
  )).rows[0];
  const retryDeletion = await beginAccountDeletion({ pool, firebaseUid: retryUid });
  const retryClaim = await claimAccountDeletionJob({
    pool,
    jobId: retryDeletion.job.id,
  });
  const retryResult = await processClaimedFirebaseDeletion({
    pool,
    job: retryClaim,
    deleteFirebaseUser: async () => {
      const error = new Error('controlled transient Firebase failure');
      error.code = 'auth/internal-error';
      throw error;
    },
  });
  assert.equal(retryResult.status, 'pending');
  const retryStored = (await pool.query(
    `SELECT status, firebase_uid, attempt_count, next_attempt_at
       FROM account_deletion_jobs WHERE user_id=$1`,
    [retryUser.id],
  )).rows[0];
  assert.equal(retryStored.status, 'pending');
  assert.equal(retryStored.firebase_uid, retryUid);
  assert.equal(retryStored.attempt_count, 1);
  assert.ok(retryStored.next_attempt_at);
});

test('auth history cleanup deletes only expired/used records and preserves active windows', async () => {
  const cleanupUser = (await pool.query(
    `INSERT INTO users (firebase_uid, phone, name)
     VALUES ('auth-cleanup-fixture', '+77000000006', 'Auth Cleanup') RETURNING id`,
  )).rows[0];
  const expiredOtp = '97000000-0000-4000-8000-000000000001';
  const resendOtp = '97000000-0000-4000-8000-000000000002';
  const activeOtp = '97000000-0000-4000-8000-000000000003';
  await pool.query(
    `INSERT INTO auth_otp_challenges (
       id, phone_normalized, code_hash, purpose, created_at, expires_at,
       max_attempts, resend_available_at
     ) VALUES
       ($1, '+77000000007', repeat('e',64), 'reset', now()-interval '2 hours', now()-interval '1 hour', 5, now()-interval '1 hour'),
       ($2, '+77000000008', repeat('f',64), 'reset', now()-interval '2 hours', now()-interval '1 hour', 5, now()+interval '1 minute'),
       ($3, '+77000000009', repeat('1',64), 'reset', now(), now()+interval '10 minutes', 5, now()+interval '1 minute')`,
    [expiredOtp, resendOtp, activeOtp],
  );
  await pool.query(
    `INSERT INTO auth_password_verifications (
       challenge_id, user_id, phone_normalized, purpose, token_hash,
       created_at, expires_at
     ) VALUES ($1, $2, '+77000000009', 'reset', repeat('2',64), now(), now()+interval '10 minutes')`,
    [activeOtp, cleanupUser.id],
  );
  const expiredSession = (await pool.query(
    `INSERT INTO auth_sessions (
       user_id, refresh_token_hash, created_at, expires_at
     ) VALUES ($1, repeat('3',64), now()-interval '2 hours', now()-interval '1 hour') RETURNING id`,
    [cleanupUser.id],
  )).rows[0].id;
  const activeSession = (await pool.query(
    `INSERT INTO auth_sessions (user_id, refresh_token_hash, expires_at)
     VALUES ($1, repeat('4',64), now()+interval '1 hour') RETURNING id`,
    [cleanupUser.id],
  )).rows[0].id;

  const cleaned = await cleanupExpiredAuthHistory({ pool, limit: 100 });
  assert.ok(cleaned.otpChallenges >= 1);
  assert.ok(cleaned.sessions >= 1);
  assert.equal((await pool.query('SELECT 1 FROM auth_otp_challenges WHERE id=$1', [expiredOtp])).rowCount, 0);
  assert.equal((await pool.query('SELECT 1 FROM auth_otp_challenges WHERE id=$1', [resendOtp])).rowCount, 1);
  assert.equal((await pool.query('SELECT 1 FROM auth_otp_challenges WHERE id=$1', [activeOtp])).rowCount, 1);
  assert.equal((await pool.query('SELECT 1 FROM auth_password_verifications WHERE challenge_id=$1', [activeOtp])).rowCount, 1);
  assert.equal((await pool.query('SELECT 1 FROM auth_sessions WHERE id=$1', [expiredSession])).rowCount, 0);
  assert.equal((await pool.query('SELECT 1 FROM auth_sessions WHERE id=$1', [activeSession])).rowCount, 1);
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
