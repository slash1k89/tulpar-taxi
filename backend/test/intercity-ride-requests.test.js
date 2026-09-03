import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import express from 'express';
import request from 'supertest';
import { createIntercityRidesRouter } from '../src/routes/intercity-rides.js';
import {
  normalizeIntercityCity,
  validateIntercityRideRequestCreate,
} from '../src/intercity-ride-policy.js';

const rideId = '11111111-1111-4111-8111-111111111111';
const secondRideId = '22222222-2222-4222-8222-222222222222';
const requestId = '33333333-3333-4333-8333-333333333333';
const secondRequestId = '44444444-4444-4444-8444-444444444444';

function kzDate(daysAhead = 1) {
  return new Date(Date.now() + daysAhead * 86_400_000 + 5 * 3_600_000)
    .toISOString()
    .slice(0, 10);
}

const travelDate = kzDate();
const departureAt = `${travelDate}T12:00:00+05:00`;
const validRequest = {
  originCity: 'Костанай',
  destinationCity: 'Есиль',
  travelDate,
  seats: 2,
};
const validRide = {
  originCity: 'Костанай',
  destinationCity: 'Есиль',
  originLat: 53.2,
  originLng: 63.6,
  destinationLat: 51.9,
  destinationLng: 66.4,
  departureAt,
  totalSeats: 4,
  pricePerSeat: 5000,
  allowsLuggage: true,
  comment: null,
};

function user(id, uid, name) {
  return { id, firebase_uid: uid, name, phone: '+70000000000' };
}

function rideRow(overrides = {}) {
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
    departure_at: departureAt,
    total_seats: 4,
    available_seats: 4,
    price_per_seat: 5000,
    allows_luggage: true,
    comment: null,
    status: 'scheduled',
    created_at: departureAt,
    updated_at: departureAt,
    ...overrides,
  };
}

function requestRow(overrides = {}) {
  return {
    id: requestId,
    passenger_id: 'passenger-a-db-id',
    origin_city: 'Костанай',
    origin_city_key: 'костанай',
    destination_city: 'Есиль',
    destination_city_key: 'есиль',
    travel_date: travelDate,
    seats: 2,
    pickup_address: null,
    pickup_lat: null,
    pickup_lng: null,
    passenger_comment: null,
    status: 'active',
    cancelled_at: null,
    created_at: departureAt,
    updated_at: departureAt,
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

function rideTravelDate(value) {
  return new Date(new Date(value).getTime() + 5 * 3_600_000)
    .toISOString()
    .slice(0, 10);
}

function createPool({
  rides = [],
  rideRequests = [],
  notifications = [],
} = {}) {
  let state = {
    users: [
      user('driver-db-id', 'driver-uid', 'Fixture Driver'),
      user('passenger-a-db-id', 'passenger-a-uid', 'Fixture Passenger A'),
      user('passenger-b-db-id', 'passenger-b-uid', 'Fixture Passenger B'),
    ],
    rides: structuredClone(rides),
    requests: structuredClone(rideRequests),
    notifications: structuredClone(notifications),
    nextRide: rides.length + 1,
    nextRequest: rideRequests.length + 1,
  };
  const calls = [];
  const acquire = createMutex();

  function withMatches(item) {
    return {
      ...item,
      matched_ride_ids: state.notifications
        .filter((entry) => entry.request_id === item.id)
        .map((entry) => entry.ride_id),
    };
  }

  function addNotification(currentRequestId, currentRideId) {
    const duplicate = state.notifications.some(
      (item) =>
        item.request_id === currentRequestId && item.ride_id === currentRideId,
    );
    if (duplicate) return false;
    state.notifications.push({
      request_id: currentRequestId,
      ride_id: currentRideId,
    });
    return true;
  }

  async function execute(sql, params = []) {
    const text = normalize(sql);
    calls.push({ sql, params, text });

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
    if (text.includes('FROM users u JOIN driver_profiles')) {
      const driver = state.users.find((item) => item.firebase_uid === params[0]);
      return {
        rows: driver
          ? [{
              driver_id: driver.id,
              driver_name: driver.name,
              status: 'active',
              has_access: true,
              car_model: 'Fixture Car',
              car_color: 'Fixture Color',
            }]
          : [],
      };
    }
    if (text.startsWith('SELECT id, name, phone FROM users')) {
      return {
        rows: state.users.filter((item) => item.firebase_uid === params[0]),
      };
    }
    if (text.startsWith('SELECT id FROM users WHERE id = $1 FOR UPDATE')) {
      return { rows: [{ id: params[0] }] };
    }
    if (text.startsWith('SELECT pg_advisory_xact_lock')) {
      return { rows: [{}] };
    }
    if (
      text.startsWith('SELECT id FROM intercity_ride_requests')
      && text.includes("status = 'active'")
    ) {
      const found = state.requests.find(
        (item) =>
          item.passenger_id === params[0]
          && item.origin_city_key === params[1]
          && item.destination_city_key === params[2]
          && item.travel_date === params[3]
          && item.status === 'active',
      );
      return { rows: found ? [{ id: found.id }] : [] };
    }
    if (text.startsWith('INSERT INTO intercity_ride_requests')) {
      const created = requestRow({
        id: state.nextRequest === 1 ? requestId : secondRequestId,
        passenger_id: params[0],
        origin_city: params[1],
        origin_city_key: params[2],
        destination_city: params[3],
        destination_city_key: params[4],
        travel_date: params[5],
        seats: params[6],
        pickup_address: params[7],
        pickup_lat: params[8],
        pickup_lng: params[9],
        passenger_comment: params[10],
      });
      state.nextRequest += 1;
      state.requests.push(created);
      return { rows: [created] };
    }
    if (
      text.startsWith('INSERT INTO intercity_ride_request_notifications')
      && text.includes('SELECT $1, r.id')
    ) {
      const currentRequest = state.requests.find((item) => item.id === params[0]);
      const rows = [];
      for (const item of state.rides) {
        if (
          item.status === 'scheduled'
          && new Date(item.departure_at) > new Date()
          && item.origin_city_key === params[1]
          && item.destination_city_key === params[2]
          && rideTravelDate(item.departure_at) === params[3]
          && item.available_seats >= params[4]
          && addNotification(currentRequest.id, item.id)
        ) {
          rows.push({ ride_id: item.id });
        }
      }
      return { rows };
    }
    if (
      text.startsWith('SELECT q.id AS request_id')
      && text.includes('AS firebase_uid')
      && text.includes('ANY($1::uuid[])')
    ) {
      return {
        rows: state.requests
          .filter((item) => params[0].includes(item.id))
          .map((item) => {
            const passenger = state.users.find(
              (entry) => entry.id === item.passenger_id,
            );
            return {
              request_id: item.id,
              firebase_uid: passenger.firebase_uid,
            };
          }),
      };
    }
    if (text.startsWith('INSERT INTO intercity_rides')) {
      const created = rideRow({
        id: state.nextRide === 1 ? rideId : secondRideId,
        driver_id: params[0],
        origin_city: params[1],
        origin_city_key: params[2],
        origin_lat: params[3],
        origin_lng: params[4],
        destination_city: params[5],
        destination_city_key: params[6],
        destination_lat: params[7],
        destination_lng: params[8],
        departure_at: params[9],
        total_seats: params[10],
        available_seats: params[10],
        price_per_seat: params[11],
        allows_luggage: params[12],
        comment: params[13],
      });
      state.nextRide += 1;
      state.rides.push(created);
      return { rows: [created] };
    }
    if (
      text.startsWith('INSERT INTO intercity_ride_request_notifications')
      && text.includes('SELECT q.id, $1')
    ) {
      const rows = [];
      for (const item of state.requests) {
        if (
          item.status === 'active'
          && item.origin_city_key === params[1]
          && item.destination_city_key === params[2]
          && item.travel_date === rideTravelDate(params[3])
          && item.seats <= params[4]
          && new Date(params[3]) > new Date()
          && addNotification(item.id, params[0])
        ) {
          rows.push({ request_id: item.id });
        }
      }
      return { rows };
    }
    if (
      text.includes('FROM intercity_ride_requests q')
      && text.includes('WHERE q.passenger_id = $1')
    ) {
      return {
        rows: state.requests
          .filter((item) => item.passenger_id === params[0])
          .map(withMatches),
      };
    }
    if (
      text.startsWith('SELECT origin_city_key, destination_city_key, travel_date')
    ) {
      const found = state.requests.find(
        (item) => item.id === params[0] && item.passenger_id === params[1],
      );
      return {
        rows: found
          ? [{
              origin_city_key: found.origin_city_key,
              destination_city_key: found.destination_city_key,
              travel_date: found.travel_date,
            }]
          : [],
      };
    }
    if (
      text.startsWith('SELECT * FROM intercity_ride_requests')
      && text.includes('FOR UPDATE')
    ) {
      const found = state.requests.find(
        (item) => item.id === params[0] && item.passenger_id === params[1],
      );
      return { rows: found ? [found] : [] };
    }
    if (text.startsWith('UPDATE intercity_ride_requests')) {
      const found = state.requests.find((item) => item.id === params[0]);
      if (found) {
        found.status = 'cancelled';
        found.cancelled_at = new Date().toISOString();
      }
      return { rows: [] };
    }
    if (
      text.includes('FROM intercity_ride_requests q')
      && text.includes('WHERE q.id = $1')
    ) {
      const found = state.requests.find((item) => item.id === params[0]);
      return { rows: found ? [withMatches(found)] : [] };
    }
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

function createRequest(app, body = validRequest) {
  return request(app).post('/api/intercity-rides/requests').send(body);
}

test('request validation uses shared city normalization and NFC', () => {
  const normalized = normalizeIntercityCity('  ОрЁл   NFC  ');
  assert.deepEqual(normalized, { display: 'ОрЁл NFC', key: 'орел nfc' });
  const result = validateIntercityRideRequestCreate({
    ...validRequest,
    originCity: '  ОрЁл   ',
    destinationCity: ' ЕСИЛЬ ',
  });
  assert.equal(result.ok, true);
  assert.equal(result.value.originCityKey, 'орел');
  assert.equal(result.value.destinationCityKey, 'есиль');
});

test('request validation rejects missing, invalid or equal cities', () => {
  for (const body of [
    { ...validRequest, originCity: '' },
    { ...validRequest, destinationCity: null },
    { ...validRequest, destinationCity: ' КОСТАНАЙ ' },
  ]) {
    assert.equal(validateIntercityRideRequestCreate(body).ok, false);
  }
});

test('request validation rejects past or invalid date and invalid seats', () => {
  for (const change of [
    { travelDate: '2020-01-01' },
    { travelDate: '2026-02-29' },
    { travelDate: 'bad' },
    { seats: '2' },
    { seats: 1.5 },
    { seats: 0 },
    { seats: -1 },
    { seats: 8 },
  ]) {
    assert.equal(
      validateIntercityRideRequestCreate({ ...validRequest, ...change }).ok,
      false,
    );
  }
  const now = new Date('2026-08-26T12:00:00+05:00');
  assert.equal(
    validateIntercityRideRequestCreate(
      { ...validRequest, travelDate: '2026-08-26' },
      { now },
    ).ok,
    false,
  );
  assert.equal(
    validateIntercityRideRequestCreate(
      { ...validRequest, travelDate: '2026-08-27' },
      { now },
    ).ok,
    true,
  );
});

test('request pickup validation supports legacy and complete normalized data', () => {
  assert.equal(validateIntercityRideRequestCreate(validRequest).ok, true);
  const complete = validateIntercityRideRequestCreate({
    ...validRequest,
    pickupAddress: '  пр. Республики, 10 ',
    pickupLat: 51.17,
    pickupLng: 71.43,
    passengerComment: '  С чемоданом ',
  });
  assert.equal(complete.ok, true);
  assert.equal(complete.value.pickupAddress, 'пр. Республики, 10');
  assert.equal(complete.value.passengerComment, 'С чемоданом');
  assert.equal(validateIntercityRideRequestCreate({
    ...validRequest, passengerComment: '  ',
  }).value.passengerComment, null);

  for (const invalid of [
    { pickupAddress: 'Адрес' },
    { pickupAddress: ' ', pickupLat: 1, pickupLng: 1 },
    { pickupAddress: 'x'.repeat(501), pickupLat: 1, pickupLng: 1 },
    { pickupAddress: 'Адрес', pickupLat: -91, pickupLng: 1 },
    { pickupAddress: 'Адрес', pickupLat: 1, pickupLng: -181 },
    { pickupAddress: 'Адрес', pickupLat: Number.NaN, pickupLng: 1 },
    { pickupAddress: 'Адрес', pickupLat: 1, pickupLng: Infinity },
    { passengerComment: 'x'.repeat(1001) },
    { passengerComment: false },
  ]) {
    assert.equal(validateIntercityRideRequestCreate({
      ...validRequest, ...invalid,
    }).ok, false);
  }
});

test('request endpoints require auth', async () => {
  const app = appWith(createPool(), { authenticated: false });
  const responses = await Promise.all([
    createRequest(app),
    request(app).get('/api/intercity-rides/requests/mine'),
    request(app).post(`/api/intercity-rides/requests/${requestId}/cancel`),
  ]);
  assert.deepEqual(responses.map((item) => item.status), [401, 401, 401]);
});

test('create and mine return only authenticated passenger requests', async () => {
  const pool = createPool();
  const app = appWith(pool);
  const created = await createRequest(app);
  assert.equal(created.status, 201);
  assert.equal(created.body.request.requestId, requestId);
  assert.equal(created.body.request.status, 'active');
  const mine = await request(app).get('/api/intercity-rides/requests/mine');
  assert.equal(mine.status, 200);
  assert.equal(mine.body.requests.length, 1);
  const foreign = await request(
    appWith(pool, { uid: 'passenger-b-uid' }),
  ).get('/api/intercity-rides/requests/mine');
  assert.equal(foreign.body.requests.length, 0);
});

test('request owner sees pickup, cancellation preserves it, and foreign user cannot access it', async () => {
  const pool = createPool();
  const pickup = {
    pickupAddress: 'пр. Республики, 10',
    pickupLat: 51.17,
    pickupLng: 71.43,
    passengerComment: 'С чемоданом',
  };
  const app = appWith(pool);
  const created = await createRequest(app, { ...validRequest, ...pickup });
  assert.equal(created.status, 201);
  assert.equal(created.body.request.pickupAddress, pickup.pickupAddress);
  const mine = await request(app).get('/api/intercity-rides/requests/mine');
  assert.equal(mine.body.requests[0].passengerComment, pickup.passengerComment);
  const foreignMine = await request(
    appWith(pool, { uid: 'passenger-b-uid' }),
  ).get('/api/intercity-rides/requests/mine');
  assert.deepEqual(foreignMine.body.requests, []);
  const cancelled = await request(app).post(
    `/api/intercity-rides/requests/${created.body.request.requestId}/cancel`,
  );
  assert.equal(cancelled.status, 200);
  assert.equal(cancelled.body.request.pickupAddress, pickup.pickupAddress);
  assert.equal(pool.state.requests[0].pickup_address, pickup.pickupAddress);
});

test('request matching and push remain independent from private pickup data', async () => {
  const pool = createPool({ rides: [rideRow()] });
  const pushes = [];
  const response = await createRequest(appWith(pool, {
    sendPushToUser: async (uid, payload) => pushes.push({ uid, payload }),
  }), {
    ...validRequest,
    pickupAddress: 'Секретный адрес',
    pickupLat: 51.17,
    pickupLng: 71.43,
    passengerComment: 'Секретный комментарий',
  });
  assert.equal(response.status, 201);
  assert.deepEqual(response.body.request.matchedRideIds, [rideId]);
  assert.equal(pushes.length, 1);
  const push = JSON.stringify(pushes[0].payload);
  for (const privateValue of [
    'pickupAddress', 'pickupLat', 'pickupLng', 'passengerComment',
    'Секретный адрес', 'Секретный комментарий',
  ]) {
    assert.equal(push.includes(privateValue), false);
  }
});

test('mass assignment fields are rejected before database writes', async () => {
  for (const extra of [
    { passengerId: 'other' },
    { status: 'active' },
    { matchedAt: departureAt },
    { cancelledAt: departureAt },
    { expiredAt: departureAt },
    { originCityKey: 'spoof' },
    { destination_city_key: 'spoof' },
    { createdAt: departureAt },
  ]) {
    const pool = createPool();
    const response = await createRequest(appWith(pool), {
      ...validRequest,
      ...extra,
    });
    assert.equal(response.status, 400);
    assert.equal(pool.state.requests.length, 0);
  }
});

test('duplicate active request returns 409, including concurrent create', async () => {
  const pool = createPool();
  const app = appWith(pool);
  const responses = await Promise.all([createRequest(app), createRequest(app)]);
  assert.deepEqual(responses.map((item) => item.status).sort(), [201, 409]);
  assert.equal(pool.state.requests.length, 1);
});

test('owner cancellation is idempotent and foreign cancellation is hidden', async () => {
  const pool = createPool({ rideRequests: [requestRow()] });
  const foreign = await request(
    appWith(pool, { uid: 'passenger-b-uid' }),
  ).post(`/api/intercity-rides/requests/${requestId}/cancel`);
  assert.equal(foreign.status, 404);
  const app = appWith(pool);
  const first = await request(app).post(
    `/api/intercity-rides/requests/${requestId}/cancel`,
  );
  const second = await request(app).post(
    `/api/intercity-rides/requests/${requestId}/cancel`,
  );
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.equal(pool.state.requests[0].status, 'cancelled');
});

test('expired request cannot be cancelled and invalid UUID is rejected', async () => {
  const pool = createPool({
    rideRequests: [requestRow({ status: 'expired' })],
  });
  assert.equal(
    (
      await request(appWith(pool)).post(
        `/api/intercity-rides/requests/${requestId}/cancel`,
      )
    ).status,
    409,
  );
  assert.equal(
    (
      await request(appWith(pool)).post(
        '/api/intercity-rides/requests/not-a-uuid/cancel',
      )
    ).status,
    400,
  );
});

test('request responses do not expose private user identifiers', async () => {
  const pool = createPool();
  await createRequest(appWith(pool));
  const response = await request(appWith(pool)).get(
    '/api/intercity-rides/requests/mine',
  );
  const json = JSON.stringify(response.body);
  for (const secret of [
    'passenger-a-db-id',
    'passenger-a-uid',
    'firebase_uid',
    '+70000000000',
    'push',
  ]) {
    assert.equal(json.includes(secret), false);
  }
});

test('creating request matches all suitable existing rides', async () => {
  const pool = createPool({
    rides: [rideRow(), rideRow({ id: secondRideId, available_seats: 3 })],
  });
  const response = await createRequest(appWith(pool));
  assert.equal(response.status, 201);
  assert.deepEqual(
    response.body.request.matchedRideIds.sort(),
    [rideId, secondRideId].sort(),
  );
  assert.equal(pool.state.notifications.length, 2);
});

test('creating ride matches all suitable active requests', async () => {
  const pool = createPool({
    rideRequests: [
      requestRow(),
      requestRow({
        id: secondRequestId,
        passenger_id: 'passenger-b-db-id',
        seats: 3,
      }),
    ],
  });
  const response = await request(appWith(pool, { uid: 'driver-uid' }))
    .post('/api/intercity-rides')
    .send(validRide);
  assert.equal(response.status, 201);
  assert.equal(response.body.matchedRequestCount, 2);
  assert.equal(pool.state.notifications.length, 2);
});

test('route, date and seat mismatches do not create notifications', async () => {
  const scenarios = [
    rideRow({ origin_city_key: 'астана' }),
    rideRow({ departure_at: `${kzDate(2)}T12:00:00+05:00` }),
    rideRow({ available_seats: 1 }),
  ];
  for (const currentRide of scenarios) {
    const pool = createPool({ rides: [currentRide] });
    const response = await createRequest(appWith(pool));
    assert.equal(response.status, 201);
    assert.deepEqual(response.body.request.matchedRideIds, []);
    assert.equal(pool.state.notifications.length, 0);
  }
});

test('cancelled, departed and completed rides do not match', async () => {
  for (const status of ['cancelled', 'departed', 'completed']) {
    const pool = createPool({ rides: [rideRow({ status })] });
    await createRequest(appWith(pool));
    assert.equal(pool.state.notifications.length, 0);
  }
});

test('cancelled request does not match a newly created ride', async () => {
  const pool = createPool({
    rideRequests: [requestRow({ status: 'cancelled' })],
  });
  const response = await request(appWith(pool, { uid: 'driver-uid' }))
    .post('/api/intercity-rides')
    .send(validRide);
  assert.equal(response.status, 201);
  assert.equal(response.body.matchedRequestCount, 0);
  assert.equal(pool.state.notifications.length, 0);
});

test('notification pair has database uniqueness and matching uses conflict-safe insert', async () => {
  const pool = createPool({ rides: [rideRow()] });
  await createRequest(appWith(pool));
  const matchingCall = pool.calls.find((call) =>
    call.text.startsWith('INSERT INTO intercity_ride_request_notifications'));
  assert.match(
    matchingCall.text,
    /ON CONFLICT \(request_id, ride_id\) DO NOTHING/,
  );
  const migration = await readFile(
    new URL('../migrations/20260825_002_intercity_rides.sql', import.meta.url),
    'utf8',
  );
  assert.match(
    migration,
    /UNIQUE \(request_id, ride_id\)/,
  );
  assert.equal(pool.state.notifications.length, 1);
});

test('request and ride creation use the same route/date advisory lock', async () => {
  const pool = createPool();
  await createRequest(appWith(pool));
  await request(appWith(pool, { uid: 'driver-uid' }))
    .post('/api/intercity-rides')
    .send(validRide);
  const locks = pool.calls.filter((call) =>
    call.text.startsWith('SELECT pg_advisory_xact_lock')
      && call.params.length === 1);
  assert.equal(locks.length, 2);
  assert.equal(locks[0].params[0], locks[1].params[0]);
  const firstRouteLock = pool.calls.findIndex((call) =>
    call.text.startsWith('SELECT pg_advisory_xact_lock')
      && call.params.length === 1);
  const firstLifecycleLock = pool.calls.findIndex((call) =>
    call.text.startsWith('SELECT pg_advisory_xact_lock')
      && call.params.length === 2);
  assert.ok(firstLifecycleLock < firstRouteLock);
});

test('request matching existing rides pushes once for every newly inserted pair', async () => {
  const pool = createPool({
    rides: [rideRow(), rideRow({ id: secondRideId })],
  });
  const pushes = [];
  const app = appWith(pool, {
    sendPushToUser: async (uid, payload) => {
      assert.equal(pool.calls.at(-1).text, 'COMMIT');
      pushes.push({ uid, payload });
    },
  });
  assert.equal((await createRequest(app)).status, 201);
  assert.equal(pushes.length, 2);
  assert.deepEqual(
    pushes.map((item) => item.payload.data.rideId).sort(),
    [rideId, secondRideId].sort(),
  );
  for (const push of pushes) {
    assert.equal(push.uid, 'passenger-a-uid');
    assert.equal(push.payload.data.type, 'intercity_ride_match_available');
    assert.equal(push.payload.data.requestId, requestId);
    assert.equal(
      push.payload.body,
      'Появилась попутка Костанай → Есиль',
    );
    const json = JSON.stringify(push.payload);
    for (const privateValue of [
      'passenger-a-uid',
      'passenger-a-db-id',
      '+70000000000',
      'token',
    ]) {
      assert.equal(json.includes(privateValue), false);
    }
  }
});

test('new ride matching existing requests pushes each passenger', async () => {
  const pool = createPool({
    rideRequests: [
      requestRow(),
      requestRow({
        id: secondRequestId,
        passenger_id: 'passenger-b-db-id',
      }),
    ],
  });
  const pushes = [];
  const response = await request(
    appWith(pool, {
      uid: 'driver-uid',
      sendPushToUser: async (uid, payload) => pushes.push({ uid, payload }),
    }),
  )
    .post('/api/intercity-rides')
    .send(validRide);
  assert.equal(response.status, 201);
  assert.equal(pushes.length, 2);
  assert.deepEqual(
    pushes.map((item) => item.uid).sort(),
    ['passenger-a-uid', 'passenger-b-uid'].sort(),
  );
  assert.deepEqual(
    pushes.map((item) => item.payload.data.requestId).sort(),
    [requestId, secondRequestId].sort(),
  );
  assert.ok(
    pushes.every(
      (item) => item.payload.data.type === 'intercity_ride_match_available',
    ),
  );
});

test('duplicate active request does not produce a second match push', async () => {
  const pool = createPool({ rides: [rideRow()] });
  const pushes = [];
  const app = appWith(pool, {
    sendPushToUser: async (...args) => pushes.push(args),
  });
  assert.equal((await createRequest(app)).status, 201);
  assert.equal((await createRequest(app)).status, 409);
  assert.equal(pushes.length, 1);
  assert.equal(pool.state.notifications.length, 1);
});

test('matching push failure after commit keeps request creation successful', async () => {
  const pool = createPool({ rides: [rideRow()] });
  const response = await createRequest(
    appWith(pool, {
      sendPushToUser: async () => {
        const failure = new Error('FCM unavailable');
        failure.code = 'messaging/unavailable';
        throw failure;
      },
    }),
  );
  assert.equal(response.status, 201);
  assert.equal(pool.state.requests.length, 1);
  assert.equal(pool.state.notifications.length, 1);
});
