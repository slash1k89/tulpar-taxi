import assert from 'node:assert/strict';
import test, { after, before, beforeEach } from 'node:test';

import express from 'express';
import request from 'supertest';

import {
  beginAccountDeletion,
  claimAccountDeletionJob,
  firebaseUidHash,
  processClaimedFirebaseDeletion,
  retryPendingAccountDeletions,
} from '../src/account-deletion.js';
import { acquireAccountLifecycleLock } from '../src/account-lifecycle.js';
import { createIntercityRidesRouter } from '../src/routes/intercity-rides.js';
import { createOrdersRouter } from '../src/routes/orders.js';
import { syncActiveUser } from '../src/user-sync.js';
import {
  assertConnectedToSafeTestDatabase,
  createIntegrationPool,
} from './test-db.js';

const pool = createIntegrationPool('account-deletion-concurrency');
let sequence = 0;

function identity(label) {
  sequence += 1;
  return `${label}-${sequence}-fixture-uid`;
}

function authFor(firebaseUid) {
  return (req, _res, next) => {
    req.user = { uid: firebaseUid };
    next();
  };
}

function intercityApp(firebaseUid) {
  const app = express();
  app.use(express.json());
  app.use('/api/intercity-rides', createIntercityRidesRouter({
    pool,
    requireAuth: authFor(firebaseUid),
  }));
  return app;
}

function ordersApp(firebaseUid) {
  const app = express();
  app.use(express.json());
  app.use('/api/orders', createOrdersRouter({
    pool,
    requireAuth: authFor(firebaseUid),
    sendToUser: () => {},
    sendToAvailableDrivers: () => {},
    sendPushToUser: async () => ({ successCount: 0, failureCount: 0 }),
  }));
  return app;
}

async function insertUser(firebaseUid, { driver = false } = {}) {
  const result = await pool.query(
    `INSERT INTO users (firebase_uid, phone, name)
     VALUES ($1, '+70000000000', 'Concurrency Fixture')
     RETURNING id`,
    [firebaseUid],
  );
  const userId = result.rows[0].id;
  if (driver) {
    await pool.query(
      `INSERT INTO driver_profiles (
         user_id, status, car_model, car_color, car_number, access_exempt
       ) VALUES ($1, 'active', 'Fixture Car', 'Fixture Color', 'FIXTURE', true)`,
      [userId],
    );
  }
  return userId;
}

async function insertScheduledRide(driverId, { seats = 3 } = {}) {
  const result = await pool.query(
    `INSERT INTO intercity_rides (
       driver_id, origin_city, origin_city_key, destination_city,
       destination_city_key, departure_at, total_seats, available_seats,
       price_per_seat
     ) VALUES ($1, 'Костанай', 'костанай', 'Есиль', 'есиль',
       now() + interval '3 days', $2, $2, 5000)
     RETURNING id`,
    [driverId, seats],
  );
  return result.rows[0].id;
}

async function insertSearchingOrder(passengerId) {
  const result = await pool.query(
    `INSERT INTO orders (
       passenger_id, status, passenger_price, pickup_address,
       destination_address, pickup_lat, pickup_lng, destination_lat,
       destination_lng, service_type
     ) VALUES ($1, 'searching', 1000, 'Fixture pickup',
       'Fixture destination', 51, 71, 52, 72, 'city')
     RETURNING id`,
    [passengerId],
  );
  return result.rows[0].id;
}

async function waitForAdvisoryWaiters(expected) {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const result = await pool.query(
      `SELECT count(*)::int AS count
         FROM pg_locks
        WHERE locktype = 'advisory' AND granted = false`,
    );
    if (result.rows[0].count >= expected) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error(`Timed out waiting for ${expected} advisory lock waiter(s)`);
}

async function raceBehindLifecycleGate(firebaseUid, first, second) {
  const gate = await pool.connect();
  await gate.query('BEGIN');
  await acquireAccountLifecycleLock(gate, firebaseUid);
  try {
    const firstPromise = Promise.resolve().then(first);
    await waitForAdvisoryWaiters(1);
    const secondPromise = Promise.resolve().then(second);
    await waitForAdvisoryWaiters(2);
    await gate.query('COMMIT');
    return await Promise.all([firstPromise, secondPromise]);
  } catch (error) {
    await gate.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    gate.release();
  }
}

async function makeDeletionJob(label) {
  const firebaseUid = identity(label);
  const userId = await insertUser(firebaseUid);
  const deletion = await beginAccountDeletion({ pool, firebaseUid });
  assert.equal(deletion.kind, 'created');
  return { firebaseUid, userId, job: deletion.job };
}

before(async () => {
  await assertConnectedToSafeTestDatabase(pool, process.env.POSTGRES_DB);
  await pool.query(
    `INSERT INTO service_types (code, name)
     VALUES ('city', 'Taxi'), ('delivery', 'Delivery'),
            ('intercity', 'Intercity')
     ON CONFLICT (code) DO NOTHING`,
  );
});

beforeEach(async () => {
  await pool.query('TRUNCATE TABLE users CASCADE');
});

after(async () => pool.end());

test('delete winning the /users/sync race prevents tombstone resurrection', async () => {
  const firebaseUid = identity('sync-delete-wins');
  await insertUser(firebaseUid);
  const [deletion, synchronization] = await raceBehindLifecycleGate(
    firebaseUid,
    () => beginAccountDeletion({ pool, firebaseUid }),
    () => syncActiveUser({
      pool,
      firebaseUid,
      phone: '+70000000001',
      name: 'Must Not Return',
    }),
  );
  assert.equal(deletion.kind, 'created');
  assert.equal(synchronization.kind, 'deleted');
  const active = await pool.query(
    `SELECT 1 FROM users WHERE firebase_uid=$1 AND account_status='active'`,
    [firebaseUid],
  );
  assert.equal(active.rowCount, 0);
});

test('/users/sync winning the race is followed by deletion, never resurrection', async () => {
  const firebaseUid = identity('sync-wins');
  await insertUser(firebaseUid);
  const [synchronization, deletion] = await raceBehindLifecycleGate(
    firebaseUid,
    () => syncActiveUser({
      pool,
      firebaseUid,
      phone: '+70000000002',
      name: 'Updated Before Delete',
    }),
    () => beginAccountDeletion({ pool, firebaseUid }),
  );
  assert.equal(synchronization.kind, 'active');
  assert.equal(deletion.kind, 'created');
  assert.equal((await pool.query(
    `SELECT 1 FROM users WHERE firebase_uid=$1 AND account_status='active'`,
    [firebaseUid],
  )).rowCount, 0);
});

test('delete winning ride creation rejects the ride after tombstone', async () => {
  const firebaseUid = identity('ride-delete-wins');
  await insertUser(firebaseUid, { driver: true });
  const payload = {
    originCity: 'Костанай',
    destinationCity: 'Есиль',
    originLat: 53.2,
    originLng: 63.6,
    destinationLat: 51.9,
    destinationLng: 66.4,
    departureAt: new Date(Date.now() + 3 * 86_400_000).toISOString(),
    totalSeats: 3,
    pricePerSeat: 5000,
    allowsLuggage: false,
    comment: null,
  };
  const [deletion, creation] = await raceBehindLifecycleGate(
    firebaseUid,
    () => beginAccountDeletion({ pool, firebaseUid }),
    () => request(intercityApp(firebaseUid)).post('/api/intercity-rides').send(payload),
  );
  assert.equal(deletion.kind, 'created');
  assert.equal(creation.status, 410);
  assert.equal(creation.body.code, 'account_deleted');
  assert.equal((await pool.query('SELECT count(*)::int AS count FROM intercity_rides')).rows[0].count, 0);
});

test('ride creation winning the race blocks deletion', async () => {
  const firebaseUid = identity('ride-wins');
  await insertUser(firebaseUid, { driver: true });
  const payload = {
    originCity: 'Костанай', destinationCity: 'Есиль',
    departureAt: new Date(Date.now() + 3 * 86_400_000).toISOString(),
    totalSeats: 3, pricePerSeat: 5000, allowsLuggage: false,
  };
  const [creation, deletion] = await raceBehindLifecycleGate(
    firebaseUid,
    () => request(intercityApp(firebaseUid)).post('/api/intercity-rides').send(payload),
    () => beginAccountDeletion({ pool, firebaseUid }),
  );
  assert.equal(creation.status, 201);
  assert.deepEqual(deletion, { kind: 'blocked', code: 'active_ride' });
});

test('delete winning request creation rejects the request after tombstone', async () => {
  const firebaseUid = identity('request-delete-wins');
  await insertUser(firebaseUid);
  const payload = {
    originCity: 'Костанай', destinationCity: 'Есиль',
    travelDate: new Date(Date.now() + 3 * 86_400_000).toISOString().slice(0, 10),
    seats: 1,
  };
  const [deletion, creation] = await raceBehindLifecycleGate(
    firebaseUid,
    () => beginAccountDeletion({ pool, firebaseUid }),
    () => request(intercityApp(firebaseUid)).post('/api/intercity-rides/requests').send(payload),
  );
  assert.equal(deletion.kind, 'created');
  assert.equal(creation.status, 410);
  assert.equal((await pool.query('SELECT count(*)::int AS count FROM intercity_ride_requests')).rows[0].count, 0);
});

test('request creation winning the race blocks deletion', async () => {
  const firebaseUid = identity('request-wins');
  await insertUser(firebaseUid);
  const payload = {
    originCity: 'Костанай', destinationCity: 'Есиль',
    travelDate: new Date(Date.now() + 3 * 86_400_000).toISOString().slice(0, 10),
    seats: 1,
  };
  const [creation, deletion] = await raceBehindLifecycleGate(
    firebaseUid,
    () => request(intercityApp(firebaseUid)).post('/api/intercity-rides/requests').send(payload),
    () => beginAccountDeletion({ pool, firebaseUid }),
  );
  assert.equal(creation.status, 201);
  assert.deepEqual(deletion, { kind: 'blocked', code: 'active_ride_request' });
});

test('delete winning booking rejects the booking after tombstone', async () => {
  const driverUid = identity('booking-driver');
  const passengerUid = identity('booking-delete-wins');
  const driverId = await insertUser(driverUid, { driver: true });
  await insertUser(passengerUid);
  const rideId = await insertScheduledRide(driverId);
  const [deletion, booking] = await raceBehindLifecycleGate(
    passengerUid,
    () => beginAccountDeletion({ pool, firebaseUid: passengerUid }),
    () => request(intercityApp(passengerUid))
      .post(`/api/intercity-rides/${rideId}/book`)
      .send({ seats: 1, clientRequestId: 'a1000000-0000-4000-8000-000000000001' }),
  );
  assert.equal(deletion.kind, 'created');
  assert.equal(booking.status, 410);
  assert.equal((await pool.query('SELECT count(*)::int AS count FROM intercity_ride_bookings')).rows[0].count, 0);
});

test('booking winning the race blocks deletion', async () => {
  const driverId = await insertUser(identity('booking-driver'), { driver: true });
  const passengerUid = identity('booking-wins');
  await insertUser(passengerUid);
  const rideId = await insertScheduledRide(driverId);
  const [booking, deletion] = await raceBehindLifecycleGate(
    passengerUid,
    () => request(intercityApp(passengerUid))
      .post(`/api/intercity-rides/${rideId}/book`)
      .send({ seats: 1, clientRequestId: 'a2000000-0000-4000-8000-000000000002' }),
    () => beginAccountDeletion({ pool, firebaseUid: passengerUid }),
  );
  assert.equal(booking.status, 201);
  assert.deepEqual(deletion, { kind: 'blocked', code: 'active_booking' });
});

test('delete winning offer creation rejects a post-tombstone pending offer', async () => {
  const passengerId = await insertUser(identity('offer-passenger'));
  const driverUid = identity('offer-delete-wins');
  await insertUser(driverUid, { driver: true });
  const orderId = await insertSearchingOrder(passengerId);
  const [deletion, offer] = await raceBehindLifecycleGate(
    driverUid,
    () => beginAccountDeletion({ pool, firebaseUid: driverUid }),
    () => request(ordersApp(driverUid))
      .post(`/api/orders/${orderId}/offers`)
      .send({ price: 1200 }),
  );
  assert.equal(deletion.kind, 'created');
  assert.equal(offer.status, 410);
  assert.equal((await pool.query('SELECT count(*)::int AS count FROM order_offers')).rows[0].count, 0);
});

test('offer winning the race is atomically withdrawn by deletion', async () => {
  const passengerId = await insertUser(identity('offer-passenger'));
  const driverUid = identity('offer-wins');
  const driverId = await insertUser(driverUid, { driver: true });
  const orderId = await insertSearchingOrder(passengerId);
  const [offer, deletion] = await raceBehindLifecycleGate(
    driverUid,
    () => request(ordersApp(driverUid))
      .post(`/api/orders/${orderId}/offers`)
      .send({ price: 1200 }),
    () => beginAccountDeletion({ pool, firebaseUid: driverUid }),
  );
  assert.equal(offer.status, 201);
  assert.equal(deletion.kind, 'created');
  const status = await pool.query(
    'SELECT status FROM order_offers WHERE order_id=$1 AND driver_id=$2',
    [orderId, driverId],
  );
  assert.equal(status.rows[0].status, 'withdrawn');
});

test('two workers cannot claim the same deletion job', async () => {
  const { job } = await makeDeletionJob('two-workers');
  const claims = await Promise.all([
    claimAccountDeletionJob({ pool, jobId: job.id }),
    claimAccountDeletionJob({ pool, jobId: job.id }),
  ]);
  assert.equal(claims.filter(Boolean).length, 1);
});

test('an expired lease is recovered with a new claim token', async () => {
  const { job } = await makeDeletionJob('expired-lease');
  await pool.query(
    `UPDATE account_deletion_jobs
        SET claimed_at=now()-interval '10 minutes',
            lease_until=now()-interval '5 minutes',
            claim_token='b1000000-0000-4000-8000-000000000001'
      WHERE id=$1`,
    [job.id],
  );
  const claimed = await claimAccountDeletionJob({ pool, jobId: job.id });
  assert.ok(claimed);
  assert.notEqual(claimed.claim_token, 'b1000000-0000-4000-8000-000000000001');
});

test('attempt twenty is terminal and failed jobs are not auto-eligible', async () => {
  const { job, firebaseUid } = await makeDeletionJob('terminal');
  await pool.query(
    'UPDATE account_deletion_jobs SET attempt_count=19 WHERE id=$1',
    [job.id],
  );
  const claimed = await claimAccountDeletionJob({ pool, jobId: job.id });
  const outcome = await processClaimedFirebaseDeletion({
    pool,
    job: claimed,
    deleteFirebaseUser: async () => {
      const error = new Error('fixture failure');
      error.code = 'auth/internal-error';
      throw error;
    },
  });
  assert.equal(outcome.status, 'failed');
  assert.equal(await claimAccountDeletionJob({ pool, jobId: job.id }), null);
  const stored = (await pool.query(
    'SELECT status, attempt_count, firebase_uid FROM account_deletion_jobs WHERE id=$1',
    [job.id],
  )).rows[0];
  assert.deepEqual(stored, {
    status: 'failed',
    attempt_count: 20,
    firebase_uid: firebaseUid,
  });
});

test('one failed deletion job does not abort the worker batch', async () => {
  const bad = await makeDeletionJob('batch-bad');
  const good = await makeDeletionJob('batch-good');
  const processed = await retryPendingAccountDeletions({
    pool,
    limit: 2,
    deleteFirebaseUser: async (firebaseUid) => {
      if (firebaseUid === bad.firebaseUid) {
        const error = new Error('fixture transient failure');
        error.code = 'auth/internal-error';
        throw error;
      }
    },
  });
  assert.equal(processed, 2);
  const jobs = await pool.query(
    `SELECT firebase_uid_hash, status, attempt_count
       FROM account_deletion_jobs
      WHERE id=ANY($1::uuid[])`,
    [[bad.job.id, good.job.id]],
  );
  const badStored = jobs.rows.find(
    (row) => row.firebase_uid_hash === firebaseUidHash(bad.firebaseUid),
  );
  const goodStored = jobs.rows.find(
    (row) => row.firebase_uid_hash === firebaseUidHash(good.firebaseUid),
  );
  assert.equal(badStored.status, 'pending');
  assert.equal(badStored.attempt_count, 1);
  assert.equal(goodStored.status, 'completed');
});
