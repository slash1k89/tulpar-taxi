import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import {
  createOrdersRouter,
  nextOrderDistanceMeters,
  nextOrderMaximumDistanceMeters,
} from '../src/routes/orders.js';

const pointAtMetersNorth = (meters) => meters / 111194.9266;

function createHarness({ current = true, queued = false, orders = [] } = {}) {
  const state = {
    current: current ? {
      id: 'current-order',
      status: 'in_progress',
      service_type: 'city',
      destination_lat: 0,
      destination_lng: 0,
    } : null,
    queuedOrder: queued ? { id: 'existing-queued' } : null,
    orders: new Map(orders.map((order) => [order.id, { ...order }])),
    queries: [],
  };

  const execute = async (sql, values = []) => {
    const query = String(sql).replace(/\s+/g, ' ').trim();
    state.queries.push(query);
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(query)) return { rows: [], rowCount: 0 };
    if (query.startsWith('SELECT pg_advisory_xact_lock')) return { rows: [{}], rowCount: 1 };
    if (query.startsWith('SELECT id, name, phone, account_status FROM users')) {
      return { rows: [{ id: 'driver-1', name: 'Driver', phone: '+70000000000', account_status: 'active' }], rowCount: 1 };
    }
    if (query.startsWith('UPDATE orders o SET status = \'expired\'')) return { rows: [], rowCount: 0 };
    if (query.includes('current_order.id AS current_order_id')) {
      return {
        rows: [{
          driver_id: 'driver-1',
          driver_profile_status: 'active',
          access_exempt: true,
          subscription_active: false,
          current_order_id: state.current?.id ?? null,
          destination_lat: state.current?.destination_lat ?? null,
          destination_lng: state.current?.destination_lng ?? null,
          has_queued_order: state.queuedOrder !== null,
        }],
      };
    }
    if (query.includes('AS distance_to_current_destination_meters')) {
      assert.match(query, /candidate\.pickup_lat - \$1/);
      assert.match(query, /candidate\.pickup_lng - \$2/);
      assert.doesNotMatch(query, /driver_lat|driver_lng/);
      const [destinationLat, destinationLng, driverId, maximum] = values;
      const rows = [...state.orders.values()]
        .filter((order) => order.service_type === 'city')
        .filter((order) => order.status === 'searching' && order.driver_id == null)
        .filter((order) => order.passenger_id !== driverId)
        .map((order) => ({
          ...order,
          distance_to_current_destination_meters: Math.round(nextOrderDistanceMeters({
            currentDestinationLat: destinationLat,
            currentDestinationLng: destinationLng,
            newPickupLat: order.pickup_lat,
            newPickupLng: order.pickup_lng,
          })),
        }))
        .filter((order) => order.distance_to_current_destination_meters <= maximum);
      return { rows };
    }
    if (query.includes('FROM users u JOIN driver_profiles dp') && query.includes('FOR UPDATE OF u')) {
      return { rows: [{ id: 'driver-1', status: 'active', access_exempt: true, subscription_active: false }], rowCount: 1 };
    }
    if (query.startsWith('SELECT id, destination_lat, destination_lng FROM orders')) {
      return { rows: state.current ? [{ ...state.current }] : [], rowCount: state.current ? 1 : 0 };
    }
    if (query.startsWith('SELECT id FROM orders') && query.includes("status = 'queued'")) {
      return { rows: state.queuedOrder ? [state.queuedOrder] : [], rowCount: state.queuedOrder ? 1 : 0 };
    }
    if (query.startsWith('SELECT id, passenger_id, driver_id, status, service_type')) {
      const order = state.orders.get(values[0]);
      return { rows: order ? [{ ...order }] : [], rowCount: order ? 1 : 0 };
    }
    if (query.startsWith('UPDATE orders SET driver_id = $1')) {
      assert.match(query, /status = 'searching'/);
      assert.match(query, /driver_id IS NULL/);
      const [driverId, currentId, orderId] = values;
      const order = state.orders.get(orderId);
      if (!order || order.status !== 'searching' || order.driver_id != null) return { rows: [], rowCount: 0 };
      Object.assign(order, {
        driver_id: driverId,
        status: 'queued',
        agreed_price: order.passenger_price,
        queued_after_order_id: currentId,
      });
      state.queuedOrder = order;
      return {
        rows: [{
          id: order.id,
          status: order.status,
          driver_id: order.driver_id,
          queued_after_order_id: order.queued_after_order_id,
          passenger_price: order.passenger_price,
          agreed_price: order.agreed_price,
        }],
        rowCount: 1,
      };
    }
    throw new Error(`Unexpected query: ${query}`);
  };

  const client = { query: execute, release() {} };
  const pool = { query: execute, async connect() { return client; } };
  const app = express();
  app.use(express.json());
  app.use('/api/orders', createOrdersRouter({
    pool,
    requireAuth(req, _res, next) { req.user = { uid: 'firebase-driver' }; next(); },
    sendToUser() {},
    sendToAvailableDrivers() {},
    async sendPushToUser() { return { successCount: 0, failureCount: 0 }; },
  }));
  return { app, state };
}

function orderAt(id, meters, serviceType = 'city') {
  return {
    id,
    passenger_id: `passenger-${id}`,
    driver_id: null,
    status: 'searching',
    service_type: serviceType,
    passenger_price: 1500,
    pickup_address: `Pickup ${id}`,
    destination_address: `Destination ${id}`,
    pickup_lat: pointAtMetersNorth(meters),
    pickup_lng: 0,
  };
}

test('250m CITY is candidate; 301m and non-CITY orders are excluded', async () => {
  const { app } = createHarness({ orders: [
    orderAt('near', 250),
    orderAt('far', 301),
    orderAt('delivery', 100, 'delivery'),
    orderAt('intercity', 100, 'intercity'),
  ] });
  const response = await request(app).get('/api/orders/next-candidates');
  assert.equal(response.status, 200);
  assert.deepEqual(response.body.map((item) => item.id), ['near']);
  assert.ok(response.body[0].distanceToCurrentDestinationMeters <= 300);
});

test('distance policy uses current destination and new pickup exactly', () => {
  assert.ok(nextOrderDistanceMeters({
    currentDestinationLat: 0,
    currentDestinationLng: 0,
    newPickupLat: pointAtMetersNorth(250),
    newPickupLng: 0,
  }) <= nextOrderMaximumDistanceMeters);
  assert.ok(nextOrderDistanceMeters({
    currentDestinationLat: 10,
    currentDestinationLng: 10,
    newPickupLat: 0,
    newPickupLng: 0,
  }) > nextOrderMaximumDistanceMeters);
});

test('driver without in-progress CITY or with queued order receives no candidates', async () => {
  for (const setup of [{ current: false }, { queued: true }]) {
    const { app } = createHarness({ ...setup, orders: [orderAt('near', 100)] });
    const response = await request(app).get('/api/orders/next-candidates');
    assert.equal(response.status, 200);
    assert.deepEqual(response.body, []);
  }
});

test('valid direct accept queues new order and leaves current unchanged', async () => {
  const { app, state } = createHarness({ orders: [orderAt('near', 250)] });
  const response = await request(app).post('/api/orders/near/accept-next');
  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'queued');
  assert.equal(response.body.driverId, 'driver-1');
  assert.equal(response.body.queuedAfterOrderId, 'current-order');
  assert.equal(response.body.agreedPrice, 1500);
  assert.equal(state.current.status, 'in_progress');
  assert.ok(state.queries.some((query) => query.includes('FOR UPDATE OF u')));
  assert.ok(state.queries.filter((query) => query.includes('FOR UPDATE')).length >= 4);
});

test('accept beyond 300m is rejected and order remains searching', async () => {
  const { app, state } = createHarness({ orders: [orderAt('far', 301)] });
  const response = await request(app).post('/api/orders/far/accept-next');
  assert.equal(response.status, 409);
  assert.equal(state.orders.get('far').status, 'searching');
});

test('second sequential next accept is rejected', async () => {
  const { app, state } = createHarness({ orders: [orderAt('first', 100), orderAt('second', 120)] });
  assert.equal((await request(app).post('/api/orders/first/accept-next')).status, 200);
  assert.equal((await request(app).post('/api/orders/second/accept-next')).status, 409);
  assert.equal(state.orders.get('second').status, 'searching');
});

test('already occupied new order is rejected', async () => {
  const occupied = { ...orderAt('occupied', 100), status: 'accepted', driver_id: 'other-driver' };
  const { app, state } = createHarness({ orders: [occupied] });
  const response = await request(app).post('/api/orders/occupied/accept-next');
  assert.equal(response.status, 409);
  assert.equal(state.orders.get('occupied').driver_id, 'other-driver');
});
