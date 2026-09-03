import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import { createOrdersRouter } from '../src/routes/orders.js';

function harness({ queued = null, pushFails = false, activationFails = false } = {}) {
  const current = {
    id: 'current', driver_id: 'driver', service_type: 'city',
    status: 'in_progress', agreed_price: 1000, completed_at: null,
  };
  const defaultQueued = {
    id: 'next', driver_id: 'driver', service_type: 'city', status: 'queued',
    agreed_price: 1400, queued_after_order_id: 'current', accepted_at: null,
    passenger_uid: 'next-passenger-uid',
  };
  const state = {
    current,
    queued: queued === true ? defaultQueued : queued,
    events: [],
    queries: [],
    snapshot: null,
  };

  const execute = async (sql, values = []) => {
    const query = String(sql).replace(/\s+/g, ' ').trim();
    state.queries.push(query);
    if (query === 'BEGIN') {
      state.snapshot = {
        current: structuredClone(state.current),
        queued: state.queued == null ? null : structuredClone(state.queued),
      };
      return { rows: [] };
    }
    if (query === 'ROLLBACK') {
      if (state.snapshot) {
        Object.assign(state.current, state.snapshot.current);
        state.queued = state.snapshot.queued;
      }
      state.snapshot = null;
      state.events.push('rollback');
      return { rows: [] };
    }
    if (query === 'COMMIT') {
      state.snapshot = null;
      state.events.push('commit');
      return { rows: [] };
    }
    if (query.startsWith('SELECT pg_advisory_xact_lock')) return { rows: [{}] };
    if (query.startsWith('SELECT id, name, phone, account_status FROM users')) {
      return { rows: [{ id: 'driver', name: 'Driver', phone: '+70000000000', account_status: 'active' }], rowCount: 1 };
    }
    if (query.startsWith('SELECT id, driver_id, service_type, status, agreed_price')) {
      const matches = state.current.id === values[0]
        && state.current.driver_id === values[1]
        && state.current.status === 'in_progress';
      return { rows: matches ? [{ ...state.current }] : [] };
    }
    if (query.includes('next_order.queued_after_order_id = $1')) {
      const matches = state.queued?.queued_after_order_id === values[0];
      return { rows: matches ? [{ ...state.queued }] : [] };
    }
    if (query.startsWith("UPDATE orders SET status = 'completed'")) {
      if (state.current.id !== values[0] || state.current.status !== 'in_progress') return { rows: [] };
      Object.assign(state.current, { status: 'completed', completed_at: new Date() });
      return { rows: [{ ...state.current }] };
    }
    if (query.startsWith("UPDATE orders SET status = 'accepted'")) {
      if (activationFails) return { rows: [] };
      const matches = state.queued
        && state.queued.id === values[0]
        && state.queued.driver_id === values[1]
        && state.queued.status === 'queued'
        && state.queued.queued_after_order_id === values[2];
      if (!matches) return { rows: [] };
      Object.assign(state.queued, {
        status: 'accepted', accepted_at: new Date(), queued_after_order_id: null,
      });
      return { rows: [{ ...state.queued }] };
    }
    if (
      query.includes('AS passenger_uid') &&
      query.includes('AS driver_uid') &&
      query.includes('FROM orders o')
    ) {
      return { rows: [{ passenger_uid: 'passenger-uid', driver_uid: 'driver-uid' }] };
    }
    throw new Error(`Unexpected query: ${query}`);
  };

  const client = { query: execute, release() {} };
  const pool = { query: execute, async connect() { return client; } };
  const app = express();
  app.use(express.json());
  app.use('/api/orders', createOrdersRouter({
    pool,
    requireAuth(req, _res, next) { req.user = { uid: 'driver-uid' }; next(); },
    sendToUser(uid, payload) { state.events.push(`realtime:${uid}:${payload.status}`); },
    sendToAvailableDrivers() {},
    async sendPushToUser(uid, payload) {
      state.events.push(`push:${uid}:${payload.data.type}`);
      if (pushFails) throw new Error('FCM unavailable');
      return { successCount: 1, failureCount: 0 };
    },
  }));
  return { app, state };
}

test('complete without queued preserves normal completion and side effects', async () => {
  const { app, state } = harness();
  const response = await request(app).post('/api/orders/current/complete');
  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'completed');
  assert.equal(response.body.nextOrderActivated, false);
  assert.equal(response.body.nextOrderId, null);
  assert.ok(state.current.completed_at instanceof Date);
  assert.ok(state.events.some((event) => event.endsWith(':completed')));
});

test('linked queued activates atomically and preserves driver and price', async () => {
  const { app, state } = harness({ queued: true });
  const response = await request(app).post('/api/orders/current/complete');
  assert.equal(response.status, 200);
  assert.equal(response.body.nextOrderActivated, true);
  assert.equal(response.body.nextOrderId, 'next');
  assert.equal(state.current.status, 'completed');
  assert.equal(state.queued.status, 'accepted');
  assert.equal(state.queued.driver_id, 'driver');
  assert.equal(state.queued.agreed_price, 1400);
  assert.equal(state.queued.queued_after_order_id, null);
  assert.ok(state.queued.accepted_at instanceof Date);
});

test('unlinked queued is not activated', async () => {
  const { app, state } = harness({ queued: { ...harness({ queued: true }).state.queued, queued_after_order_id: 'other-current' } });
  const response = await request(app).post('/api/orders/current/complete');
  assert.equal(response.status, 200);
  assert.equal(response.body.nextOrderActivated, false);
  assert.equal(state.queued.status, 'queued');
});

test('queued cancelled before complete is not activated', async () => {
  const cancelled = {
    ...harness({ queued: true }).state.queued,
    status: 'cancelled',
    queued_after_order_id: null,
  };
  const { app, state } = harness({ queued: cancelled });
  const response = await request(app).post('/api/orders/current/complete');
  assert.equal(response.status, 200);
  assert.equal(response.body.nextOrderActivated, false);
  assert.equal(response.body.nextOrderId, null);
  assert.equal(state.current.status, 'completed');
  assert.equal(state.queued.status, 'cancelled');
});

test('linked queued for another driver is invalid and rolls back', async () => {
  const { app, state } = harness({ queued: { ...harness({ queued: true }).state.queued, driver_id: 'other-driver' } });
  const response = await request(app).post('/api/orders/current/complete');
  assert.equal(response.status, 409);
  assert.equal(state.current.status, 'in_progress');
  assert.equal(state.queued.status, 'queued');
});

test('activation failure rolls back completed current without partial state', async () => {
  const { app, state } = harness({ queued: true, activationFails: true });
  const response = await request(app).post('/api/orders/current/complete');
  assert.equal(response.status, 409);
  assert.equal(state.current.status, 'in_progress');
  assert.equal(state.queued.status, 'queued');
});

test('repeat complete does not activate or push again', async () => {
  const { app, state } = harness({ queued: true });
  assert.equal((await request(app).post('/api/orders/current/complete')).status, 200);
  const pushCount = state.events.filter((event) => event.startsWith('push:')).length;
  assert.equal((await request(app).post('/api/orders/current/complete')).status, 409);
  assert.equal(state.events.filter((event) => event.startsWith('push:')).length, pushCount);
});

test('next event and push happen only after commit', async () => {
  const { app, state } = harness({ queued: true });
  await request(app).post('/api/orders/current/complete');
  const commit = state.events.indexOf('commit');
  const acceptedEvent = state.events.findIndex((event) => event.endsWith(':accepted'));
  const push = state.events.findIndex((event) => event.startsWith('push:'));
  assert.ok(commit >= 0 && acceptedEvent > commit && push > commit);
});

test('FCM failure after commit leaves current completed and next accepted', async () => {
  const { app, state } = harness({ queued: true, pushFails: true });
  const response = await request(app).post('/api/orders/current/complete');
  assert.equal(response.status, 200);
  assert.equal(state.current.status, 'completed');
  assert.equal(state.queued.status, 'accepted');
});

test('transaction uses lifecycle, current and linked queued locks in order', async () => {
  const { app, state } = harness({ queued: true });
  await request(app).post('/api/orders/current/complete');
  const lifecycle = state.queries.findIndex((query) => query.startsWith('SELECT pg_advisory_xact_lock'));
  const current = state.queries.findIndex((query) => query.startsWith('SELECT id, driver_id, service_type'));
  const queued = state.queries.findIndex((query) => query.includes('FOR UPDATE OF next_order'));
  assert.ok(lifecycle >= 0 && current > lifecycle && queued > current);
});
