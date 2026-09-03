import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test, { after, before, beforeEach } from 'node:test';

import express from 'express';
import supertest from 'supertest';

import { createIntercityRidesRouter } from '../src/routes/intercity-rides.js';
import {
  assertConnectedToSafeTestDatabase,
  createIntegrationPool,
} from './test-db.js';

const expectedDatabase = String(process.env.POSTGRES_DB ?? '').trim();
const pool = createIntegrationPool('intercity-sequential-e2e');
const ids = Object.freeze({
  driverA: '61000000-0000-4000-8000-000000000001',
  driverB: '61000000-0000-4000-8000-000000000002',
  passengerA: '61000000-0000-4000-8000-000000000003',
  passengerB: '61000000-0000-4000-8000-000000000004',
  passengerC: '61000000-0000-4000-8000-000000000005',
});
const uids = Object.freeze({
  driverA: 'e2e-driver-a',
  driverB: 'e2e-driver-b',
  passengerA: 'e2e-passenger-a',
  passengerB: 'e2e-passenger-b',
  passengerC: 'e2e-passenger-c',
});

let pushes = [];
let failNextType = null;

function travelDate(days = 20) {
  return new Date(Date.now() + days * 86_400_000 + 5 * 3_600_000)
    .toISOString()
    .slice(0, 10);
}

function departure(date = travelDate(), hour = 12) {
  return `${date}T${String(hour).padStart(2, '0')}:00:00+05:00`;
}

function auth(req, res, next) {
  const uid = req.get('x-integration-uid');
  if (!uid) return res.status(401).json({ error: 'Authentication required' });
  req.user = { uid };
  return next();
}

async function assertPushObservedAfterCommit(uid, payload) {
  const type = payload?.data?.type;
  const allowedDataKeys = new Set(['type', 'rideId', 'bookingId', 'requestId']);
  assert.ok(uid.startsWith('e2e-'));
  assert.ok(Object.keys(payload.data ?? {}).every((key) => allowedDataKeys.has(key)));
  assert.doesNotMatch(
    JSON.stringify(payload),
    /firebase|push.?token|phone|comment|address|pickup|driverId|passengerId/i,
  );

  if (type === 'intercity_ride_booked') {
    const result = await pool.query(
      `SELECT status FROM intercity_ride_bookings WHERE id = $1`,
      [payload.data.bookingId],
    );
    assert.equal(result.rows[0]?.status, 'confirmed');
  } else if (type === 'intercity_booking_cancelled') {
    const result = await pool.query(
      `SELECT status FROM intercity_ride_bookings WHERE id = $1`,
      [payload.data.bookingId],
    );
    assert.equal(result.rows[0]?.status, 'cancelled');
  } else if (type === 'intercity_ride_cancelled' || type === 'intercity_ride_departed') {
    const result = await pool.query(
      `SELECT status FROM intercity_rides WHERE id = $1`,
      [payload.data.rideId],
    );
    assert.equal(
      result.rows[0]?.status,
      type === 'intercity_ride_cancelled' ? 'cancelled' : 'departed',
    );
  } else if (type === 'intercity_ride_match_available') {
    const result = await pool.query(
      `SELECT 1 FROM intercity_ride_request_notifications
       WHERE request_id = $1 AND ride_id = $2`,
      [payload.data.requestId, payload.data.rideId],
    );
    assert.equal(result.rowCount, 1);
  } else {
    assert.fail(`Unexpected push type: ${type}`);
  }

  pushes.push({ uid, payload });
  if (failNextType === type) {
    failNextType = null;
    const failure = new Error('simulated FCM failure');
    failure.code = 'messaging/unavailable';
    throw failure;
  }
  return { successCount: 1, failureCount: 0 };
}

const app = express();
app.use(express.json());
app.use(
  '/api/intercity-rides',
  createIntercityRidesRouter({
    pool,
    requireAuth: auth,
    sendPushToUser: assertPushObservedAfterCommit,
  }),
);

function api(method, path, uid, body) {
  let call = supertest(app)[method](path).set('x-integration-uid', uid);
  if (body !== undefined) call = method === 'get' ? call.query(body) : call.send(body);
  return call;
}

async function createRide({
  uid = uids.driverA,
  originCity = 'Есиль',
  destinationCity = 'Астана',
  date = travelDate(),
  hour = 12,
  totalSeats = 3,
  pricePerSeat = 4000,
} = {}) {
  return api('post', '/api/intercity-rides', uid, {
    originCity,
    destinationCity,
    originLat: 51.9555,
    originLng: 66.4042,
    destinationLat: 51.1694,
    destinationLng: 71.4491,
    departureAt: departure(date, hour),
    totalSeats,
    pricePerSeat,
    allowsLuggage: true,
  });
}

function search(uid, originCity, destinationCity, date, seats) {
  return api('get', '/api/intercity-rides/search', uid, {
    originCity,
    destinationCity,
    travelDate: date,
    seats,
  });
}

function book(uid, rideId, seats, clientRequestId = randomUUID(), extra = {}) {
  return api('post', `/api/intercity-rides/${rideId}/book`, uid, {
    seats,
    clientRequestId,
    ...extra,
  });
}

async function rideState(rideId) {
  const result = await pool.query(
    `SELECT r.*,
       COALESCE(sum(b.seats) FILTER (WHERE b.status = 'confirmed'), 0)::integer
         AS confirmed_seats
     FROM intercity_rides r
     LEFT JOIN intercity_ride_bookings b ON b.ride_id = r.id
     WHERE r.id = $1 GROUP BY r.id`,
    [rideId],
  );
  return result.rows[0];
}

function assertNoPrivateIdentifiers(value) {
  const serialized = JSON.stringify(value);
  assert.doesNotMatch(serialized, /firebaseUid|firebase_uid|pushToken|push_token/);
  assert.doesNotMatch(serialized, /passenger_id|driver_id|user_id/);
}

before(async () => {
  await assertConnectedToSafeTestDatabase(pool, expectedDatabase);
});

beforeEach(async () => {
  pushes = [];
  failNextType = null;
  await pool.query(
    `TRUNCATE TABLE intercity_ride_request_notifications,
       intercity_ride_requests, intercity_ride_bookings, intercity_rides,
       driver_subscriptions, driver_profiles, users CASCADE`,
  );
  await pool.query(
    `INSERT INTO users (id, firebase_uid, phone, name) VALUES
       ($1,$2,'+77001000001','E2E Driver A'),
       ($3,$4,'+77001000002','E2E Driver B'),
       ($5,$6,'+77001000003','E2E Passenger A'),
       ($7,$8,'+77001000004','E2E Passenger B'),
       ($9,$10,'+77001000005','E2E Passenger C')`,
    [
      ids.driverA, uids.driverA, ids.driverB, uids.driverB,
      ids.passengerA, uids.passengerA, ids.passengerB, uids.passengerB,
      ids.passengerC, uids.passengerC,
    ],
  );
  await pool.query(
    `INSERT INTO driver_profiles
       (user_id,status,car_model,car_color,car_number,access_exempt) VALUES
       ($1,'active','Toyota','Белый','E2E-A',true),
       ($2,'active','Skoda','Синий','E2E-B',false)`,
    [ids.driverA, ids.driverB],
  );
  await pool.query(
    `INSERT INTO driver_subscriptions
       (driver_id,amount,starts_at,valid_until,status,payment_status)
     VALUES ($1,1000,now()-interval '1 day',now()+interval '30 days','active','paid')`,
    [ids.driverB],
  );
});

after(async () => pool.end());

test('sequential create, search, booking, cancellation, edit and IDOR flow', async () => {
  const date = travelDate(20);
  const rejectedAssignment = await api('post', '/api/intercity-rides', uids.driverA, {
    originCity: 'Есиль', destinationCity: 'Астана', departureAt: departure(date),
    totalSeats: 3, pricePerSeat: 4000, driverId: ids.driverB,
  });
  assert.equal(rejectedAssignment.status, 400);

  const created = await createRide({ date });
  assert.equal(created.status, 201);
  const rideId = created.body.ride.rideId;
  assert.deepEqual(
    { status: created.body.ride.status, total: created.body.ride.totalSeats, available: created.body.ride.availableSeats, price: created.body.ride.pricePerSeat },
    { status: 'scheduled', total: 3, available: 3, price: 4000 },
  );
  const owner = await pool.query('SELECT driver_id FROM intercity_rides WHERE id=$1', [rideId]);
  assert.equal(owner.rows[0].driver_id, ids.driverA);

  const found = await search(uids.passengerA, 'Есиль', 'Астана', date, 2);
  assert.equal(found.status, 200);
  assert.deepEqual(found.body.rides.map((ride) => ride.rideId), [rideId]);
  assertNoPrivateIdentifiers(found.body);
  assert.doesNotMatch(
    JSON.stringify(found.body),
    /pickupAddress|pickupLat|pickupLng|passengerComment/,
  );
  assert.equal(found.body.rides[0].driver.phone, undefined);

  const requestA = randomUUID();
  const pickup = {
    pickupAddress: 'ул. Абая, 15',
    pickupLat: 51.1605,
    pickupLng: 71.4704,
    passengerComment: 'Главный вход',
  };
  const bookingA = await book(uids.passengerA, rideId, 2, requestA, pickup);
  assert.equal(bookingA.status, 201);
  assert.deepEqual(
    { status: bookingA.body.booking.status, price: bookingA.body.booking.pricePerSeat, total: bookingA.body.booking.totalPrice },
    { status: 'confirmed', price: 4000, total: 8000 },
  );
  const replayPushCount = pushes.length;
  const replay = await book(uids.passengerA, rideId, 2, requestA, pickup);
  assert.equal(replay.status, 200);
  assert.equal(replay.body.booking.bookingId, bookingA.body.booking.bookingId);
  assert.equal(pushes.length, replayPushCount);
  assert.equal((await book(uids.passengerA, rideId, 2, requestA, {
    ...pickup, pickupAddress: 'Другой адрес',
  })).status, 409);
  const passengerBookings = await api(
    'get', '/api/intercity-rides/bookings/mine', uids.passengerA,
  );
  assert.equal(passengerBookings.body.bookings[0].pickupAddress, pickup.pickupAddress);
  const driverBookings = await api(
    'get', `/api/intercity-rides/${rideId}/bookings`, uids.driverA,
  );
  assert.equal(driverBookings.body.bookings[0].passengerComment, pickup.passengerComment);
  assert.equal((await api(
    'get', `/api/intercity-rides/${rideId}/bookings`, uids.driverB,
  )).status, 403);
  assert.equal((await rideState(rideId)).available_seats, 1);

  assert.equal((await search(uids.passengerB, 'Есиль', 'Астана', date, 2)).body.rides.length, 0);
  assert.equal((await search(uids.passengerB, 'Есиль', 'Астана', date, 1)).body.rides.length, 1);
  const bookingB = await book(uids.passengerB, rideId, 1);
  assert.equal(bookingB.status, 201);
  assert.equal((await rideState(rideId)).available_seats, 0);
  const beforeOverbookPushes = pushes.length;
  assert.equal((await book(uids.passengerC, rideId, 1)).status, 409);
  assert.equal(pushes.length, beforeOverbookPushes);

  assert.equal(
    (await api('post', `/api/intercity-rides/bookings/${bookingB.body.booking.bookingId}/cancel`, uids.passengerA)).status,
    403,
  );
  const cancelledA = await api('post', `/api/intercity-rides/bookings/${bookingA.body.booking.bookingId}/cancel`, uids.passengerA);
  assert.equal(cancelledA.status, 200);
  assert.equal(cancelledA.body.booking.status, 'cancelled');
  assert.equal(cancelledA.body.booking.pickupAddress, pickup.pickupAddress);
  const cancelledStored = await pool.query(
    `SELECT pickup_address, passenger_comment
       FROM intercity_ride_bookings WHERE id = $1`,
    [bookingA.body.booking.bookingId],
  );
  assert.deepEqual(cancelledStored.rows[0], {
    pickup_address: pickup.pickupAddress,
    passenger_comment: pickup.passengerComment,
  });
  assert.equal((await rideState(rideId)).available_seats, 2);
  const cancellationPushes = pushes.length;
  assert.equal((await api('post', `/api/intercity-rides/bookings/${bookingA.body.booking.bookingId}/cancel`, uids.passengerA)).status, 200);
  assert.equal((await rideState(rideId)).available_seats, 2);
  assert.equal(pushes.length, cancellationPushes);

  const bookingC = await book(uids.passengerC, rideId, 1);
  assert.equal(bookingC.status, 201);
  assert.equal((await rideState(rideId)).available_seats, 1);

  for (const patch of [
    { destinationCity: 'Костанай' },
    { departureAt: departure(travelDate(21)) },
    { totalSeats: 4 },
  ]) {
    assert.equal((await api('patch', `/api/intercity-rides/${rideId}`, uids.driverA, patch)).status, 409);
  }
  const edited = await api('patch', `/api/intercity-rides/${rideId}`, uids.driverA, {
    pricePerSeat: 5500, allowsLuggage: false, comment: 'Новая цена',
  });
  assert.equal(edited.status, 200);
  assert.equal(edited.body.ride.pricePerSeat, 5500);
  const bookingA2 = await book(uids.passengerA, rideId, 1);
  assert.equal(bookingA2.status, 201);
  assert.equal(bookingA2.body.booking.pricePerSeat, 5500);
  const snapshots = await pool.query(
    `SELECT passenger_id, price_per_seat FROM intercity_ride_bookings
     WHERE ride_id=$1 AND status='confirmed' ORDER BY passenger_id`,
    [rideId],
  );
  assert.equal(snapshots.rows.find((item) => item.passenger_id === ids.passengerB).price_per_seat, 4000);
  assert.equal(snapshots.rows.find((item) => item.passenger_id === ids.passengerC).price_per_seat, 4000);
  assert.equal(snapshots.rows.find((item) => item.passenger_id === ids.passengerA).price_per_seat, 5500);

  assert.equal((await api('patch', `/api/intercity-rides/${rideId}`, uids.driverB, { comment: 'IDOR' })).status, 403);
  assert.equal((await api('post', `/api/intercity-rides/${rideId}/cancel`, uids.driverB)).status, 403);
  assert.equal((await api('get', `/api/intercity-rides/${rideId}/bookings`, uids.driverB)).status, 403);
  assertNoPrivateIdentifiers((await api('get', `/api/intercity-rides/${rideId}/bookings`, uids.driverA)).body);
  assert.equal(pushes.filter((item) => item.payload.data.type === 'intercity_ride_booked').length, 4);
  assert.equal(pushes.filter((item) => item.payload.data.type === 'intercity_booking_cancelled').length, 1);
});

test('request-first and ride-first matching are unique and private', async () => {
  const date = travelDate(30);
  const requestFirst = await api('post', '/api/intercity-rides/requests', uids.passengerA, {
    originCity: 'Есиль', destinationCity: 'Костанай', travelDate: date, seats: 1,
    pickupAddress: 'Точка пассажира', pickupLat: 51.95, pickupLng: 66.4,
    passengerComment: 'С багажом',
  });
  assert.equal(requestFirst.status, 201);
  assert.deepEqual(requestFirst.body.request.matchedRideIds, []);
  const matchedRide = await createRide({ originCity: 'Есиль', destinationCity: 'Костанай', date });
  assert.equal(matchedRide.status, 201);
  const mine = await api('get', '/api/intercity-rides/requests/mine', uids.passengerA);
  assert.equal(mine.body.requests[0].status, 'active');
  assert.equal(mine.body.requests[0].pickupAddress, 'Точка пассажира');
  assert.deepEqual(mine.body.requests[0].matchedRideIds, [matchedRide.body.ride.rideId]);
  assertNoPrivateIdentifiers(mine.body);
  assert.deepEqual(
    (await api('get', '/api/intercity-rides/requests/mine', uids.passengerB))
      .body.requests,
    [],
  );
  assert.equal(
    (await pool.query('SELECT count(*) FROM intercity_ride_request_notifications WHERE request_id=$1', [requestFirst.body.request.requestId])).rows[0].count,
    '1',
  );
  assert.equal(
    (await api('post', `/api/intercity-rides/requests/${requestFirst.body.request.requestId}/cancel`, uids.passengerB)).status,
    404,
  );

  const rideFirst = await createRide({ originCity: 'Астана', destinationCity: 'Караганда', date, hour: 15 });
  const requestSecond = await api('post', '/api/intercity-rides/requests', uids.passengerB, {
    originCity: 'Астана', destinationCity: 'Караганда', travelDate: date, seats: 1,
  });
  assert.equal(requestSecond.status, 201);
  assert.deepEqual(requestSecond.body.request.matchedRideIds, [rideFirst.body.ride.rideId]);
  assert.equal(
    (await pool.query('SELECT count(*) FROM intercity_ride_request_notifications WHERE request_id=$1 AND ride_id=$2', [requestSecond.body.request.requestId, rideFirst.body.ride.rideId])).rows[0].count,
    '1',
  );

  const failureRequest = await api('post', '/api/intercity-rides/requests', uids.passengerC, {
    originCity: 'Павлодар', destinationCity: 'Семей', travelDate: date, seats: 1,
  });
  failNextType = 'intercity_ride_match_available';
  const committedDespitePushFailure = await createRide({ originCity: 'Павлодар', destinationCity: 'Семей', date, hour: 17 });
  assert.equal(committedDespitePushFailure.status, 201);
  assert.equal(
    (await pool.query('SELECT count(*) FROM intercity_ride_request_notifications WHERE request_id=$1', [failureRequest.body.request.requestId])).rows[0].count,
    '1',
  );
  assert.equal(pushes.filter((item) => item.payload.data.type === 'intercity_ride_match_available').length, 3);
});

test('depart and complete preserve booking lifecycle and remove ride from search', async () => {
  const date = travelDate(40);
  const created = await createRide({ date });
  const rideId = created.body.ride.rideId;
  const booking = await book(uids.passengerA, rideId, 1);
  assert.equal(booking.status, 201);
  const departed = await api('post', `/api/intercity-rides/${rideId}/depart`, uids.driverA);
  assert.equal(departed.status, 200);
  assert.equal(departed.body.ride.status, 'departed');
  assert.equal((await book(uids.passengerB, rideId, 1)).status, 409);
  assert.equal(
    (await api('post', `/api/intercity-rides/bookings/${booking.body.booking.bookingId}/cancel`, uids.passengerA)).status,
    409,
  );
  const completed = await api('post', `/api/intercity-rides/${rideId}/complete`, uids.driverA);
  assert.equal(completed.status, 200);
  assert.equal(completed.body.ride.status, 'completed');
  const stored = await pool.query('SELECT status FROM intercity_ride_bookings WHERE id=$1', [booking.body.booking.bookingId]);
  assert.equal(stored.rows[0].status, 'completed');
  assert.equal((await search(uids.passengerB, 'Есиль', 'Астана', date, 1)).body.rides.length, 0);
  assert.equal(pushes.filter((item) => item.payload.data.type === 'intercity_ride_departed').length, 1);
});

test('driver cancellation cancels all bookings, restores inventory and survives push failure', async () => {
  const date = travelDate(50);
  const created = await createRide({ date });
  const rideId = created.body.ride.rideId;
  await book(uids.passengerA, rideId, 1);
  await book(uids.passengerB, rideId, 1);
  failNextType = 'intercity_ride_cancelled';
  const cancelled = await api('post', `/api/intercity-rides/${rideId}/cancel`, uids.driverA);
  assert.equal(cancelled.status, 200);
  assert.equal(cancelled.body.ride.status, 'cancelled');
  const state = await rideState(rideId);
  assert.equal(state.available_seats, state.total_seats);
  assert.equal(state.confirmed_seats, 0);
  const bookings = await pool.query('SELECT status FROM intercity_ride_bookings WHERE ride_id=$1', [rideId]);
  assert.ok(bookings.rows.every((booking) => booking.status === 'cancelled'));
  assert.equal((await search(uids.passengerC, 'Есиль', 'Астана', date, 1)).body.rides.length, 0);
  assert.equal(pushes.filter((item) => item.payload.data.type === 'intercity_ride_cancelled').length, 2);
});
