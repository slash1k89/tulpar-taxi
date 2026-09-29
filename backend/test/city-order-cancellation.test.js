import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';

import { createOrdersRouter } from '../src/routes/orders.js';
import { canCancelCityOrder, validateCityCancellationReason } from '../src/city-cancellation-policy.js';
import { localizedPushCopy } from '../src/push-copy.js';

function harness({ status = 'in_progress', caller = 'passenger', serviceType = 'city' } = {}) {
  const order = {
    id: 'order-id', passenger_id: 'passenger', driver_id: 'driver',
    status, service_type: serviceType, queued_after_order_id: null,
  };
  const state = { order, queries: [], pushes: [], messages: [], audit: null };
  state.stops = [{ sequence: 1, reached_at: new Date() }, { sequence: 2, reached_at: null }];
  const query = async (sql, values = []) => {
    const normalized = String(sql).replace(/\s+/g, ' ').trim();
    state.queries.push(normalized);
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(normalized)) return { rows: [] };
    if (normalized.startsWith('SELECT id FROM users WHERE')) return { rows: [{ id: caller }] };
    if (normalized.includes('FROM orders WHERE id = $1 FOR UPDATE')) return { rows: [order] };
    if (normalized.startsWith("UPDATE orders SET status = 'cancelled'")) {
      order.status = 'cancelled';
      state.audit = {
        userId: values[1], role: values[2], reasonCode: values[3], reasonText: values[4],
      };
      return { rows: [{ id: order.id, status: order.status, cancelled_at: new Date() }] };
    }
    if (normalized.startsWith('UPDATE order_offers')) return { rows: [] };
    if (normalized.includes('AS passenger_uid') && normalized.includes('AS driver_uid')) {
      return { rows: [{ passenger_uid: 'passenger-uid', driver_uid: 'driver-uid' }] };
    }
    if (normalized.startsWith('SELECT o.service_type,')) {
      return { rows: [{ service_type: serviceType, identity_key: caller === 'driver' ? 'passenger-uid' : 'driver-uid' }] };
    }
    throw new Error(`Unexpected query: ${normalized}`);
  };
  const client = { query, release() {} };
  const pool = { query, async connect() { return client; } };
  const app = express();
  app.use(express.json());
  app.use('/api/orders', createOrdersRouter({
    pool,
    requireAuth(req, _res, next) { req.user = { uid: 'firebase-uid' }; next(); },
    sendToUser(uid, payload) { state.messages.push({ uid, payload }); },
    sendToAvailableDrivers() {},
    async sendPushToUser(uid, payload) { state.pushes.push({ uid, payload }); },
  }));
  return { app, state };
}

for (const caller of ['passenger', 'driver']) {
  test(`${caller} can cancel started city ride with audit and one opposite push`, async () => {
    const { app, state } = harness({ caller });
    const reasonCode = caller === 'driver' ? 'car_breakdown' : 'plans_changed';
    const result = await request(app).post('/api/orders/order-id/cancel').send({ reasonCode });
    assert.equal(result.status, 200);
    assert.equal(state.order.status, 'cancelled');
    assert.deepEqual(state.audit, { userId: caller, role: caller, reasonCode, reasonText: null });
    assert.equal(state.pushes.length, 1);
    assert.equal(state.pushes[0].payload.data.cancelledBy, caller);
    const replay = await request(app).post('/api/orders/order-id/cancel').send({ reasonCode });
    assert.equal(replay.status, 200);
    assert.equal(replay.body.alreadyCancelled, true);
    assert.equal(state.pushes.length, 1);
    assert.ok(!state.queries.some((sql) => sql.includes('DELETE FROM order_messages')));
    assert.ok(!state.queries.some((sql) => sql.includes('DELETE FROM order_stops')));
    assert.equal(state.stops[0].reached_at instanceof Date, true);
    assert.equal(state.stops[1].reached_at, null);
  });
}

test('started ride requires reason and does not mutate on invalid reason', async () => {
  const { app, state } = harness();
  const response = await request(app).post('/api/orders/order-id/cancel');
  assert.equal(response.status, 400);
  assert.equal(response.body.error, 'cancellation_reason_required');
  assert.equal(state.order.status, 'in_progress');
  assert.equal(state.pushes.length, 0);
});

for (const status of ['completed', 'expired']) {
  test(`${status} city ride cannot be cancelled`, async () => {
    const { app, state } = harness({ status });
    const response = await request(app).post('/api/orders/order-id/cancel');
    assert.equal(response.status, 409);
    assert.equal(state.order.status, status);
  });
}

test('foreign caller cannot cancel', async () => {
  const { app, state } = harness({ caller: 'other' });
  const response = await request(app).post('/api/orders/order-id/cancel');
  assert.equal(response.status, 403);
  assert.equal(state.order.status, 'in_progress');
});

test('city status policy includes approach and arrived, not terminal statuses', () => {
  for (const status of ['accepted', 'driver_arriving', 'driver_arrived', 'in_progress']) {
    assert.equal(canCancelCityOrder(status, 'passenger'), true);
    assert.equal(canCancelCityOrder(status, 'driver'), true);
  }
  for (const status of ['completed', 'cancelled', 'expired']) {
    assert.equal(canCancelCityOrder(status, 'passenger'), false);
    assert.equal(canCancelCityOrder(status, 'driver'), false);
  }
  assert.equal(validateCityCancellationReason({ status: 'in_progress', role: 'driver', reasonCode: 'plans_changed' }).ok, false);
});

test('opposite participant gets localized city cancellation in ru kk en', () => {
  for (const locale of ['ru', 'kk', 'en']) {
    for (const cancelledBy of ['driver', 'passenger']) {
      const copy = localizedPushCopy({ eventType: 'cancelled', locale,
        data: { serviceType: 'city', cancelledBy } });
      assert.ok(copy.title.length > 0);
      assert.ok(copy.body.length > 0);
    }
  }
});
