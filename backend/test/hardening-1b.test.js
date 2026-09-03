import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import {
  cityOrderLifetimeMs,
  expireStaleSearchingOrders,
  isSearchingOrderExpired,
  orderValidationLimits,
  validateOrderCreatePayload,
} from '../src/order-policy.js';
import { createDriverProfileRouter } from '../src/routes/driver-profile.js';
import { createOrdersRouter } from '../src/routes/orders.js';

const now = new Date('2026-08-25T12:00:00.000Z');

function validCityPayload(overrides = {}) {
  return {
    serviceType: 'city',
    passengerPrice: 1_000,
    pickupAddress: 'Есиль, ул. Абая, 1',
    destinationAddress: 'Есиль, ул. Ауэзова, 2',
    pickupLat: 51.9555,
    pickupLng: 66.4042,
    destinationLat: 51.96,
    destinationLng: 66.41,
    distanceMeters: 2_500,
    ...overrides,
  };
}

function fakeAuth(req, _res, next) {
  req.user = { uid: 'firebase-user', phone: '+77001234567' };
  next();
}

function createInvalidOrderApp() {
  const pool = {
    async connect() {
      throw new Error('DB must not be reached for an invalid payload');
    },
    async query() {
      throw new Error('DB must not be reached for an invalid payload');
    },
  };
  const app = express();
  app.use(express.json());
  app.use(
    '/api/orders',
    createOrdersRouter({
      pool,
      requireAuth: fakeAuth,
      sendToUser: () => {},
      sendToAvailableDrivers: () => {},
      sendPushToUser: async () => ({ successCount: 0, failureCount: 0 }),
    }),
  );
  return app;
}

function createValidOrderApp() {
  const client = {
    async query(sql, params = []) {
      const query = String(sql).replace(/\s+/g, ' ').trim();
      if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(query)) return { rows: [] };
      if (query.startsWith('SELECT pg_advisory_xact_lock')) {
        return { rows: [{}], rowCount: 1 };
      }
      if (query.startsWith('SELECT id, name, phone, account_status FROM users')) {
        return {
          rows: [{
            id: 'passenger-1',
            name: 'Fixture Passenger',
            phone: '+70000000000',
            account_status: 'active',
          }],
          rowCount: 1,
        };
      }
      if (query.startsWith('SELECT 1 FROM account_deletion_jobs')) {
        return { rows: [], rowCount: 0 };
      }
      if (query.includes('FROM users') && query.includes('firebase_uid')) {
        return { rows: [{ id: 'passenger-1' }] };
      }
      if (query.includes('FROM service_tariffs')) {
        return {
          rows: [
            {
              minimum_day_fare: 600,
              minimum_night_fare: 700,
              day_start_hour: 6,
              night_start_hour: 22,
            },
          ],
        };
      }
      if (query.startsWith('INSERT INTO orders')) {
        return {
          rows: [
            {
              id: `order-${params[1]}`,
              service_type: params[1],
              status: 'searching',
              passenger_price: params[2],
              agreed_price: null,
              pickup_address: params[3],
              destination_address: params[4],
              pickup_lat: params[5],
              pickup_lng: params[6],
              destination_lat: params[7],
              destination_lng: params[8],
              distance_meters: params[9],
              created_at: now,
            },
          ],
        };
      }
      if (
        query.startsWith('INSERT INTO delivery_details') ||
        query.startsWith('INSERT INTO intercity_details')
      ) {
        return { rows: [] };
      }
      throw new Error(`Unexpected test query: ${query}`);
    },
    release() {},
  };
  const pool = {
    async connect() {
      return client;
    },
    async query(sql) {
      const query = String(sql).replace(/\s+/g, ' ').trim();
      if (query.startsWith('UPDATE orders o') && query.includes("status = 'expired'")) {
        return { rows: [] };
      }
      throw new Error(`Unexpected pool query: ${query}`);
    },
  };
  const app = express();
  app.use(express.json());
  app.use(
    '/api/orders',
    createOrdersRouter({
      pool,
      requireAuth: fakeAuth,
      sendToUser: () => {},
      sendToAvailableDrivers: async () => {},
      sendPushToUser: async () => ({ successCount: 0, failureCount: 0 }),
    }),
  );
  return app;
}

test('bad latitude returns HTTP 400 before DB access', async () => {
  const response = await request(createInvalidOrderApp())
    .post('/api/orders')
    .send(validCityPayload({ pickupLat: 91 }));

  assert.equal(response.status, 400);
  assert.deepEqual(response.body, { error: 'pickup latitude is invalid' });
});

test('bad longitude is rejected', () => {
  const result = validateOrderCreatePayload(
    validCityPayload({ destinationLng: -181 }),
    { now },
  );
  assert.equal(result.ok, false);
  assert.equal(result.error, 'destination longitude is invalid');
});

test('NaN, Infinity and string lookalikes are rejected as coordinates', () => {
  for (const invalidValue of [NaN, Infinity, -Infinity, 'NaN', 'Infinity']) {
    const result = validateOrderCreatePayload(
      validCityPayload({ pickupLat: invalidValue }),
      { now },
    );
    assert.equal(result.ok, false, `value ${String(invalidValue)} must fail`);
  }
});

test('bad address types and empty addresses are rejected', () => {
  assert.equal(
    validateOrderCreatePayload(validCityPayload({ pickupAddress: 123 }), { now }).ok,
    false,
  );
  assert.equal(
    validateOrderCreatePayload(validCityPayload({ destinationAddress: '   ' }), {
      now,
    }).ok,
    false,
  );
});

test('too large passenger price and client agreedPrice are rejected', () => {
  assert.equal(
    validateOrderCreatePayload(
      validCityPayload({ passengerPrice: orderValidationLimits.passengerPrice + 1 }),
      { now },
    ).ok,
    false,
  );
  assert.equal(
    validateOrderCreatePayload(validCityPayload({ agreedPrice: 1_000 }), { now }).ok,
    false,
  );
});

test('too large or non-integer distance is rejected', () => {
  assert.equal(
    validateOrderCreatePayload(
      validCityPayload({ distanceMeters: orderValidationLimits.distanceMeters + 1 }),
      { now },
    ).ok,
    false,
  );
  assert.equal(
    validateOrderCreatePayload(validCityPayload({ distanceMeters: 1.5 }), { now }).ok,
    false,
  );
});

test('coordinate pairs must be both present or both null', () => {
  assert.equal(
    validateOrderCreatePayload(validCityPayload({ pickupLng: null }), { now }).ok,
    false,
  );
  assert.equal(
    validateOrderCreatePayload(
      validCityPayload({ pickupLat: null, pickupLng: null }),
      { now },
    ).ok,
    true,
  );
});

test('invalid delivery field types and lengths are rejected', () => {
  const base = validCityPayload({
    serviceType: 'delivery',
    itemDescription: 'Документы',
    recipientPhone: '+77001234567',
  });

  assert.equal(
    validateOrderCreatePayload({ ...base, pickupComment: 123 }, { now }).ok,
    false,
  );
  assert.equal(
    validateOrderCreatePayload(
      { ...base, pickupIntercom: 'x'.repeat(orderValidationLimits.intercom + 1) },
      { now },
    ).ok,
    false,
  );
});

test('invalid intercity fields are rejected', () => {
  const base = validCityPayload({
    serviceType: 'intercity',
    departureAt: '2026-08-26T08:00:00.000Z',
    passengerCount: 2,
    hasLuggage: true,
  });

  assert.equal(
    validateOrderCreatePayload({ ...base, departureAt: now.toISOString() }, { now }).ok,
    false,
  );
  assert.equal(
    validateOrderCreatePayload({ ...base, passengerCount: 21 }, { now }).ok,
    false,
  );
  assert.equal(
    validateOrderCreatePayload({ ...base, hasLuggage: 'yes' }, { now }).ok,
    false,
  );
  assert.equal(
    validateOrderCreatePayload(
      {
        ...base,
        intercityComment: 'x'.repeat(orderValidationLimits.comment + 1),
      },
      { now },
    ).ok,
    false,
  );
});

test('valid city, delivery and intercity payloads remain accepted', async () => {
  const city = validCityPayload();
  const delivery = validCityPayload({
    serviceType: 'delivery',
    itemDescription: 'Небольшая посылка',
    senderName: 'Айжан',
    recipientName: 'Сергей',
    recipientPhone: '+77001234567',
    pickupHandoffType: 'door',
    destinationHandoffType: 'outside',
    pickupApartment: '15',
    destinationComment: 'Позвонить получателю',
  });
  const intercity = validCityPayload({
    serviceType: 'intercity',
    departureAt: '2099-08-26T08:30:00.000Z',
    passengerCount: 3,
    hasLuggage: true,
    comment: 'Детское кресло',
  });

  for (const payload of [city, delivery, intercity]) {
    const result = validateOrderCreatePayload(payload, { now });
    assert.equal(result.ok, true);
    if (payload.serviceType === 'intercity') {
      assert.equal(result.value.intercityComment, 'Детское кресло');
    }

    const response = await request(createValidOrderApp())
      .post('/api/orders')
      .send(payload);
    assert.equal(response.status, 201);
    assert.equal(response.body.serviceType, payload.serviceType);
    assert.equal(response.body.status, 'searching');
  }
});

test('stale city and delivery searching orders expire after two hours', () => {
  const createdAt = new Date(now.getTime() - cityOrderLifetimeMs - 1);
  for (const serviceType of ['city', 'delivery']) {
    assert.equal(
      isSearchingOrderExpired(
        { status: 'searching', serviceType, createdAt },
        { now },
      ),
      true,
    );
  }
});

test('future intercity does not expire because its record is old', () => {
  assert.equal(
    isSearchingOrderExpired(
      {
        status: 'searching',
        serviceType: 'intercity',
        createdAt: '2026-08-01T00:00:00.000Z',
        departureAt: '2026-08-26T08:00:00.000Z',
      },
      { now },
    ),
    false,
  );
});

test('intercity expires when its departure time has passed', () => {
  assert.equal(
    isSearchingOrderExpired(
      {
        status: 'searching',
        serviceType: 'intercity',
        departureAt: '2026-08-25T11:59:59.000Z',
      },
      { now },
    ),
    true,
  );
});

test('expiry cannot change an order that concurrent accept already accepted', async () => {
  assert.equal(
    isSearchingOrderExpired(
      {
        status: 'accepted',
        serviceType: 'city',
        createdAt: '2026-08-01T00:00:00.000Z',
      },
      { now },
    ),
    false,
  );

  let capturedSql = '';
  await expireStaleSearchingOrders(
    {
      async query(sql) {
        capturedSql = String(sql).replace(/\s+/g, ' ');
        return { rows: [] };
      },
    },
    { now },
  );
  assert.match(capturedSql, /o\.status = 'searching'/);
  assert.match(capturedSql, /SET status = 'expired'/);
});

function createVehicleApp(currentStatus, { currentCarModel = 'Toyota' } = {}) {
  let capturedSql = '';
  let queryCalls = 0;
  const pool = {
    async query(sql, params) {
      queryCalls++;
      capturedSql = String(sql).replace(/\s+/g, ' ').trim();
      assert.match(capturedSql, /car_model = \$1::varchar\(100\)/);
      assert.match(
        capturedSql,
        /dp\.car_model IS DISTINCT FROM \$1::varchar\(100\)/,
      );
      const changed = currentCarModel !== params[0];
      const nextStatus = currentStatus === 'active' && changed
        ? 'pending'
        : currentStatus;
      return {
        rows: [
          {
            user_id: 'driver-1',
            status: nextStatus,
            car_model: params[0],
            car_color: 'Белый',
            car_number: '123ABC01',
            agreement_version: '1.0',
            agreement_accepted_at: now,
            created_at: now,
            updated_at: now,
          },
        ],
      };
    },
  };
  const app = express();
  app.use(express.json());
  app.use(
    '/api/driver-profile',
    createDriverProfileRouter({ pool, requireAuth: fakeAuth }),
  );
  return {
    app,
    getSql: () => capturedSql,
    getQueryCalls: () => queryCalls,
  };
}

test('editing an active driver vehicle model returns profile to pending', async () => {
  const harness = createVehicleApp('active');
  const response = await request(harness.app)
    .patch('/api/driver-profile/vehicle-model')
    .send({ carModel: 'Toyota Camry' });

  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'pending');
  assert.match(harness.getSql(), /dp\.status = 'active'/);
  assert.match(harness.getSql(), /THEN 'pending'/);
});

test('editing an active driver with the same model keeps active status', async () => {
  const harness = createVehicleApp('active', {
    currentCarModel: 'Toyota Camry',
  });
  const response = await request(harness.app)
    .patch('/api/driver-profile/vehicle-model')
    .send({ carModel: 'Toyota Camry' });

  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'active');
  assert.equal(harness.getQueryCalls(), 1);
});

test('empty vehicle model is rejected before executing SQL', async () => {
  const harness = createVehicleApp('active');
  const response = await request(harness.app)
    .patch('/api/driver-profile/vehicle-model')
    .send({ carModel: '   ' });

  assert.equal(response.status, 400);
  assert.equal(harness.getQueryCalls(), 0);
});

test('invalid vehicle model type and excessive length are rejected before SQL', async () => {
  const harness = createVehicleApp('active');
  const invalidType = await request(harness.app)
    .patch('/api/driver-profile/vehicle-model')
    .send({ carModel: 123 });
  const tooLong = await request(harness.app)
    .patch('/api/driver-profile/vehicle-model')
    .send({ carModel: 'x'.repeat(101) });

  assert.equal(invalidType.status, 400);
  assert.equal(tooLong.status, 400);
  assert.equal(harness.getQueryCalls(), 0);
});

test('editing a suspended driver vehicle model does not unblock the profile', async () => {
  const harness = createVehicleApp('suspended');
  const response = await request(harness.app)
    .patch('/api/driver-profile/vehicle-model')
    .send({ carModel: 'Toyota Camry' });

  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'suspended');
  assert.match(harness.getSql(), /ELSE dp\.status/);
});

function createAcceptAppWithPostCommitFailure({
  failUidLookup = false,
  failWebSocket = false,
} = {}) {
  const client = {
    async query(sql) {
      const query = String(sql).replace(/\s+/g, ' ').trim();
      if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(query)) return { rows: [] };
      if (query.startsWith('SELECT pg_advisory_xact_lock')) {
        return { rows: [{}], rowCount: 1 };
      }
      if (query.startsWith('SELECT id, name, phone, account_status FROM users')) {
        return {
          rows: [{
            id: 'driver-1',
            name: 'Driver',
            phone: '+77000000000',
            account_status: 'active',
          }],
          rowCount: 1,
        };
      }
      if (query.startsWith('SELECT 1 FROM account_deletion_jobs')) {
        return { rows: [], rowCount: 0 };
      }
      if (query.includes('FROM users u') && query.includes('JOIN driver_profiles')) {
        return {
          rows: [
            {
              id: 'driver-1',
              name: 'Driver',
              phone: '+77000000000',
              rating: '5.00',
              status: 'active',
              access_exempt: true,
              subscription_active: false,
              car_model: 'Toyota',
              car_color: 'Белый',
              car_number: '123ABC01',
            },
          ],
        };
      }
      if (query.includes('FROM orders') && query.includes('FOR UPDATE')) {
        return {
          rows: [
            {
              id: 'order-1',
              passenger_id: 'passenger-1',
              driver_id: null,
              status: 'searching',
              passenger_price: 1_000,
            },
          ],
        };
      }
      if (query.includes('FROM orders') && query.includes('driver_id = $1')) {
        return { rows: [] };
      }
      if (query.startsWith('UPDATE orders')) {
        return {
          rows: [
            {
              id: 'order-1',
              passenger_id: 'passenger-1',
              driver_id: 'driver-1',
              status: 'accepted',
              passenger_price: 1_000,
              agreed_price: 1_000,
              accepted_at: now,
              created_at: now,
            },
          ],
        };
      }
      if (query.startsWith('UPDATE order_offers')) return { rows: [] };
      throw new Error(`Unexpected query: ${query}`);
    },
    release() {},
  };
  const pool = {
    async connect() {
      return client;
    },
    async query() {
      if (failUidLookup) {
        throw new Error('post-commit UID lookup failed');
      }
      return { rows: [{ firebase_uid: 'passenger-firebase' }] };
    },
  };
  const app = express();
  app.use(express.json());
  app.use(
    '/api/orders',
    createOrdersRouter({
      pool,
      requireAuth: fakeAuth,
      sendToUser: () => {
        if (failWebSocket) throw new Error('websocket failed');
      },
      sendToAvailableDrivers: () => {},
      sendPushToUser: async () => ({ successCount: 0, failureCount: 0 }),
    }),
  );
  return app;
}

test('post-commit UID lookup failure does not turn accepted order into HTTP 500', async (t) => {
  const originalConsoleError = console.error;
  console.error = () => {};
  t.after(() => {
    console.error = originalConsoleError;
  });

  const response = await request(
    createAcceptAppWithPostCommitFailure({ failUidLookup: true }),
  ).post('/api/orders/order-1/accept');

  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'accepted');
});

test('post-commit websocket failure does not turn accepted order into HTTP 500', async (t) => {
  const originalConsoleError = console.error;
  console.error = () => {};
  t.after(() => {
    console.error = originalConsoleError;
  });

  const response = await request(
    createAcceptAppWithPostCommitFailure({ failWebSocket: true }),
  ).post('/api/orders/order-1/accept');

  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'accepted');
});

test('post-update push failure does not turn arrive into HTTP 500', async (t) => {
  const originalConsoleError = console.error;
  console.error = () => {};
  t.after(() => {
    console.error = originalConsoleError;
  });

  const pool = {
    async query(sql) {
      const query = String(sql).replace(/\s+/g, ' ').trim();
      if (query.startsWith('UPDATE orders o')) {
        return {
          rows: [
            {
              id: 'order-1',
              status: 'driver_arrived',
              driver_arrived_at: now,
              passenger_uid: 'passenger-firebase',
            },
          ],
        };
      }
      if (query.includes('passenger.firebase_uid AS passenger_uid')) {
        return {
          rows: [
            {
              passenger_uid: 'passenger-firebase',
              driver_uid: 'firebase-user',
            },
          ],
        };
      }
      throw new Error(`Unexpected query: ${query}`);
    },
  };
  const app = express();
  app.use(express.json());
  app.use(
    '/api/orders',
    createOrdersRouter({
      pool,
      requireAuth: fakeAuth,
      sendToUser: () => {},
      sendToAvailableDrivers: () => {},
      sendPushToUser: async () => {
        throw new Error('FCM unavailable');
      },
    }),
  );

  const response = await request(app).post('/api/orders/order-1/arrive');
  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'driver_arrived');
});

test('active passenger order query has a valid SELECT list before FROM', async () => {
  let activeQueryCalls = 0;
  const pool = {
    async query(sql) {
      const query = String(sql).replace(/\s+/g, ' ').trim();
      if (query.startsWith('UPDATE orders o')) return { rows: [] };
      if (query.includes('FROM users u') && query.includes('JOIN orders o')) {
        activeQueryCalls++;
        assert.doesNotMatch(query, /,\s*FROM users u/i);
        assert.match(query, /dp\.car_number FROM users u/i);
        return {
          rows: [
            {
              id: 'order-1',
              passenger_id: 'passenger-1',
              driver_id: 'driver-1',
              current_user_id: 'passenger-1',
              status: 'in_progress',
              passenger_price: 1_000,
              agreed_price: 1_000,
              pickup_address: 'Pickup',
              destination_address: 'Destination',
              pickup_lat: 51.9,
              pickup_lng: 66.4,
              destination_lat: 52.0,
              destination_lng: 66.5,
              distance_meters: 1_000,
              driver_lat: 51.95,
              driver_lng: 66.45,
              driver_location_updated_at: now,
              driver_name: 'Driver',
              car_model: 'Toyota',
              car_color: 'Blue',
              car_number: '123 ABC',
            },
          ],
        };
      }
      throw new Error(`Unexpected query: ${query}`);
    },
  };
  const app = express();
  app.use(express.json());
  app.use(
    '/api/orders',
    createOrdersRouter({
      pool,
      requireAuth: fakeAuth,
      sendToUser: () => {},
      sendToAvailableDrivers: () => {},
      sendPushToUser: async () => ({ successCount: 0, failureCount: 0 }),
    }),
  );

  const response = await request(app).get('/api/orders/active/me');

  assert.equal(response.status, 200);
  assert.equal(activeQueryCalls, 1);
  assert.equal(response.body.activeOrder.role, 'passenger');
  assert.equal(response.body.activeOrder.status, 'in_progress');
  assert.equal(response.body.activeOrder.driverLat, 51.95);
});
