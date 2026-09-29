import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';
import { createIntercityRidesRouter } from '../src/routes/intercity-rides.js';
import { normalizeIntercityCity, validateIntercityRideCreate, validateIntercityRidePatch, validateIntercityRideSearch } from '../src/intercity-ride-policy.js';

const rideId = '11111111-1111-4111-8111-111111111111';
const otherRideId = '22222222-2222-4222-8222-222222222222';
const future = new Date(Date.now() + 86_400_000).toISOString();
const valid = { originCity: 'Костанай', destinationCity: 'Есиль', originLat: 53.2, originLng: 63.6, destinationLat: 51.9, destinationLng: 66.4, departureAt: future, totalSeats: 3, pricePerSeat: 5000, allowsLuggage: true, comment: 'У вокзала' };

function row(overrides = {}) {
  return { id: rideId, driver_id: 'driver-db-id', origin_city: 'Костанай', origin_city_key: 'костанай', origin_lat: 53.2, origin_lng: 63.6, destination_city: 'Есиль', destination_city_key: 'есиль', destination_lat: 51.9, destination_lng: 66.4, departure_at: future, total_seats: 3, available_seats: 3, price_per_seat: 5000, allows_luggage: true, comment: null, status: 'scheduled', driver_name: 'Иван', car_model: 'Toyota', car_color: 'Белый', created_at: future, updated_at: future, firebase_uid: 'driver', ...overrides };
}

function appWith(pool, { authenticated = true, uid = 'driver' } = {}) {
  const app = express(); app.use(express.json());
  const auth = (req, res, next) => authenticated ? (req.user = { uid }, next()) : res.status(401).json({ error: 'Missing authorization token' });
  app.use('/api/intercity-rides', createIntercityRidesRouter({ pool, requireAuth: auth }));
  return app;
}

function createPool({ access = true, accessStatus = 'active', hasAccess = true, rides = [row()], booking = false } = {}) {
  const calls = [];
  const query = async (sql, params = []) => {
    calls.push({ sql, params }); const normalized = sql.replace(/\s+/g, ' ');
    if (normalized.includes('SELECT id, name, phone, account_status FROM users')) return { rows: [{ id: 'driver-db-id', name: 'Иван', phone: '+70000000000', account_status: 'active' }], rowCount: 1 };
    if (normalized.startsWith('SELECT 1 FROM account_deletion_jobs')) return { rows: [], rowCount: 0 };
    if (normalized.includes('FROM users u JOIN driver_profiles')) return { rows: access ? [{ driver_id: 'driver-db-id', driver_name: 'Иван', status: accessStatus, has_access: hasAccess, car_model: 'Toyota', car_color: 'Белый' }] : [] };
    if (normalized.startsWith('SELECT pg_advisory_xact_lock')) return { rows: [{}] };
    if (normalized.startsWith('INSERT INTO intercity_rides')) return { rows: [row({ origin_city: params[1], origin_city_key: params[2], available_seats: params[10], total_seats: params[10] })] };
    if (normalized.startsWith('INSERT INTO intercity_ride_request_notifications')) return { rows: [] };
    if (normalized.includes('FROM intercity_rides r JOIN users') && normalized.includes('FOR UPDATE')) return { rows: rides };
    if (normalized.includes('FROM intercity_ride_bookings')) return { rows: booking ? [{ '?column?': 1 }] : [] };
    if (normalized.startsWith('UPDATE intercity_ride_bookings SET')) return { rows: [] };
    if (normalized.startsWith('SELECT b.id AS booking_id') && normalized.includes('passenger_firebase_uid')) return { rows: [] };
    if (normalized.startsWith('UPDATE intercity_rides SET status = $1')) return { rows: [row({ status: params[0] })] };
    if (normalized.startsWith('UPDATE intercity_rides SET')) return { rows: [row()] };
    if (normalized.startsWith('UPDATE intercity_rides r SET')) return { rows: rides.length ? [row({ status: params[0] })] : [] };
    if (normalized.includes('FROM intercity_rides r JOIN users')) return { rows: rides };
    if (normalized === 'BEGIN' || normalized === 'COMMIT' || normalized === 'ROLLBACK') return { rows: [] };
    throw new Error(`Unexpected SQL: ${normalized}`);
  };
  const client = { query, release() {} };
  return { query, connect: async () => client, calls };
}

test('city normalization is deterministic (trim, NFC, case, ё/е)', () => {
  assert.deepEqual(normalizeIntercityCity('  ОрЁл  '), { display: 'ОрЁл', key: 'орел' });
  assert.equal(normalizeIntercityCity('Е\u0308силь').key, 'есиль');
});

test('create validation accepts valid payload and generates keys', () => {
  const result = validateIntercityRideCreate(valid);
  assert.equal(result.ok, true); assert.equal(result.value.originCityKey, 'костанай');
});

for (const [name, change] of [
  ['missing city', { originCity: '' }], ['same cities', { destinationCity: 'КОСТАНАЙ' }],
  ['past departure', { departureAt: '2020-01-01T00:00:00Z' }], ['too many seats', { totalSeats: 8 }],
  ['invalid price', { pricePerSeat: 1000001 }], ['invalid coordinates', { originLat: Infinity }],
  ['long comment', { comment: 'x'.repeat(1001) }], ['mass assignment', { status: 'completed' }],
]) test(`create validation rejects ${name}`, () => assert.equal(validateIntercityRideCreate({ ...valid, ...change }).ok, false));

test('search validates date and seats', () => {
  assert.equal(validateIntercityRideSearch({ originCity: 'Есиль', destinationCity: 'Костанай', travelDate: '2026-02-29', seats: '2' }).ok, false);
  assert.equal(validateIntercityRideSearch({ originCity: 'Есиль', destinationCity: 'Костанай', travelDate: '2028-02-29', seats: '7' }).ok, true);
  assert.equal(validateIntercityRideSearch({ originCity: 'Есиль', destinationCity: 'Костанай', travelDate: '2028-02-29', seats: '8' }).ok, false);
});

test('patch rejects unknown and protected fields', () => {
  assert.equal(validateIntercityRidePatch({ driverId: 'x' }).ok, false);
  assert.equal(validateIntercityRidePatch({ surprise: true }).ok, false);
});

test('all endpoints require auth', async () => {
  const response = await request(appWith(createPool(), { authenticated: false })).get('/api/intercity-rides/mine');
  assert.equal(response.status, 401);
});

test('approved driver can create a ride for free without private identifier leakage', async () => {
  const pool = createPool(); const response = await request(appWith(pool)).post('/api/intercity-rides').send(valid);
  assert.equal(response.status, 201); assert.equal(response.body.ride.rideId, rideId);
  assert.equal(response.body.matchedRequestCount, 0);
  assert.equal(response.body.ride.driver.name, 'Иван');
  assert.equal(JSON.stringify(response.body).includes('firebase'), false);
  assert.equal(JSON.stringify(response.body).includes('driver-db-id'), false);
  const accessQuery = pool.calls.find((call) =>
    call.sql.includes('FROM users u') && call.sql.includes('JOIN driver_profiles'));
  assert.doesNotMatch(accessQuery.sql, /driver_subscriptions/);
});

for (const [name, options] of [['pending driver', { accessStatus: 'pending' }], ['suspended driver', { accessStatus: 'suspended' }], ['missing profile', { access: false }]]) {
  test(`${name} cannot create`, async () => assert.equal((await request(appWith(createPool(options))).post('/api/intercity-rides').send(valid)).status, 403));
}

test('mine and own details return safe rides; invalid UUID is rejected', async () => {
  const app = appWith(createPool());
  assert.equal((await request(app).get('/api/intercity-rides/mine')).body.rides.length, 1);
  assert.equal((await request(app).get(`/api/intercity-rides/${rideId}`)).status, 200);
  assert.equal((await request(app).get('/api/intercity-rides/not-a-uuid')).status, 400);
});

test('foreign non-public ride is hidden (IDOR)', async () => {
  const response = await request(appWith(createPool({ rides: [] }), { uid: 'other' })).get(`/api/intercity-rides/${otherRideId}`);
  assert.equal(response.status, 404);
});

test('search SQL enforces status, future departure and requested seats', async () => {
  const pool = createPool();
  const response = await request(appWith(pool)).get('/api/intercity-rides/search').query({ originCity: 'Костанай', destinationCity: 'Есиль', travelDate: '2028-08-25', seats: 3 });
  assert.equal(response.status, 200);
  const call = pool.calls.at(-1); assert.match(call.sql, /status='scheduled'/); assert.match(call.sql, /departure_at > now\(\)/); assert.match(call.sql, /available_seats >= \$5/); assert.equal(call.params[4], 3);
});

test('patch is owner-only and confirmed booking locks route fields', async () => {
  assert.equal((await request(appWith(createPool({ rides: [row({ firebase_uid: 'owner' })] }))).patch(`/api/intercity-rides/${rideId}`).send({ comment: 'ok' })).status, 403);
  assert.equal((await request(appWith(createPool({ booking: true }))).patch(`/api/intercity-rides/${rideId}`).send({ departureAt: future })).status, 409);
  assert.equal((await request(appWith(createPool({ booking: true }))).patch(`/api/intercity-rides/${rideId}`).send({ pricePerSeat: 6000 })).status, 200);
});

test('only scheduled ride can be patched', async () => {
  const response = await request(appWith(createPool({ rides: [row({ status: 'departed' })] }))).patch(`/api/intercity-rides/${rideId}`).send({ comment: 'x' });
  assert.equal(response.status, 409);
});

test('patch cannot make origin and destination the same city', async () => {
  const response = await request(appWith(createPool())).patch(`/api/intercity-rides/${rideId}`).send({ originCity: 'ЕСИЛЬ' });
  assert.equal(response.status, 400);
});

for (const [action, status] of [['cancel','cancelled'],['depart','departed'],['complete','completed']]) {
  test(`${action} performs owner lifecycle transition`, async () => {
    const initialStatus = action === 'complete' ? 'departed' : 'scheduled';
    const response = await request(appWith(createPool({ rides: [row({ status: initialStatus })] }))).post(`/api/intercity-rides/${rideId}/${action}`);
    assert.equal(response.status, 200); assert.equal(response.body.ride.status, status);
  });
}

test('invalid lifecycle transition has stable conflict', async () => {
  const response = await request(appWith(createPool({ rides: [row({ status: 'scheduled' })] }))).post(`/api/intercity-rides/${rideId}/complete`);
  assert.equal(response.status, 409); assert.match(response.body.error, /cannot transition/);
});
