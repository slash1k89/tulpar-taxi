import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import { createOrdersRouter } from '../src/routes/orders.js';

function harness({ userId = 'passenger', status = 'queued' } = {}) {
  const state = {
    current: { id: 'current', status: 'in_progress' },
    order: {
      id: 'next',
      passenger_id: 'passenger',
      driver_id: 'driver',
      status,
      queued_after_order_id: status === 'queued' ? 'current' : null,
      cancelled_at: null,
    },
    offerStatus: 'pending',
    queries: [],
    pushes: [],
  };

  const execute = async (sql, values = []) => {
    const query = String(sql).replace(/\s+/g, ' ').trim();
    state.queries.push(query);
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(query)) return { rows: [] };
    if (query.startsWith('SELECT id FROM users WHERE (firebase_uid')) {
      return { rows: [{ id: userId }] };
    }
    if (query.startsWith('SELECT id, passenger_id, driver_id, status,')) {
      assert.match(query, /queued_after_order_id FROM orders/);
      assert.match(query, /FOR UPDATE/);
      return { rows: [{ ...state.order }] };
    }
    if (query.startsWith("UPDATE orders SET status = 'cancelled'")) {
      assert.match(query, /queued_after_order_id = NULL/);
      state.order.status = 'cancelled';
      state.order.queued_after_order_id = null;
      state.order.cancelled_at = new Date();
      return { rows: [{ ...state.order }] };
    }
    if (query.startsWith('UPDATE order_offers')) {
      if (state.offerStatus === 'pending') state.offerStatus = 'rejected';
      return { rows: [] };
    }
    if (query.includes('AS passenger_uid') && query.includes('AS driver_uid')) {
      return {
        rows: [{ passenger_uid: 'passenger-uid', driver_uid: 'driver-uid' }],
      };
    }
    if (query.startsWith('SELECT o.service_type,') && query.includes('JOIN users u ON u.id = o.driver_id')) {
      return { rows: [{ service_type: 'city', identity_key: 'driver-uid' }] };
    }
    throw new Error(`Unexpected query: ${query} ${values}`);
  };

  const client = { query: execute, release() {} };
  const pool = { query: execute, async connect() { return client; } };
  const app = express();
  app.use(express.json());
  app.use('/api/orders', createOrdersRouter({
    pool,
    requireAuth(req, _res, next) { req.user = { uid: 'firebase-user' }; next(); },
    sendToUser() {},
    sendToAvailableDrivers() {},
    async sendPushToUser(uid, payload) {
      assert.ok(state.queries.includes('COMMIT'));
      state.pushes.push({ uid, payload });
      return { successCount: 1, failureCount: 0 };
    },
  }));
  return { app, state };
}

test('owner passenger cancels only queued order and clears queued link', async () => {
  const { app, state } = harness();
  const response = await request(app).post('/api/orders/next/cancel');
  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'cancelled');
  assert.equal(state.order.status, 'cancelled');
  assert.equal(state.order.queued_after_order_id, null);
  assert.equal(state.current.status, 'in_progress');
  assert.equal(state.offerStatus, 'rejected');
  assert.deepEqual(state.pushes, [{
    uid: 'driver-uid',
    payload: { data: { type: 'cancelled', orderId: 'next', serviceType: 'city' } },
  }]);
  const replay = await request(app).post('/api/orders/next/cancel');
  assert.equal(replay.status, 409);
  assert.equal(state.pushes.length, 1);
});

test('another passenger cannot cancel queued order', async () => {
  const { app, state } = harness({ userId: 'other-passenger' });
  const response = await request(app).post('/api/orders/next/cancel');
  assert.equal(response.status, 403);
  assert.equal(state.order.status, 'queued');
  assert.equal(state.current.status, 'in_progress');
  assert.equal(state.pushes.length, 0);
});

test('driver cannot use passenger queued cancellation branch', async () => {
  const { app, state } = harness({ userId: 'driver' });
  const response = await request(app).post('/api/orders/next/cancel');
  assert.equal(response.status, 409);
  assert.equal(state.order.status, 'queued');
});

test('activation winning first uses existing accepted cancellation rule', async () => {
  const { app, state } = harness({ status: 'accepted' });
  const response = await request(app).post('/api/orders/next/cancel');
  assert.equal(response.status, 200);
  assert.equal(state.order.status, 'cancelled');
  assert.equal(state.order.queued_after_order_id, null);
});

test('terminal order remains non-cancellable', async () => {
  const { app, state } = harness({ status: 'completed' });
  const response = await request(app).post('/api/orders/next/cancel');
  assert.equal(response.status, 409);
  assert.equal(state.order.status, 'completed');
});
