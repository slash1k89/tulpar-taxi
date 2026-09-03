import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test, { after, before, beforeEach } from 'node:test';

import express from 'express';
import supertest from 'supertest';

import { createIntercityRidesRouter } from '../src/routes/intercity-rides.js';
import {
  assertConnectedToSafeTestDatabase,
  createIntegrationPool,
} from './test-db.js';

const ids = Object.freeze({
  driver: '10000000-0000-4000-8000-000000000001',
  passengerA: '10000000-0000-4000-8000-000000000002',
  passengerB: '10000000-0000-4000-8000-000000000003',
  passengerC: '10000000-0000-4000-8000-000000000004',
  rideA: '20000000-0000-4000-8000-000000000001',
  rideB: '20000000-0000-4000-8000-000000000002',
  rideC: '20000000-0000-4000-8000-000000000003',
  rideD: '20000000-0000-4000-8000-000000000004',
  requestA: '30000000-0000-4000-8000-000000000001',
  bookingA: '40000000-0000-4000-8000-000000000001',
  clientA: '50000000-0000-4000-8000-000000000001',
  clientB: '50000000-0000-4000-8000-000000000002',
  clientC: '50000000-0000-4000-8000-000000000003',
});

const uids = Object.freeze({
  driver: 'integration-driver-uid',
  passengerA: 'integration-passenger-a-uid',
  passengerB: 'integration-passenger-b-uid',
  passengerC: 'integration-passenger-c-uid',
});

const dayMilliseconds = 86_400_000;
const expectedDatabase = String(process.env.POSTGRES_DB ?? '').trim();
const adminPool = createIntegrationPool('intercity-integration-admin');
const mainPool = createIntegrationPool('intercity-integration-main');
const requestFirstPool = createIntegrationPool('intercity-request-first');
const rideFirstPool = createIntegrationPool('intercity-ride-first');

function futureTravelDate(days = 3) {
  return new Date(Date.now() + days * dayMilliseconds + 5 * 3_600_000)
    .toISOString()
    .slice(0, 10);
}

function departureAt(travelDate = futureTravelDate(), hour = 12) {
  return `${travelDate}T${String(hour).padStart(2, '0')}:00:00+05:00`;
}

function appFor(pool) {
  const app = express();
  app.use(express.json());
  app.use(
    '/api/intercity-rides',
    createIntercityRidesRouter({
      pool,
      requireAuth(req, res, next) {
        const uid = req.get('x-integration-uid');
        if (!uid) return res.status(401).json({ error: 'Authentication required' });
        req.user = { uid };
        return next();
      },
      sendPushToUser: async () => ({ successCount: 1, failureCount: 0 }),
    }),
  );
  return app;
}

const app = appFor(mainPool);
const requestFirstApp = appFor(requestFirstPool);
const rideFirstApp = appFor(rideFirstPool);

async function resetFixtures() {
  await adminPool.query(
    `TRUNCATE TABLE
       intercity_ride_request_notifications,
       intercity_ride_requests,
       intercity_ride_bookings,
       intercity_rides,
       driver_subscriptions,
       driver_profiles,
       users
     CASCADE`,
  );
  await adminPool.query(
    `INSERT INTO users (id, firebase_uid, phone, name) VALUES
       ($1, $2, '+77000000001', 'Integration Driver'),
       ($3, $4, '+77000000002', 'Integration Passenger A'),
       ($5, $6, '+77000000003', 'Integration Passenger B'),
       ($7, $8, '+77000000004', 'Integration Passenger C')`,
    [
      ids.driver,
      uids.driver,
      ids.passengerA,
      uids.passengerA,
      ids.passengerB,
      uids.passengerB,
      ids.passengerC,
      uids.passengerC,
    ],
  );
  await adminPool.query(
    `INSERT INTO driver_profiles (
       user_id, status, car_model, car_color, car_number, access_exempt
     ) VALUES ($1, 'active', 'Integration Car', 'Blue', 'TEST-001', true)`,
    [ids.driver],
  );
}

async function seedRide({
  id = ids.rideA,
  totalSeats = 3,
  availableSeats = totalSeats,
  pricePerSeat = 4000,
  departure = departureAt(),
  status = 'scheduled',
} = {}) {
  const result = await adminPool.query(
    `INSERT INTO intercity_rides (
       id, driver_id, origin_city, origin_city_key,
       origin_lat, origin_lng, destination_city, destination_city_key,
       destination_lat, destination_lng, departure_at, total_seats,
       available_seats, price_per_seat, allows_luggage, status
     ) VALUES (
       $1, $2, 'Костанай', 'костанай', 53.2, 63.6,
       'Есиль', 'есиль', 51.9, 66.4, $3, $4, $5, $6, true, $7
     ) RETURNING *`,
    [
      id,
      ids.driver,
      departure,
      totalSeats,
      availableSeats,
      pricePerSeat,
      status,
    ],
  );
  return result.rows[0];
}

async function seedRequest({
  id = ids.requestA,
  passengerId = ids.passengerA,
  travelDate = futureTravelDate(),
  seats = 1,
  status = 'active',
} = {}) {
  const result = await adminPool.query(
    `INSERT INTO intercity_ride_requests (
       id, passenger_id, origin_city, origin_city_key,
       destination_city, destination_city_key, travel_date, seats, status
     ) VALUES ($1, $2, 'Костанай', 'костанай', 'Есиль', 'есиль', $3, $4, $5)
     RETURNING *`,
    [id, passengerId, travelDate, seats, status],
  );
  return result.rows[0];
}

function bookingRequest(
  rideId,
  uid,
  clientRequestId,
  seats = 1,
  targetApp = app,
) {
  return supertest(targetApp)
    .post(`/api/intercity-rides/${rideId}/book`)
    .set('x-integration-uid', uid)
    .send({ seats, clientRequestId });
}

function createRideRequest(targetApp = app, travelDate = futureTravelDate()) {
  return supertest(targetApp)
    .post('/api/intercity-rides')
    .set('x-integration-uid', uids.driver)
    .send({
      originCity: 'Костанай',
      destinationCity: 'Есиль',
      originLat: 53.2,
      originLng: 63.6,
      destinationLat: 51.9,
      destinationLng: 66.4,
      departureAt: departureAt(travelDate),
      totalSeats: 3,
      pricePerSeat: 4000,
      allowsLuggage: true,
    });
}

function createPassengerRequest(targetApp = app, travelDate = futureTravelDate()) {
  return supertest(targetApp)
    .post('/api/intercity-rides/requests')
    .set('x-integration-uid', uids.passengerA)
    .send({
      originCity: 'Костанай',
      destinationCity: 'Есиль',
      travelDate,
      seats: 1,
    });
}

async function rideState(rideId = ids.rideA) {
  const result = await adminPool.query(
    `SELECT r.*,
       COALESCE(sum(b.seats) FILTER (WHERE b.status = 'confirmed'), 0)::integer
         AS confirmed_seats
     FROM intercity_rides r
     LEFT JOIN intercity_ride_bookings b ON b.ride_id = r.id
     WHERE r.id = $1
     GROUP BY r.id`,
    [rideId],
  );
  return result.rows[0];
}

async function assertScheduledInventory(rideId = ids.rideA) {
  const state = await rideState(rideId);
  assert.ok(state.available_seats >= 0);
  assert.ok(state.available_seats <= state.total_seats);
  assert.equal(
    state.available_seats,
    state.total_seats - state.confirmed_seats,
  );
  return state;
}

async function expectDatabaseError(sql, params, expectedCode) {
  const client = await adminPool.connect();
  try {
    await client.query('BEGIN');
    await assert.rejects(
      client.query(sql, params),
      (error) => error.code === expectedCode,
    );
  } finally {
    await client.query('ROLLBACK');
    client.release();
  }
}

async function waitForAdvisoryWait(applicationName) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const result = await adminPool.query(
      `SELECT 1 FROM pg_stat_activity
        WHERE application_name = $1
          AND wait_event_type = 'Lock'
          AND wait_event = 'advisory'`,
      [applicationName],
    );
    if (result.rowCount > 0) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error(`${applicationName} did not reach the advisory-lock barrier`);
}

async function matchingRace({ requestFirst }) {
  const blocker = await adminPool.connect();
  const travelDate = futureTravelDate();
  const lockKey = JSON.stringify([
    'костанай',
    'есиль',
    travelDate,
  ]);
  try {
    await blocker.query('BEGIN');
    await blocker.query(
      'SELECT pg_advisory_xact_lock(141500, hashtext($1))',
      [lockKey],
    );

    const first = Promise.resolve(
      requestFirst
        ? createPassengerRequest(requestFirstApp, travelDate)
        : createRideRequest(rideFirstApp, travelDate),
    );
    await waitForAdvisoryWait(
      requestFirst ? 'intercity-request-first' : 'intercity-ride-first',
    );
    const second = Promise.resolve(
      requestFirst
        ? createRideRequest(rideFirstApp, travelDate)
        : createPassengerRequest(requestFirstApp, travelDate),
    );
    await waitForAdvisoryWait(
      requestFirst ? 'intercity-ride-first' : 'intercity-request-first',
    );

    await blocker.query('COMMIT');
    return Promise.all([first, second]);
  } catch (error) {
    await blocker.query('ROLLBACK');
    throw error;
  } finally {
    blocker.release();
  }
}

before(async () => {
  await Promise.all([
    assertConnectedToSafeTestDatabase(adminPool, expectedDatabase),
    assertConnectedToSafeTestDatabase(mainPool, expectedDatabase),
    assertConnectedToSafeTestDatabase(requestFirstPool, expectedDatabase),
    assertConnectedToSafeTestDatabase(rideFirstPool, expectedDatabase),
  ]);
});

beforeEach(resetFixtures);

after(async () => {
  await Promise.all([
    adminPool.end(),
    mainPool.end(),
    requestFirstPool.end(),
    rideFirstPool.end(),
  ]);
});

test('migration creates required tables, constraints and indexes and is one-time', async () => {
  const tables = await adminPool.query(
    `SELECT table_name FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = ANY($1::text[])`,
    [[
      'intercity_rides',
      'intercity_ride_bookings',
      'intercity_ride_requests',
      'intercity_ride_request_notifications',
    ]],
  );
  assert.equal(tables.rowCount, 4);

  const constraints = await adminPool.query(
    `SELECT conname FROM pg_constraint
      WHERE connamespace = 'public'::regnamespace
        AND conname = ANY($1::text[])`,
    [[
      'intercity_rides_seats',
      'intercity_rides_status',
      'intercity_ride_bookings_idempotency',
      'intercity_ride_requests_cities_different',
      'intercity_ride_request_notifications_unique',
    ]],
  );
  assert.equal(constraints.rowCount, 5);

  const pickupColumns = await adminPool.query(
    `SELECT table_name, column_name FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name IN ('intercity_ride_bookings', 'intercity_ride_requests')
        AND column_name IN (
          'pickup_address', 'pickup_lat', 'pickup_lng', 'passenger_comment'
        )`,
  );
  assert.equal(pickupColumns.rowCount, 8);

  const pickupConstraints = await adminPool.query(
    `SELECT conname FROM pg_constraint
      WHERE connamespace = 'public'::regnamespace
        AND conname = ANY($1::text[])`,
    [[
      'intercity_ride_bookings_pickup_complete',
      'intercity_ride_bookings_pickup_lat',
      'intercity_ride_bookings_pickup_lng',
      'intercity_ride_requests_pickup_complete',
      'intercity_ride_requests_pickup_lat',
      'intercity_ride_requests_pickup_lng',
    ]],
  );
  assert.equal(pickupConstraints.rowCount, 6);

  const indexes = await adminPool.query(
    `SELECT indexname FROM pg_indexes
      WHERE schemaname = 'public' AND indexname = ANY($1::text[])`,
    [[
      'idx_intercity_rides_search',
      'idx_intercity_rides_driver',
      'idx_intercity_ride_booking_active_passenger',
      'idx_intercity_ride_bookings_ride_status',
      'idx_intercity_ride_bookings_passenger',
      'idx_intercity_ride_requests_match',
      'idx_intercity_ride_requests_passenger',
      'idx_intercity_ride_notifications_ride',
    ]],
  );
  assert.equal(indexes.rowCount, 8);

  const migration = await readFile(
    new URL('../migrations/20260825_002_intercity_rides.sql', import.meta.url),
    'utf8',
  );
  const client = await adminPool.connect();
  try {
    await assert.rejects(
      client.query(migration),
      (error) => error.code === '42P07',
    );
    await client.query('ROLLBACK');
  } finally {
    client.release();
  }
  const preserved = await adminPool.query(
    `SELECT to_regclass('public.intercity_rides') AS relation`,
  );
  assert.equal(preserved.rows[0].relation, 'intercity_rides');
});

test('migration 003 accepts legacy and complete pickup but rejects invalid database values', async () => {
  await seedRide();
  await adminPool.query(
    `INSERT INTO intercity_ride_bookings
       (id, ride_id, passenger_id, seats, price_per_seat, client_request_id)
     VALUES ($1, $2, $3, 1, 4000, $4)`,
    [ids.bookingA, ids.rideA, ids.passengerA, ids.clientA],
  );
  const legacy = await adminPool.query(
    `SELECT pickup_address, pickup_lat, pickup_lng, passenger_comment
       FROM intercity_ride_bookings WHERE id = $1`,
    [ids.bookingA],
  );
  assert.deepEqual(legacy.rows[0], {
    pickup_address: null,
    pickup_lat: null,
    pickup_lng: null,
    passenger_comment: null,
  });

  await adminPool.query(
    `INSERT INTO intercity_ride_bookings
       (ride_id, passenger_id, seats, price_per_seat, client_request_id,
        pickup_address, pickup_lat, pickup_lng, passenger_comment)
     VALUES ($1, $2, 1, 4000, $3, 'ул. Абая, 15', 51.16, 71.47, 'Вход')`,
    [ids.rideA, ids.passengerB, ids.clientB],
  );

  const invalidValues = [
    ['Адрес', 51, null],
    ['', 51, 71],
    ['Адрес', 91, 71],
    ['Адрес', 51, 181],
    ['Адрес', Number.NaN, 71],
    ['Адрес', 51, Infinity],
  ];
  for (const [address, lat, lng] of invalidValues) {
    await expectDatabaseError(
      `INSERT INTO intercity_ride_requests (
         passenger_id, origin_city, origin_city_key,
         destination_city, destination_city_key, travel_date, seats,
         pickup_address, pickup_lat, pickup_lng
       ) VALUES ($1, 'Костанай', 'костанай', 'Есиль', 'есиль', $2, 1,
                 $3, $4, $5)`,
      [ids.passengerC, futureTravelDate(), address, lat, lng],
      '23514',
    );
  }

  const migration = await readFile(
    new URL('../migrations/20260826_003_intercity_pickup_points.sql', import.meta.url),
    'utf8',
  );
  assert.doesNotMatch(
    migration,
    /DROP\s|ADD COLUMN pickup_[^,\n]*NOT NULL/iu,
  );
});

test('two passengers competing for the last seat produce one booking', async () => {
  await seedRide({ totalSeats: 1 });
  const responses = await Promise.all([
    bookingRequest(ids.rideA, uids.passengerA, ids.clientA),
    bookingRequest(ids.rideA, uids.passengerB, ids.clientB),
  ]);
  assert.deepEqual(responses.map((response) => response.status).sort(), [201, 409]);
  const state = await assertScheduledInventory();
  assert.equal(state.confirmed_seats, 1);
  assert.equal(state.available_seats, 0);
});

test('concurrent identical clientRequestId creates one booking and decrements once', async () => {
  await seedRide({ totalSeats: 2 });
  const responses = await Promise.all([
    bookingRequest(ids.rideA, uids.passengerA, ids.clientA),
    bookingRequest(ids.rideA, uids.passengerA, ids.clientA),
  ]);
  assert.deepEqual(responses.map((response) => response.status).sort(), [200, 201]);
  assert.equal(
    (await adminPool.query('SELECT count(*) FROM intercity_ride_bookings')).rows[0].count,
    '1',
  );
  const state = await assertScheduledInventory();
  assert.equal(state.available_seats, 1);
});

test('concurrent different clientRequestIds leave one confirmed booking per passenger', async () => {
  await seedRide({ totalSeats: 2 });
  const responses = await Promise.all([
    bookingRequest(ids.rideA, uids.passengerA, ids.clientA),
    bookingRequest(ids.rideA, uids.passengerA, ids.clientB),
  ]);
  assert.deepEqual(responses.map((response) => response.status).sort(), [201, 409]);
  assert.equal(
    (await adminPool.query(
      `SELECT count(*) FROM intercity_ride_bookings
        WHERE ride_id = $1 AND passenger_id = $2 AND status = 'confirmed'`,
      [ids.rideA, ids.passengerA],
    )).rows[0].count,
    '1',
  );
  await assertScheduledInventory();
});

test('booking racing driver cancellation has a consistent serialized result', async () => {
  await seedRide({ totalSeats: 2 });
  const [booking, cancellation] = await Promise.all([
    bookingRequest(ids.rideA, uids.passengerA, ids.clientA),
    supertest(app)
      .post(`/api/intercity-rides/${ids.rideA}/cancel`)
      .set('x-integration-uid', uids.driver),
  ]);
  assert.ok([201, 409].includes(booking.status));
  assert.equal(cancellation.status, 200);
  const state = await rideState();
  assert.equal(state.status, 'cancelled');
  assert.equal(state.available_seats, state.total_seats);
  assert.equal(state.confirmed_seats, 0);
});

test('booking racing departure preserves inventory and lifecycle invariants', async () => {
  await seedRide({ totalSeats: 2 });
  const [booking, departure] = await Promise.all([
    bookingRequest(ids.rideA, uids.passengerA, ids.clientA),
    supertest(app)
      .post(`/api/intercity-rides/${ids.rideA}/depart`)
      .set('x-integration-uid', uids.driver),
  ]);
  assert.ok([201, 409].includes(booking.status));
  assert.equal(departure.status, 200);
  const state = await rideState();
  assert.equal(state.status, 'departed');
  assert.equal(
    state.available_seats,
    state.total_seats - state.confirmed_seats,
  );
});

test('booking racing price update snapshots the serialized ride price', async () => {
  await seedRide({ totalSeats: 2, pricePerSeat: 4000 });
  const [booking, update] = await Promise.all([
    bookingRequest(ids.rideA, uids.passengerA, ids.clientA),
    supertest(app)
      .patch(`/api/intercity-rides/${ids.rideA}`)
      .set('x-integration-uid', uids.driver)
      .send({ pricePerSeat: 7000 }),
  ]);
  assert.equal(booking.status, 201);
  assert.equal(update.status, 200);
  const stored = await adminPool.query(
    `SELECT b.price_per_seat AS booking_price, r.price_per_seat AS ride_price
       FROM intercity_ride_bookings b
       JOIN intercity_rides r ON r.id = b.ride_id
      WHERE b.ride_id = $1`,
    [ids.rideA],
  );
  assert.ok([4000, 7000].includes(stored.rows[0].booking_price));
  assert.equal(stored.rows[0].ride_price, 7000);
  await assertScheduledInventory();
});

test('two concurrent booking cancellations restore seats exactly once', async () => {
  await seedRide({ totalSeats: 2 });
  const created = await bookingRequest(
    ids.rideA,
    uids.passengerA,
    ids.clientA,
  );
  assert.equal(created.status, 201);
  const bookingId = created.body.booking.bookingId;
  const responses = await Promise.all([
    supertest(app)
      .post(`/api/intercity-rides/bookings/${bookingId}/cancel`)
      .set('x-integration-uid', uids.passengerA),
    supertest(app)
      .post(`/api/intercity-rides/bookings/${bookingId}/cancel`)
      .set('x-integration-uid', uids.passengerA),
  ]);
  assert.deepEqual(responses.map((response) => response.status), [200, 200]);
  const state = await rideState();
  assert.equal(state.available_seats, state.total_seats);
  assert.equal(state.confirmed_seats, 0);
  const booking = await adminPool.query(
    'SELECT status, cancelled_at FROM intercity_ride_bookings WHERE id = $1',
    [bookingId],
  );
  assert.equal(booking.rows[0].status, 'cancelled');
  assert.ok(booking.rows[0].cancelled_at);
});

test('passenger cancellation racing ride cancellation never double-restores inventory', async () => {
  await seedRide({ totalSeats: 2 });
  const created = await bookingRequest(
    ids.rideA,
    uids.passengerA,
    ids.clientA,
  );
  const bookingId = created.body.booking.bookingId;
  const [passengerCancellation, driverCancellation] = await Promise.all([
    supertest(app)
      .post(`/api/intercity-rides/bookings/${bookingId}/cancel`)
      .set('x-integration-uid', uids.passengerA),
    supertest(app)
      .post(`/api/intercity-rides/${ids.rideA}/cancel`)
      .set('x-integration-uid', uids.driver),
  ]);
  assert.equal(passengerCancellation.status, 200);
  assert.equal(driverCancellation.status, 200);
  const state = await rideState();
  assert.equal(state.status, 'cancelled');
  assert.equal(state.available_seats, state.total_seats);
  assert.equal(state.confirmed_seats, 0);
});

test('request-first advisory-lock race creates exactly one matching notification', async () => {
  const responses = await matchingRace({ requestFirst: true });
  assert.deepEqual(responses.map((response) => response.status), [201, 201]);
  const counts = await adminPool.query(
    `SELECT
       (SELECT count(*) FROM intercity_ride_requests) AS requests,
       (SELECT count(*) FROM intercity_rides) AS rides,
       (SELECT count(*) FROM intercity_ride_request_notifications) AS notifications`,
  );
  assert.deepEqual(counts.rows[0], {
    requests: '1',
    rides: '1',
    notifications: '1',
  });
});

test('ride-first advisory-lock race creates exactly one matching notification', async () => {
  const responses = await matchingRace({ requestFirst: false });
  assert.deepEqual(responses.map((response) => response.status), [201, 201]);
  const counts = await adminPool.query(
    `SELECT
       (SELECT count(*) FROM intercity_ride_requests) AS requests,
       (SELECT count(*) FROM intercity_rides) AS rides,
       (SELECT count(*) FROM intercity_ride_request_notifications) AS notifications`,
  );
  assert.deepEqual(counts.rows[0], {
    requests: '1',
    rides: '1',
    notifications: '1',
  });
});

test('Kazakhstan calendar matching uses UTC+5 around the UTC date boundary', async () => {
  const travelDate = futureTravelDate(30);
  const start = Date.parse(`${travelDate}T00:00:00+05:00`);
  await seedRide({
    id: ids.rideA,
    departure: new Date(start + 30 * 60_000).toISOString(),
  });
  await seedRide({
    id: ids.rideB,
    departure: new Date(start + 23.5 * 3_600_000).toISOString(),
  });
  await seedRide({
    id: ids.rideC,
    departure: new Date(start - 30 * 60_000).toISOString(),
  });
  await seedRide({
    id: ids.rideD,
    departure: new Date(start + 24.5 * 3_600_000).toISOString(),
  });

  const created = await supertest(app)
    .post('/api/intercity-rides/requests')
    .set('x-integration-uid', uids.passengerA)
    .send({
      originCity: 'Костанай',
      destinationCity: 'Есиль',
      travelDate,
      seats: 1,
    });
  assert.equal(created.status, 201);
  assert.deepEqual(
    created.body.request.matchedRideIds.sort(),
    [ids.rideA, ids.rideB].sort(),
  );

  const search = await supertest(app)
    .get('/api/intercity-rides/search')
    .set('x-integration-uid', uids.passengerA)
    .query({
      originCity: 'Костанай',
      destinationCity: 'Есиль',
      travelDate,
      seats: 1,
    });
  assert.equal(search.status, 200);
  assert.deepEqual(
    search.body.rides.map((ride) => ride.rideId).sort(),
    [ids.rideA, ids.rideB].sort(),
  );
});

test('database constraints reject invalid inventory, seats, status, duplicates and FK', async () => {
  await seedRide({ totalSeats: 2 });
  await expectDatabaseError(
    'UPDATE intercity_rides SET available_seats = -1 WHERE id = $1',
    [ids.rideA],
    '23514',
  );
  await expectDatabaseError(
    'UPDATE intercity_rides SET available_seats = total_seats + 1 WHERE id = $1',
    [ids.rideA],
    '23514',
  );
  await expectDatabaseError(
    `INSERT INTO intercity_ride_bookings (
       ride_id, passenger_id, seats, price_per_seat, client_request_id
     ) VALUES ($1, $2, 0, 4000, $3)`,
    [ids.rideA, ids.passengerA, ids.clientA],
    '23514',
  );
  await expectDatabaseError(
    "UPDATE intercity_rides SET status = 'invalid' WHERE id = $1",
    [ids.rideA],
    '23514',
  );

  await adminPool.query(
    `INSERT INTO intercity_ride_bookings (
       id, ride_id, passenger_id, seats, price_per_seat, client_request_id
     ) VALUES ($1, $2, $3, 1, 4000, $4)`,
    [ids.bookingA, ids.rideA, ids.passengerA, ids.clientA],
  );
  await expectDatabaseError(
    `INSERT INTO intercity_ride_bookings (
       ride_id, passenger_id, seats, price_per_seat, client_request_id
     ) VALUES ($1, $2, 1, 4000, $3)`,
    [ids.rideA, ids.passengerA, ids.clientB],
    '23505',
  );

  await seedRequest();
  await adminPool.query(
    `INSERT INTO intercity_ride_request_notifications (request_id, ride_id)
     VALUES ($1, $2)`,
    [ids.requestA, ids.rideA],
  );
  await expectDatabaseError(
    `INSERT INTO intercity_ride_request_notifications (request_id, ride_id)
     VALUES ($1, $2)`,
    [ids.requestA, ids.rideA],
    '23505',
  );
  await expectDatabaseError(
    `INSERT INTO intercity_rides (
       driver_id, origin_city, origin_city_key,
       destination_city, destination_city_key, departure_at,
       total_seats, available_seats, price_per_seat
     ) VALUES ($1, 'A', 'a', 'B', 'b', now() + interval '1 day', 1, 1, 1)`,
    ['99999999-9999-4999-8999-999999999999'],
    '23503',
  );
});
