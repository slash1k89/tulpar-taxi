import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import { createOrdersRouter, nextOrderDistanceMeters } from '../src/routes/orders.js';

const north = (meters) => meters / 111194.9266;

function harness({ current = true, distance = 200 } = {}) {
  const startedAt = new Date('2026-08-30T10:00:00Z');
  const state = {
    current: current ? {
      id: 'current',
      status: 'in_progress',
      service_type: 'city',
      destination_lat: 0,
      destination_lng: 0,
      started_at: startedAt,
      completed_at: null,
    } : null,
    queued: null,
    targets: new Map(),
    offers: new Map(),
    queries: [],
  };
  state.targets.set('target', {
    id: 'target', passenger_id: 'passenger', passenger_firebase_uid: 'passenger-uid',
    passenger_price: 1000, status: 'searching', driver_id: null,
    service_type: 'city', pickup_lat: north(distance), pickup_lng: 0,
  });

  const execute = async (sql, values = []) => {
    const query = String(sql).replace(/\s+/g, ' ').trim();
    state.queries.push(query);
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(query)) return { rows: [], rowCount: 0 };
    if (query.startsWith('SELECT pg_advisory_xact_lock')) return { rows: [{}], rowCount: 1 };
    if (query.startsWith('SELECT id, name, phone, account_status FROM users')) {
      return { rows: [{ id: 'driver', name: 'Driver', phone: '+70000000000', account_status: 'active' }], rowCount: 1 };
    }
    if (query.includes('FROM users u JOIN driver_profiles dp') && query.includes('u.firebase_uid = $1')) {
      return { rows: [{ id: 'driver', status: 'active', access_exempt: true, subscription_active: false }] };
    }
    if (query.includes('AS passenger_firebase_uid')) {
      const target = state.targets.get(values[0]);
      return { rows: target ? [{ ...target }] : [] };
    }
    if (query.startsWith('SELECT id, service_type, status, destination_lat')) {
      return { rows: state.current && ['accepted', 'driver_arrived', 'in_progress'].includes(state.current.status) ? [{ ...state.current }] : [] };
    }
    if (query.startsWith('SELECT id FROM orders') && query.includes("status = 'queued'")) {
      return { rows: state.queued ? [{ id: state.queued.id }] : [] };
    }
    if (query.startsWith('INSERT INTO order_offers')) {
      const [orderId, driverId, price] = values;
      const existing = [...state.offers.values()].find((offer) => offer.order_id === orderId && offer.driver_id === driverId);
      const offer = existing ?? { id: `offer-${orderId}`, order_id: orderId, driver_id: driverId, created_at: new Date() };
      Object.assign(offer, { price, status: 'pending', updated_at: new Date(startedAt.getTime() + 10_000) });
      state.offers.set(offer.id, offer);
      return { rows: [{ ...offer }] };
    }
    if (query.startsWith('SELECT o.id FROM orders o JOIN users u')) {
      const target = state.targets.get(values[0]);
      return { rows: target && values[1] === 'passenger-uid' ? [{ id: target.id }] : [] };
    }
    if (
      query.startsWith('SELECT oo.driver_id,') &&
      query.includes('AS driver_firebase_uid')
    ) {
      const offer = state.offers.get(values[0]);
      return { rows: offer ? [{ driver_id: offer.driver_id, driver_firebase_uid: 'driver-uid' }] : [] };
    }
    if (query === 'SELECT id FROM users WHERE id = $1 FOR UPDATE') return { rows: [{ id: 'driver' }] };
    if (query.startsWith('SELECT o.id, o.passenger_id, o.driver_id, o.status')) {
      const target = state.targets.get(values[0]);
      return { rows: target && values[1] === 'passenger-uid' ? [{ ...target }] : [] };
    }
    if (query.includes('oo.updated_at') && query.includes('FROM order_offers oo')) {
      const offer = state.offers.get(values[0]);
      return { rows: offer ? [{
        ...offer,
        driver_name: 'Driver', driver_phone: '+70000000000', driver_rating: 5,
        driver_profile_status: 'active', access_exempt: true,
        subscription_active: false, car_model: 'Car', car_color: 'Blue', car_number: 'A1',
      }] : [] };
    }
    if (query.startsWith('SELECT id, status, destination_lat, destination_lng')) {
      const offerTime = new Date(values[1]);
      const currentOrder = state.current;
      const containsOfferTime = currentOrder
        && currentOrder.started_at <= offerTime
        && (currentOrder.completed_at == null || currentOrder.completed_at >= offerTime);
      return { rows: containsOfferTime ? [{ ...currentOrder }] : [] };
    }
    if (query.startsWith('SELECT id FROM orders') && query.includes("status IN ('accepted', 'driver_arrived', 'in_progress')")) {
      return { rows: state.current && state.current.status === 'in_progress' ? [{ id: state.current.id }] : [] };
    }
    if (query.startsWith('UPDATE orders SET driver_id = $1, status = \'queued\'')) {
      const [driverId, price, currentId, targetId] = values;
      const target = state.targets.get(targetId);
      if (!target || target.status !== 'searching' || target.driver_id != null) return { rows: [] };
      Object.assign(target, { driver_id: driverId, status: 'queued', agreed_price: price, queued_after_order_id: currentId });
      state.queued = target;
      return { rows: [{ ...target, agreed_price: price, queued_after_order_id: currentId }] };
    }
    if (query.startsWith('UPDATE orders SET driver_id = $1, status = \'accepted\'')) {
      const [driverId, price, targetId] = values;
      const target = state.targets.get(targetId);
      if (!target || target.status !== 'searching' || target.driver_id != null) return { rows: [] };
      Object.assign(target, { driver_id: driverId, status: 'accepted', agreed_price: price, accepted_at: new Date(), queued_after_order_id: null });
      return { rows: [{ ...target, agreed_price: price }] };
    }
    if (query.startsWith('UPDATE order_offers SET status = CASE')) {
      for (const offer of state.offers.values()) {
        if (offer.order_id === values[1] && offer.status === 'pending') offer.status = offer.id === values[0] ? 'accepted' : 'rejected';
      }
      return { rows: [] };
    }
    throw new Error(`Unexpected query: ${query}`);
  };

  const pool = { query: execute, async connect() { return { query: execute, release() {} }; } };
  const app = express();
  app.use(express.json());
  app.use('/api/orders', createOrdersRouter({
    pool,
    requireAuth(req, _res, next) { req.user = { uid: req.get('x-uid') ?? 'driver-uid' }; next(); },
    sendToUser() {}, sendToAvailableDrivers() {}, async sendPushToUser() {},
  }));
  return { app, state };
}

async function createOffer(app, orderId = 'target', price = 1300) {
  return request(app).post(`/api/orders/${orderId}/offers`).set('x-uid', 'driver-uid').send({ price });
}

async function acceptOffer(app, orderId = 'target', offerId = `offer-${orderId}`, uid = 'passenger-uid') {
  return request(app).post(`/api/orders/${orderId}/offers/${offerId}/accept`).set('x-uid', uid);
}

test('valid next candidate creates pending offer without changing current', async () => {
  const { app, state } = harness({ distance: 250 });
  const response = await createOffer(app);
  assert.equal(response.status, 201);
  assert.equal(response.body.status, 'pending');
  assert.equal(state.current.status, 'in_progress');
  assert.equal(state.targets.get('target').status, 'searching');
});

test('next offer beyond 300m is rejected using current destination to target pickup', async () => {
  const { app, state } = harness({ distance: 301 });
  const response = await createOffer(app);
  assert.equal(response.status, 409);
  assert.equal(state.offers.size, 0);
  assert.ok(nextOrderDistanceMeters({ currentDestinationLat: 0, currentDestinationLng: 0, newPickupLat: state.targets.get('target').pickup_lat, newPickupLng: 0 }) > 300);
});

test('passenger accepts valid next offer into queued at offer price', async () => {
  const { app, state } = harness({ distance: 200 });
  await createOffer(app, 'target', 1400);
  const response = await acceptOffer(app);
  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'queued');
  assert.equal(response.body.agreedPrice, 1400);
  assert.equal(response.body.queuedAfterOrderId, 'current');
  assert.equal(state.current.status, 'in_progress');
});

test('stale next offer is rejected after queued acquisition or current completion', async () => {
  for (const stale of ['queued', 'completed']) {
    const { app, state } = harness();
    await createOffer(app);
    if (stale === 'queued') state.queued = { id: 'other-queued' };
    if (stale === 'completed') {
      state.current.status = 'completed';
      state.current.completed_at = new Date('2026-08-30T10:01:00Z');
    }
    assert.equal((await acceptOffer(app)).status, 409);
    assert.equal(state.targets.get('target').status, 'searching');
  }
});

test('at most one of two next offers for one driver becomes queued', async () => {
  const { app, state } = harness();
  state.targets.set('second', { ...state.targets.get('target'), id: 'second', passenger_id: 'passenger-2' });
  await createOffer(app, 'target', 1300);
  await createOffer(app, 'second', 1350);
  assert.equal((await acceptOffer(app, 'target')).status, 200);
  assert.equal((await acceptOffer(app, 'second')).status, 409);
  assert.equal([...state.targets.values()].filter((order) => order.status === 'queued').length, 1);
});

test('occupied target loses normal-accept race without corrupted state', async () => {
  const { app, state } = harness();
  await createOffer(app);
  Object.assign(state.targets.get('target'), { status: 'accepted', driver_id: 'other-driver' });
  assert.equal((await acceptOffer(app)).status, 409);
  assert.equal(state.targets.get('target').driver_id, 'other-driver');
});

test('normal free-driver offer remains normal accepted order', async () => {
  const { app, state } = harness({ current: false });
  assert.equal((await createOffer(app)).status, 201);
  const response = await acceptOffer(app);
  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'accepted');
  assert.equal(response.body.queuedAfterOrderId, null);
  assert.equal(state.targets.get('target').status, 'accepted');
});

test('unauthorized passenger cannot accept another passenger offer', async () => {
  const { app, state } = harness();
  await createOffer(app);
  assert.equal((await acceptOffer(app, 'target', 'offer-target', 'attacker-uid')).status, 403);
  assert.equal(state.targets.get('target').status, 'searching');
});
