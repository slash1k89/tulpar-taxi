import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';
import { readFileSync } from 'node:fs';
import { createIntercityRidesRouter } from '../src/routes/intercity-rides.js';
import { validateIntercityRideBooking } from '../src/intercity-ride-policy.js';

const rideId = '11111111-1111-4111-8111-111111111111';
const otherRideId = '22222222-2222-4222-8222-222222222222';
const bookingId = '33333333-3333-4333-8333-333333333333';
const requestA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const requestB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const future = new Date(Date.now() + 86_400_000).toISOString();

function user(id, uid, name, phone) {
  return { id, firebase_uid: uid, name, phone };
}

function ride(overrides = {}) {
  return {
    id: rideId,
    driver_id: 'driver-db-id',
    origin_city: 'Костанай',
    origin_city_key: 'костанай',
    origin_lat: 53.2,
    origin_lng: 63.6,
    destination_city: 'Есиль',
    destination_city_key: 'есиль',
    destination_lat: 51.9,
    destination_lng: 66.4,
    departure_at: future,
    total_seats: 3,
    available_seats: 3,
    price_per_seat: 4000,
    allows_luggage: true,
    comment: null,
    status: 'scheduled',
    cancelled_at: null,
    departed_at: null,
    completed_at: null,
    created_at: future,
    updated_at: future,
    ...overrides,
  };
}

function makeBooking(overrides = {}) {
  return {
    id: bookingId,
    ride_id: rideId,
    passenger_id: 'passenger-a-db-id',
    seats: 1,
    price_per_seat: 4000,
    total_price: 4000,
    status: 'confirmed',
    client_request_id: requestA,
    pickup_address: null,
    pickup_lat: null,
    pickup_lng: null,
    passenger_comment: null,
    pickup_reached_at: null,
    cancelled_at: null,
    completed_at: null,
    created_at: future,
    updated_at: future,
    ...overrides,
  };
}

function normalize(sql) {
  return sql.replace(/\s+/gu, ' ').trim();
}

function createMutex() {
  let tail = Promise.resolve();
  return async () => {
    let release;
    const held = new Promise((resolve) => {
      release = resolve;
    });
    const previous = tail;
    tail = tail.then(() => held);
    await previous;
    return release;
  };
}

function createStatefulPool({
  rides = [ride()],
  bookings = [],
  users,
  failInventory = false,
} = {}) {
  let state = {
    rides: structuredClone(rides),
    bookings: structuredClone(bookings),
    users: structuredClone(
      users ?? [
        user('driver-db-id', 'driver-uid', 'Fixture Driver', '+70000000001'),
        user(
          'passenger-a-db-id',
          'passenger-a-uid',
          'Fixture Passenger A',
          '+70000000002',
        ),
        user(
          'passenger-b-db-id',
          'passenger-b-uid',
          'Fixture Passenger B',
          '+70000000003',
        ),
      ],
    ),
    nextBooking: bookings.length + 1,
  };
  const calls = [];
  const acquire = createMutex();

  function details(booking) {
    if (!booking) return null;
    const currentRide = state.rides.find((item) => item.id === booking.ride_id);
    const driver = state.users.find((item) => item.id === currentRide.driver_id);
    const passenger = state.users.find(
      (item) => item.id === booking.passenger_id,
    );
    return {
      booking_id: booking.id,
      ride_id: booking.ride_id,
      seats: booking.seats,
      booking_price_per_seat: booking.price_per_seat,
      total_price: booking.total_price,
      booking_status: booking.status,
      client_request_id: booking.client_request_id,
      pickup_address: booking.pickup_address,
      pickup_lat: booking.pickup_lat,
      pickup_lng: booking.pickup_lng,
      passenger_comment: booking.passenger_comment,
      pickup_reached_at: booking.pickup_reached_at,
      booking_cancelled_at: booking.cancelled_at,
      booking_completed_at: booking.completed_at,
      booking_created_at: booking.created_at,
      booking_updated_at: booking.updated_at,
      origin_city: currentRide.origin_city,
      origin_lat: currentRide.origin_lat,
      origin_lng: currentRide.origin_lng,
      destination_city: currentRide.destination_city,
      destination_lat: currentRide.destination_lat,
      destination_lng: currentRide.destination_lng,
      departure_at: currentRide.departure_at,
      ride_status: currentRide.status,
      driver_name: driver.name,
      driver_phone: driver.phone,
      car_model: 'Fixture Car',
      car_color: 'Fixture Color',
      car_number: 'FIXTURE-001',
      passenger_name: passenger.name,
      passenger_phone: passenger.phone,
    };
  }

  async function execute(sql, params = []) {
    const text = normalize(sql);
    calls.push({ sql, params, text });

    if (text.startsWith('SELECT pg_advisory_xact_lock')) {
      return { rows: [{}] };
    }
    if (text.startsWith('SELECT id, name, phone, account_status FROM users')) {
      const found = state.users.find(
        (item) => item.firebase_uid === params[0],
      );
      return {
        rows: found ? [{ ...found, account_status: 'active' }] : [],
        rowCount: found ? 1 : 0,
      };
    }
    if (text.startsWith('SELECT 1 FROM account_deletion_jobs')) {
      return { rows: [], rowCount: 0 };
    }
    if (text.startsWith('SELECT id, name, phone FROM users')) {
      return {
        rows: state.users.filter((item) => item.firebase_uid === params[0]),
      };
    }
    if (
      text.includes('FROM intercity_ride_bookings b')
      && text.includes('b.passenger_id = $1 AND b.client_request_id = $2')
    ) {
      const found = state.bookings.find(
        (item) =>
          item.passenger_id === params[0]
          && item.client_request_id === params[1],
      );
      return { rows: found ? [details(found)] : [] };
    }
    if (
      text.includes('FROM intercity_rides r')
      && text.includes('JOIN users du')
      && text.includes('FOR UPDATE OF r')
    ) {
      const found = state.rides.find((item) => item.id === params[0]);
      const driver = found
        ? state.users.find((item) => item.id === found.driver_id)
        : null;
      return {
        rows: found
          ? [{
              ...found,
              driver_name: driver.name,
              driver_phone: driver.phone,
              driver_firebase_uid: driver.firebase_uid,
              car_model: 'Fixture Car',
              car_color: 'Fixture Color',
              car_number: 'FIXTURE-001',
            }]
          : [],
      };
    }
    if (
      text.includes('FROM intercity_rides r')
      && text.includes('u.firebase_uid')
      && text.includes('FOR UPDATE OF r')
    ) {
      const found = state.rides.find((item) => item.id === params[0]);
      const driver = found
        ? state.users.find((item) => item.id === found.driver_id)
        : null;
      return {
        rows: found
          ? [{
              ...found,
              firebase_uid: driver.firebase_uid,
              driver_firebase_uid: driver.firebase_uid,
              driver_name: driver.name,
              car_model: 'Fixture Car',
              car_color: 'Fixture Color',
              car_number: 'FIXTURE-001',
            }]
          : [],
      };
    }
    if (text.startsWith('INSERT INTO intercity_ride_bookings')) {
      const [
        currentRideId,
        passengerId,
        seats,
        price,
        clientRequestId,
        pickupAddress,
        pickupLat,
        pickupLng,
        passengerComment,
      ] = params;
      const duplicateRequest = state.bookings.some(
        (item) =>
          item.passenger_id === passengerId
          && item.client_request_id === clientRequestId,
      );
      const duplicateActive = state.bookings.some(
        (item) =>
          item.ride_id === currentRideId
          && item.passenger_id === passengerId
          && item.status === 'confirmed',
      );
      if (duplicateRequest || duplicateActive) return { rows: [] };
      const created = makeBooking({
        id: `33333333-3333-4333-8333-${String(state.nextBooking).padStart(12, '0')}`,
        ride_id: currentRideId,
        passenger_id: passengerId,
        seats,
        price_per_seat: price,
        total_price: seats * price,
        client_request_id: clientRequestId,
        pickup_address: pickupAddress,
        pickup_lat: pickupLat,
        pickup_lng: pickupLng,
        passenger_comment: passengerComment,
      });
      state.nextBooking += 1;
      state.bookings.push(created);
      return { rows: [created] };
    }
    if (
      text.startsWith('UPDATE intercity_rides')
      && text.includes('available_seats = available_seats - $1')
    ) {
      const [seats, currentRideId] = params;
      const found = state.rides.find((item) => item.id === currentRideId);
      if (
        failInventory
        ||
        !found
        || found.status !== 'scheduled'
        || new Date(found.departure_at) <= new Date()
        || found.available_seats < seats
      ) {
        return { rows: [] };
      }
      found.available_seats -= seats;
      return { rows: [found] };
    }
    if (
      text.includes('FROM intercity_ride_bookings b')
      && text.includes('WHERE b.id = $1')
    ) {
      const found = state.bookings.find((item) => item.id === params[0]);
      return { rows: found ? [details(found)] : [] };
    }
    if (
      text.startsWith('SELECT id FROM intercity_ride_bookings')
      && text.includes("status = 'confirmed'")
    ) {
      const found = state.bookings.find(
        (item) =>
          item.ride_id === params[0]
          && item.passenger_id === params[1]
          && item.status === 'confirmed',
      );
      return { rows: found ? [{ id: found.id }] : [] };
    }
    if (
      text.startsWith('SELECT ride_id FROM intercity_ride_bookings')
    ) {
      const found = state.bookings.find((item) => item.id === params[0]);
      return { rows: found ? [{ ride_id: found.ride_id }] : [] };
    }
    if (
      text.startsWith('SELECT r.*, u.firebase_uid AS driver_firebase_uid')
      && text.includes('FOR UPDATE')
    ) {
      const found = state.rides.find((item) => item.id === params[0]);
      const driver = found
        ? state.users.find((item) => item.id === found.driver_id)
        : null;
      return {
        rows: found
          ? [{ ...found, driver_firebase_uid: driver.firebase_uid }]
          : [],
      };
    }
    if (
      text.startsWith('SELECT * FROM intercity_ride_bookings')
      && text.includes('FOR UPDATE')
    ) {
      const found = state.bookings.find((item) => item.id === params[0]);
      return { rows: found ? [found] : [] };
    }
    if (
      text.startsWith('SELECT b.id AS booking_id')
      && text.includes('passenger_firebase_uid')
    ) {
      return {
        rows: state.bookings
          .filter(
            (item) => item.ride_id === params[0] && item.status === 'confirmed',
          )
          .map((item) => {
            const passenger = state.users.find(
              (entry) => entry.id === item.passenger_id,
            );
            return {
              booking_id: item.id,
              passenger_firebase_uid: passenger.firebase_uid,
            };
          }),
      };
    }
    if (
      text.startsWith('UPDATE intercity_ride_bookings b')
      && text.includes('pickup_reached_at = COALESCE')
    ) {
      const [currentBookingId, currentRideId, driverId] = params;
      const currentRide = state.rides.find(
        (item) => item.id === currentRideId && item.driver_id === driverId,
      );
      const found = state.bookings.find(
        (item) =>
          item.id === currentBookingId
          && item.ride_id === currentRideId
          && item.status === 'confirmed',
      );
      if (
        !currentRide
        || currentRide.status !== 'departed'
        || !found
        || !found.pickup_address
      ) return { rows: [] };
      found.pickup_reached_at ??= new Date().toISOString();
      return { rows: [{ id: found.id }] };
    }
    if (
      text.startsWith('UPDATE intercity_ride_bookings')
      && text.includes("WHERE id = $1")
    ) {
      const found = state.bookings.find((item) => item.id === params[0]);
      if (found) {
        found.status = 'cancelled';
        found.cancelled_at = new Date().toISOString();
      }
      return { rows: [] };
    }
    if (
      text.startsWith('UPDATE intercity_rides')
      && text.includes('available_seats = available_seats + $1')
    ) {
      const found = state.rides.find((item) => item.id === params[1]);
      if (found) found.available_seats += params[0];
      return { rows: found ? [found] : [] };
    }
    if (
      text.includes('FROM intercity_ride_bookings b')
      && text.includes('WHERE b.passenger_id = $1')
      && text.includes('ORDER BY b.created_at DESC')
    ) {
      return {
        rows: state.bookings
          .filter((item) => item.passenger_id === params[0])
          .map(details),
      };
    }
    if (text.startsWith('SELECT driver_id FROM intercity_rides')) {
      const found = state.rides.find((item) => item.id === params[0]);
      return { rows: found ? [{ driver_id: found.driver_id }] : [] };
    }
    if (
      text.includes('FROM intercity_ride_bookings b')
      && text.includes('WHERE b.ride_id = $1')
      && text.includes('ORDER BY b.created_at')
    ) {
      return {
        rows: state.bookings
          .filter((item) => item.ride_id === params[0])
          .map(details),
      };
    }
    if (
      text.startsWith('UPDATE intercity_ride_bookings')
      && text.includes("WHERE ride_id = $1 AND status = 'confirmed'")
    ) {
      const nextStatus = text.includes("status = 'completed'")
        ? 'completed'
        : 'cancelled';
      for (const item of state.bookings) {
        if (item.ride_id === params[0] && item.status === 'confirmed') {
          item.status = nextStatus;
          if (nextStatus === 'completed') item.completed_at = future;
          else item.cancelled_at = future;
        }
      }
      return { rows: [] };
    }
    if (
      text.startsWith('UPDATE intercity_rides')
      && text.includes('SET status = $1')
    ) {
      const found = state.rides.find((item) => item.id === params[1]);
      if (!found) return { rows: [] };
      found.status = params[0];
      if (params[0] === 'cancelled') found.available_seats = found.total_seats;
      return { rows: [found] };
    }
    if (
      text.startsWith('UPDATE intercity_rides SET price_per_seat=$1')
    ) {
      const found = state.rides.find((item) => item.id === params.at(-1));
      found.price_per_seat = params[0];
      return { rows: [found] };
    }
    if (
      text.startsWith('SELECT 1 FROM intercity_ride_bookings')
    ) {
      const found = state.bookings.find(
        (item) => item.ride_id === params[0] && item.status === 'confirmed',
      );
      return { rows: found ? [{ '?column?': 1 }] : [] };
    }
    if (text.includes('FROM user_blocks')) return { rows: [], rowCount: 0 };
    throw new Error(`Unexpected SQL: ${text}`);
  }

  const pool = {
    calls,
    get state() {
      return state;
    },
    query: execute,
    connect: async () => {
      let releaseLock;
      let snapshot;
      return {
        query: async (sql, params = []) => {
          const text = normalize(sql);
          if (text === 'BEGIN') {
            releaseLock = await acquire();
            snapshot = structuredClone(state);
            calls.push({ sql, params, text });
            return { rows: [] };
          }
          if (text === 'COMMIT') {
            calls.push({ sql, params, text });
            releaseLock?.();
            releaseLock = null;
            return { rows: [] };
          }
          if (text === 'ROLLBACK') {
            calls.push({ sql, params, text });
            state = snapshot;
            releaseLock?.();
            releaseLock = null;
            return { rows: [] };
          }
          return execute(sql, params);
        },
        release() {
          releaseLock?.();
          releaseLock = null;
        },
      };
    },
  };
  return pool;
}

function appWith(pool, {
  authenticated = true,
  uid = 'passenger-a-uid',
  sendPushToUser = async () => ({ successCount: 0, failureCount: 0 }),
} = {}) {
  const app = express();
  app.use(express.json());
  const auth = (req, res, next) => {
    if (!authenticated) {
      return res.status(401).json({ error: 'Missing authorization token' });
    }
    req.user = { uid };
    return next();
  };
  app.use(
    '/api/intercity-rides',
    createIntercityRidesRouter({ pool, requireAuth: auth, sendPushToUser }),
  );
  return app;
}

function book(app, {
  currentRideId = rideId,
  seats = 1,
  clientRequestId = requestA,
  ...pickup
} = {}) {
  return request(app)
    .post(`/api/intercity-rides/${currentRideId}/book`)
    .send({ seats, clientRequestId, ...pickup });
}

test('booking validation accepts only seats and UUID clientRequestId', () => {
  assert.equal(
    validateIntercityRideBooking({ seats: 2, clientRequestId: requestA }).ok,
    true,
  );
  for (const seats of ['2', 1.5, 0, -1, 8]) {
    assert.equal(
      validateIntercityRideBooking({ seats, clientRequestId: requestA }).ok,
      false,
    );
  }
  assert.equal(
    validateIntercityRideBooking({ seats: 1, clientRequestId: 'bad' }).ok,
    false,
  );
});

test('booking pickup validation normalizes complete data and rejects invalid data', () => {
  const complete = validateIntercityRideBooking({
    seats: 1,
    clientRequestId: requestA,
    pickupAddress: '  ул. Абая, 15  ',
    pickupLat: 51.1605,
    pickupLng: 71.4704,
    passengerComment: '  Главный вход  ',
  });
  assert.equal(complete.ok, true);
  assert.deepEqual(complete.value, {
    seats: 1,
    clientRequestId: requestA,
    pickupAddress: 'ул. Абая, 15',
    pickupLat: 51.1605,
    pickupLng: 71.4704,
    passengerComment: 'Главный вход',
  });
  assert.equal(validateIntercityRideBooking({
    seats: 1, clientRequestId: requestA, passengerComment: '   ',
  }).value.passengerComment, null);

  for (const invalid of [
    { pickupAddress: 'Адрес' },
    { pickupAddress: '', pickupLat: 1, pickupLng: 1 },
    { pickupAddress: 'x'.repeat(501), pickupLat: 1, pickupLng: 1 },
    { pickupAddress: 'Адрес', pickupLat: 91, pickupLng: 1 },
    { pickupAddress: 'Адрес', pickupLat: 1, pickupLng: 181 },
    { pickupAddress: 'Адрес', pickupLat: Number.NaN, pickupLng: 1 },
    { pickupAddress: 'Адрес', pickupLat: 1, pickupLng: Infinity },
    { passengerComment: 'x'.repeat(1001) },
    { passengerComment: 7 },
  ]) {
    assert.equal(validateIntercityRideBooking({
      seats: 1, clientRequestId: requestA, ...invalid,
    }).ok, false);
  }
});

test('all booking endpoints require auth', async () => {
  const app = appWith(createStatefulPool(), { authenticated: false });
  const responses = await Promise.all([
    book(app),
    request(app).get('/api/intercity-rides/bookings/mine'),
    request(app).post(`/api/intercity-rides/bookings/${bookingId}/cancel`),
    request(app).get(`/api/intercity-rides/${rideId}/bookings`),
    request(app).post(
      `/api/intercity-rides/${rideId}/bookings/${bookingId}/pickup-reached`,
    ),
  ]);
  assert.deepEqual(
    responses.map((item) => item.status),
    [401, 401, 401, 401, 401],
  );
});

test('pickup reached is driver-owned, persisted and idempotent', async () => {
  const pool = createStatefulPool({
    rides: [ride({ status: 'departed' })],
    bookings: [makeBooking({
      pickup_address: 'Pickup A',
      pickup_lat: 51.95,
      pickup_lng: 66.4,
    })],
  });
  const app = appWith(pool, { uid: 'driver-uid' });
  const endpoint =
    `/api/intercity-rides/${rideId}/bookings/${bookingId}/pickup-reached`;
  const first = await request(app).post(endpoint);
  const reachedAt = first.body.booking.pickupReachedAt;
  const repeated = await request(app).post(endpoint);

  assert.equal(first.status, 200);
  assert.ok(reachedAt);
  assert.equal(repeated.status, 200);
  assert.equal(repeated.body.booking.pickupReachedAt, reachedAt);
});

test('pickup reached rejects foreign driver and inactive booking', async () => {
  const activePool = createStatefulPool({
    rides: [ride({ status: 'departed' })],
    bookings: [makeBooking({
      pickup_address: 'Pickup A',
      pickup_lat: 51.95,
      pickup_lng: 66.4,
    })],
  });
  const endpoint =
    `/api/intercity-rides/${rideId}/bookings/${bookingId}/pickup-reached`;
  const foreign = await request(
    appWith(activePool, { uid: 'passenger-a-uid' }),
  ).post(endpoint);
  assert.equal(foreign.status, 409);
  assert.equal(activePool.state.bookings[0].pickup_reached_at, null);

  const cancelledPool = createStatefulPool({
    rides: [ride({ status: 'departed' })],
    bookings: [makeBooking({
      status: 'cancelled',
      pickup_address: 'Pickup A',
      pickup_lat: 51.95,
      pickup_lng: 66.4,
    })],
  });
  const cancelled = await request(
    appWith(cancelledPool, { uid: 'driver-uid' }),
  ).post(endpoint);
  assert.equal(cancelled.status, 409);
  assert.equal(cancelledPool.state.bookings[0].pickup_reached_at, null);
});

test('pickup reached migration adds server truth and remaining index', () => {
  const sql = readFileSync(
    new URL(
      '../migrations/20260921_021_intercity_pickup_reached.sql',
      import.meta.url,
    ),
    'utf8',
  );
  assert.match(sql, /ADD COLUMN pickup_reached_at timestamptz/);
  assert.match(sql, /idx_intercity_ride_bookings_remaining_pickups/);
  assert.match(sql, /pickup_reached_at IS NULL/);
});

test('invalid ride, booking and client request UUIDs are rejected', async () => {
  const app = appWith(createStatefulPool());
  assert.equal((await book(app, { currentRideId: 'bad' })).status, 400);
  assert.equal(
    (
      await request(app).post(
        '/api/intercity-rides/bookings/not-a-uuid/cancel',
      )
    ).status,
    400,
  );
  assert.equal((await book(app, { clientRequestId: 'bad' })).status, 400);
});

test('server creates price snapshot and ignores no client identity or price', async () => {
  const pool = createStatefulPool();
  const response = await book(appWith(pool), { seats: 2 });
  assert.equal(response.status, 201);
  assert.equal(response.body.booking.pricePerSeat, 4000);
  assert.equal(response.body.booking.totalPrice, 8000);
  assert.equal(pool.state.rides[0].available_seats, 1);
  assert.equal(pool.state.bookings[0].passenger_id, 'passenger-a-db-id');
  const insert = pool.calls.find((call) =>
    call.text.startsWith('INSERT INTO intercity_ride_bookings'));
  assert.deepEqual(insert.params, [
    rideId,
    'passenger-a-db-id',
    2,
    4000,
    requestA,
    null,
    null,
    null,
    null,
  ]);
  assert.match(insert.text, /ON CONFLICT DO NOTHING/);
});

test('mass assignment and price or passenger spoofing are rejected', async () => {
  for (const extra of [
    { passengerId: 'driver-db-id' },
    { driverId: 'passenger-b-db-id' },
    { pricePerSeat: 1 },
    { totalPrice: 1 },
    { status: 'confirmed' },
    { availableSeats: 7 },
  ]) {
    const response = await request(appWith(createStatefulPool()))
      .post(`/api/intercity-rides/${rideId}/book`)
      .send({ seats: 1, clientRequestId: requestA, ...extra });
    assert.equal(response.status, 400);
  }
});

test('self-booking is forbidden', async () => {
  const response = await book(
    appWith(createStatefulPool(), { uid: 'driver-uid' }),
  );
  assert.equal(response.status, 403);
});

test('same request replay returns existing booking without second decrement', async () => {
  const pool = createStatefulPool();
  const app = appWith(pool);
  assert.equal((await book(app)).status, 201);
  const replay = await book(app);
  assert.equal(replay.status, 200);
  assert.equal(pool.state.bookings.length, 1);
  assert.equal(pool.state.rides[0].available_seats, 2);
});

test('pickup booking exact replay succeeds and changed private data conflicts', async () => {
  const pool = createStatefulPool();
  const app = appWith(pool);
  const pickup = {
    pickupAddress: '  ул. Абая, 15 ',
    pickupLat: 51.1605,
    pickupLng: 71.4704,
    passengerComment: '  Главный вход ',
  };
  const created = await book(app, pickup);
  assert.equal(created.status, 201);
  assert.equal((await book(app, pickup)).status, 200);
  assert.equal((await book(app, {
    ...pickup, pickupAddress: 'Другой адрес',
  })).status, 409);
  assert.equal((await book(app, {
    ...pickup, passengerComment: 'Другой комментарий',
  })).status, 409);
  assert.equal((await book(app)).status, 409);
  assert.equal(pool.state.bookings.length, 1);
  assert.equal(pool.state.rides[0].available_seats, 2);
});

test('pickup is visible only through passenger-owner and driver-owner booking DTOs', async () => {
  const pool = createStatefulPool();
  const app = appWith(pool);
  const pickup = {
    pickupAddress: 'ул. Абая, 15',
    pickupLat: 51.1605,
    pickupLng: 71.4704,
    passengerComment: 'Главный вход',
  };
  assert.equal((await book(app, pickup)).status, 201);
  const mine = await request(app).get('/api/intercity-rides/bookings/mine');
  assert.deepEqual(
    {
      pickupAddress: mine.body.bookings[0].pickupAddress,
      pickupLat: mine.body.bookings[0].pickupLat,
      pickupLng: mine.body.bookings[0].pickupLng,
      passengerComment: mine.body.bookings[0].passengerComment,
    },
    pickup,
  );
  const driver = await request(appWith(pool, { uid: 'driver-uid' })).get(
    `/api/intercity-rides/${rideId}/bookings`,
  );
  assert.equal(driver.status, 200);
  assert.equal(driver.body.bookings[0].pickupAddress, pickup.pickupAddress);
  const unrelated = await request(
    appWith(pool, { uid: 'passenger-b-uid' }),
  ).get(`/api/intercity-rides/${rideId}/bookings`);
  assert.equal(unrelated.status, 403);
});

test('booking cancellation preserves pickup and passenger comment', async () => {
  const pool = createStatefulPool();
  const app = appWith(pool);
  const pickup = {
    pickupAddress: 'ул. Абая, 15', pickupLat: 51, pickupLng: 71,
    passengerComment: 'Жду здесь',
  };
  const created = await book(app, pickup);
  await request(app).post(
    `/api/intercity-rides/bookings/${created.body.booking.bookingId}/cancel`,
  );
  assert.equal(pool.state.bookings[0].pickup_address, pickup.pickupAddress);
  assert.equal(pool.state.bookings[0].passenger_comment, pickup.passengerComment);
});

test('same clientRequestId with different seats or ride is a stable conflict', async () => {
  const pool = createStatefulPool({
    rides: [ride(), ride({ id: otherRideId })],
  });
  const app = appWith(pool);
  assert.equal((await book(app)).status, 201);
  assert.equal((await book(app, { seats: 2 })).status, 409);
  assert.equal(
    (await book(app, { currentRideId: otherRideId })).status,
    409,
  );
  assert.equal(pool.state.bookings.length, 1);
  assert.equal(pool.state.rides[1].available_seats, 3);
});

test('two passengers racing for the last seat produce one booking', async () => {
  const pool = createStatefulPool({ rides: [ride({ total_seats: 1, available_seats: 1 })] });
  const responses = await Promise.all([
    book(appWith(pool, { uid: 'passenger-a-uid' })),
    book(appWith(pool, { uid: 'passenger-b-uid' }), {
      clientRequestId: requestB,
    }),
  ]);
  assert.deepEqual(responses.map((item) => item.status).sort(), [201, 409]);
  assert.equal(pool.state.bookings.length, 1);
  assert.equal(pool.state.rides[0].available_seats, 0);
});

test('two concurrent identical requests create one booking and decrement once', async () => {
  const pool = createStatefulPool();
  const app = appWith(pool);
  const responses = await Promise.all([book(app), book(app)]);
  assert.deepEqual(responses.map((item) => item.status).sort(), [200, 201]);
  assert.equal(pool.state.bookings.length, 1);
  assert.equal(pool.state.rides[0].available_seats, 2);
});

test('different concurrent request IDs allow one confirmed booking per passenger and ride', async () => {
  const pool = createStatefulPool();
  const app = appWith(pool);
  const responses = await Promise.all([
    book(app, { clientRequestId: requestA }),
    book(app, { clientRequestId: requestB }),
  ]);
  assert.deepEqual(responses.map((item) => item.status).sort(), [201, 409]);
  assert.equal(pool.state.bookings.length, 1);
  assert.equal(pool.state.rides[0].available_seats, 2);
});

test('booking lock and conditional inventory SQL use one transaction', async () => {
  const pool = createStatefulPool();
  assert.equal((await book(appWith(pool))).status, 201);
  const texts = pool.calls.map((call) => call.text);
  const begin = texts.indexOf('BEGIN');
  const rideLock = texts.findIndex((text) =>
    text.includes('FROM intercity_rides r') && text.includes('FOR UPDATE OF r'));
  const insert = texts.findIndex((text) =>
    text.startsWith('INSERT INTO intercity_ride_bookings'));
  const inventory = texts.findIndex((text) =>
    text.includes('available_seats = available_seats - $1'));
  const commit = texts.lastIndexOf('COMMIT');
  assert.ok(begin < rideLock && rideLock < insert && insert < inventory);
  assert.ok(inventory < commit);
  assert.match(texts[inventory], /available_seats >= \$1/);
  assert.match(texts[inventory], /status = 'scheduled'/);
  assert.match(texts[inventory], /departure_at > now\(\)/);
});

test('price changes affect only new bookings, not existing snapshots', async () => {
  const pool = createStatefulPool();
  assert.equal((await book(appWith(pool), { clientRequestId: requestA })).status, 201);
  const patchResponse = await request(
    appWith(pool, { uid: 'driver-uid' }),
  )
    .patch(`/api/intercity-rides/${rideId}`)
    .send({ pricePerSeat: 5000 });
  assert.equal(patchResponse.status, 200);
  assert.equal(
    (
      await book(appWith(pool, { uid: 'passenger-b-uid' }), {
        clientRequestId: requestB,
      })
    ).status,
    201,
  );
  assert.equal(pool.state.bookings[0].price_per_seat, 4000);
  assert.equal(pool.state.bookings[1].price_per_seat, 5000);
});

test('mine returns only authenticated passenger bookings and safe fields', async () => {
  const pool = createStatefulPool({
    bookings: [
      makeBooking(),
      makeBooking({
        id: '44444444-4444-4444-8444-444444444444',
        passenger_id: 'passenger-b-db-id',
        client_request_id: requestB,
      }),
    ],
  });
  const response = await request(appWith(pool)).get(
    '/api/intercity-rides/bookings/mine',
  );
  assert.equal(response.status, 200);
  assert.equal(response.body.bookings.length, 1);
  const json = JSON.stringify(response.body);
  assert.equal(json.includes('passenger-a-db-id'), false);
  assert.equal(json.includes('driver-db-id'), false);
  assert.equal(json.includes('firebase_uid'), false);
  assert.equal(json.includes('passenger-a-uid'), false);
  assert.equal(json.includes('push'), false);
  assert.equal(response.body.bookings[0].driver.phone, '+70000000001');
});

test('cancelled booking omits driver contact from passenger response', async () => {
  const pool = createStatefulPool({
    bookings: [makeBooking({ status: 'cancelled' })],
  });
  const response = await request(appWith(pool)).get(
    '/api/intercity-rides/bookings/mine',
  );
  assert.equal(response.status, 200);
  assert.equal('phone' in response.body.bookings[0].driver, false);
});

test('driver-owner sees safe passenger minimum; foreign driver and passenger are denied', async () => {
  const pool = createStatefulPool({ bookings: [makeBooking()] });
  const owner = await request(appWith(pool, { uid: 'driver-uid' })).get(
    `/api/intercity-rides/${rideId}/bookings`,
  );
  assert.equal(owner.status, 200);
  assert.equal(owner.body.bookings[0].passenger.phone, '+70000000002');
  assert.equal(JSON.stringify(owner.body).includes('passenger-a-db-id'), false);
  assert.equal(
    (
      await request(appWith(pool, { uid: 'passenger-b-uid' })).get(
        `/api/intercity-rides/${rideId}/bookings`,
      )
    ).status,
    403,
  );
  assert.equal(
    (
      await request(appWith(pool, { uid: 'passenger-a-uid' })).get(
        `/api/intercity-rides/${rideId}/bookings`,
      )
    ).status,
    403,
  );
});

test('only booking owner may cancel and completed booking cannot cancel', async () => {
  const foreignPool = createStatefulPool({ bookings: [makeBooking()] });
  const foreign = await request(
    appWith(foreignPool, { uid: 'passenger-b-uid' }),
  ).post(`/api/intercity-rides/bookings/${bookingId}/cancel`);
  assert.equal(foreign.status, 403);
  assert.equal(foreignPool.state.rides[0].available_seats, 3);

  const completedPool = createStatefulPool({
    bookings: [makeBooking({ status: 'completed' })],
  });
  const completed = await request(appWith(completedPool)).post(
    `/api/intercity-rides/bookings/${bookingId}/cancel`,
  );
  assert.equal(completed.status, 409);
  assert.equal(completedPool.state.rides[0].available_seats, 3);
});

test('cancellation is idempotent and returns seats once', async () => {
  const pool = createStatefulPool({
    rides: [ride({ available_seats: 2 })],
    bookings: [makeBooking()],
  });
  const app = appWith(pool);
  assert.equal(
    (
      await request(app).post(
        `/api/intercity-rides/bookings/${bookingId}/cancel`,
      )
    ).status,
    200,
  );
  assert.equal(
    (
      await request(app).post(
        `/api/intercity-rides/bookings/${bookingId}/cancel`,
      )
    ).status,
    200,
  );
  assert.equal(pool.state.rides[0].available_seats, 3);
  assert.equal(pool.state.bookings[0].status, 'cancelled');
});

test('concurrent double cancellation restores inventory once', async () => {
  const pool = createStatefulPool({
    rides: [ride({ available_seats: 2 })],
    bookings: [makeBooking()],
  });
  const app = appWith(pool);
  const responses = await Promise.all([
    request(app).post(`/api/intercity-rides/bookings/${bookingId}/cancel`),
    request(app).post(`/api/intercity-rides/bookings/${bookingId}/cancel`),
  ]);
  assert.deepEqual(responses.map((item) => item.status), [200, 200]);
  assert.equal(pool.state.rides[0].available_seats, 3);
  assert.equal(pool.state.bookings[0].status, 'cancelled');
});

test('driver cancel cancels confirmed bookings and resets inventory atomically', async () => {
  const pool = createStatefulPool({
    rides: [ride({ available_seats: 2 })],
    bookings: [makeBooking()],
  });
  const response = await request(appWith(pool, { uid: 'driver-uid' })).post(
    `/api/intercity-rides/${rideId}/cancel`,
  );
  assert.equal(response.status, 200);
  assert.equal(pool.state.rides[0].status, 'cancelled');
  assert.equal(pool.state.rides[0].available_seats, 3);
  assert.equal(pool.state.bookings[0].status, 'cancelled');
});

test('depart blocks later bookings and complete finishes confirmed bookings', async () => {
  const pool = createStatefulPool({ bookings: [makeBooking()] });
  const driverApp = appWith(pool, { uid: 'driver-uid' });
  assert.equal(
    (await request(driverApp).post(`/api/intercity-rides/${rideId}/depart`))
      .status,
    200,
  );
  assert.equal(
    (
      await book(appWith(pool, { uid: 'passenger-b-uid' }), {
        clientRequestId: requestB,
      })
    ).status,
    409,
  );
  assert.equal(
    (await request(driverApp).post(`/api/intercity-rides/${rideId}/complete`))
      .status,
    200,
  );
  assert.equal(pool.state.bookings[0].status, 'completed');
});

test('booking racing driver cancel leaves no confirmed booking on cancelled ride', async () => {
  const pool = createStatefulPool();
  const responses = await Promise.all([
    book(appWith(pool)),
    request(appWith(pool, { uid: 'driver-uid' })).post(
      `/api/intercity-rides/${rideId}/cancel`,
    ),
  ]);
  assert.ok(responses.every((item) => [200, 201, 409].includes(item.status)));
  assert.equal(pool.state.rides[0].status, 'cancelled');
  assert.equal(
    pool.state.bookings.some((item) => item.status === 'confirmed'),
    false,
  );
});

test('booking racing depart cannot commit after departure', async () => {
  const pool = createStatefulPool();
  const responses = await Promise.all([
    book(appWith(pool)),
    request(appWith(pool, { uid: 'driver-uid' })).post(
      `/api/intercity-rides/${rideId}/depart`,
    ),
  ]);
  assert.ok(responses.every((item) => [200, 201, 409].includes(item.status)));
  assert.equal(pool.state.rides[0].status, 'departed');
  const confirmed = pool.state.bookings.filter(
    (item) => item.status === 'confirmed',
  );
  assert.ok(confirmed.length <= 1);
});

test('new booking pushes driver once after commit; replay does not push again', async () => {
  const pool = createStatefulPool();
  const pushes = [];
  const sendPushToUser = async (uid, payload) => {
    assert.equal(pool.calls.at(-1).text, 'COMMIT');
    pushes.push({ uid, payload });
  };
  const app = appWith(pool, { sendPushToUser });
  assert.equal((await book(app, { seats: 2 })).status, 201);
  assert.equal((await book(app, { seats: 2 })).status, 200);
  assert.equal(pushes.length, 1);
  assert.equal(pushes[0].uid, 'driver-uid');
  assert.deepEqual(pushes[0].payload.data, {
    type: 'intercity_booking_created',
    rideId,
    bookingId: pool.state.bookings[0].id,
    seats: 2,
  });
  assert.equal(pushes[0].payload.body, 'Пассажир забронировал 2 места');
  const payloadJson = JSON.stringify(pushes[0].payload);
  for (const privateValue of [
    'driver-uid',
    'driver-db-id',
    'passenger-a-db-id',
    '+70000000001',
    'token',
  ]) {
    assert.equal(payloadJson.includes(privateValue), false);
  }
});

test('failed booking and rolled back inventory update send no push', async () => {
  for (const pool of [
    createStatefulPool({ rides: [ride({ available_seats: 0 })] }),
    createStatefulPool({ failInventory: true }),
  ]) {
    const pushes = [];
    const response = await book(
      appWith(pool, {
        sendPushToUser: async (...args) => pushes.push(args),
      }),
    );
    assert.equal(response.status, 409);
    assert.equal(pushes.length, 0);
    assert.equal(pool.state.bookings.length, 0);
  }
});

test('first booking cancellation pushes driver once; replay does not push', async () => {
  const pool = createStatefulPool({
    rides: [ride({ available_seats: 2 })],
    bookings: [makeBooking()],
  });
  const pushes = [];
  const app = appWith(pool, {
    sendPushToUser: async (uid, payload) => pushes.push({ uid, payload }),
  });
  const endpoint = `/api/intercity-rides/bookings/${bookingId}/cancel`;
  assert.equal((await request(app).post(endpoint)).status, 200);
  assert.equal((await request(app).post(endpoint)).status, 200);
  assert.equal(pushes.length, 1);
  assert.equal(pushes[0].uid, 'driver-uid');
  assert.deepEqual(pushes[0].payload.data, {
    type: 'intercity_booking_cancelled',
    rideId,
    bookingId,
  });
});

test('driver ride cancellation pushes only previously confirmed passengers', async () => {
  const pool = createStatefulPool({
    rides: [ride({ available_seats: 2 })],
    bookings: [
      makeBooking(),
      makeBooking({
        id: '44444444-4444-4444-8444-444444444444',
        passenger_id: 'passenger-b-db-id',
        client_request_id: requestB,
      }),
      makeBooking({
        id: '55555555-5555-4555-8555-555555555555',
        passenger_id: 'passenger-b-db-id',
        client_request_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        status: 'cancelled',
      }),
      makeBooking({
        id: '66666666-6666-4666-8666-666666666666',
        passenger_id: 'passenger-b-db-id',
        client_request_id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        status: 'completed',
      }),
    ],
  });
  const pushes = [];
  const response = await request(
    appWith(pool, {
      uid: 'driver-uid',
      sendPushToUser: async (uid, payload) => pushes.push({ uid, payload }),
    }),
  ).post(`/api/intercity-rides/${rideId}/cancel`);
  assert.equal(response.status, 200);
  assert.equal(pushes.length, 2);
  assert.deepEqual(
    pushes.map((item) => item.uid).sort(),
    ['passenger-a-uid', 'passenger-b-uid'].sort(),
  );
  assert.deepEqual(
    pushes.map((item) => item.payload.data.bookingId).sort(),
    [bookingId, '44444444-4444-4444-8444-444444444444'].sort(),
  );
  assert.ok(
    pushes.every(
      (item) => item.payload.data.type === 'intercity_ride_cancelled',
    ),
  );
});

test('depart pushes confirmed passengers once; invalid repeat sends no push', async () => {
  const pool = createStatefulPool({ bookings: [makeBooking()] });
  const pushes = [];
  const app = appWith(pool, {
    uid: 'driver-uid',
    sendPushToUser: async (uid, payload) => pushes.push({ uid, payload }),
  });
  const endpoint = `/api/intercity-rides/${rideId}/depart`;
  assert.equal((await request(app).post(endpoint)).status, 200);
  assert.equal((await request(app).post(endpoint)).status, 409);
  assert.equal(pushes.length, 1);
  assert.equal(pushes[0].uid, 'passenger-a-uid');
  assert.deepEqual(pushes[0].payload.data, {
    type: 'intercity_trip_started',
    rideId,
    bookingId,
  });
});

test('post-commit push failure does not change successful booking response', async () => {
  const pool = createStatefulPool();
  const response = await book(
    appWith(pool, {
      sendPushToUser: async () => {
        const failure = new Error('FCM unavailable');
        failure.code = 'messaging/unavailable';
        throw failure;
      },
    }),
  );
  assert.equal(response.status, 201);
  assert.equal(pool.state.bookings.length, 1);
  assert.equal(pool.calls.some((call) => call.text === 'COMMIT'), true);
});
