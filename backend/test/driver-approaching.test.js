import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import { createOrdersRouter } from '../src/routes/orders.js';

function distanceMeters(lat, lng, pickupLat = 0, pickupLng = 0) {
  const radians = (value) => value * Math.PI / 180;
  const dLat = radians(lat - pickupLat);
  const dLng = radians(lng - pickupLng);
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(radians(pickupLat)) * Math.cos(radians(lat))
    * Math.sin(dLng / 2) ** 2;
  return 6371000 * 2 * Math.asin(Math.sqrt(a));
}

function appFor({
  status = 'accepted',
  authenticatedDriver = 'driver',
  pushResults = [{ successCount: 1, failureCount: 0 }],
  initialClaim = null,
  claimExpired = false,
} = {}) {
  const state = {
    status,
    notified: false,
    claim: initialClaim,
    claimExpired,
    pushes: [],
    realtime: [],
    passengerUid: 'passenger-current-order',
  };
  const pool = {
    async query(sql, values = []) {
      const query = String(sql).replace(/\s+/g, ' ').trim();
      if (query.startsWith('UPDATE orders o SET status = \'driver_arrived\'')) {
        if (state.status !== 'accepted' || values[1] !== 'driver') return { rows: [] };
        state.status = 'driver_arrived';
        return { rows: [{
          id: values[0], status: state.status,
          driver_arrived_at: new Date(), passenger_uid: state.passengerUid,
        }] };
      }
      if (query.startsWith('WITH eligible AS')) {
        assert.match(query, /o\.pickup_lat/);
        assert.match(query, /o\.pickup_lng/);
        assert.doesNotMatch(query, /destination_lat|destination_lng/);
        assert.match(query, /AS was_already_notified/);
        assert.match(query, /FOR UPDATE OF o/);
        assert.match(query, /\) <= 200/);
        assert.match(query, /driver_approaching_claimed_at < now\(\) - interval '5 minutes'/);
        assert.doesNotMatch(query, /driver_approaching_notified_at =/);
        if (!['accepted', 'driver_arrived', 'in_progress'].includes(state.status)) {
          return { rows: [] };
        }
        const [lat, lng] = values;
        if (values[3] !== 'driver') return { rows: [] };
        const distance = distanceMeters(lat, lng);
        const wasAlreadyNotified = state.notified;
        const shouldNotify = state.status === 'accepted'
          && !state.notified
          && (!state.claim || state.claimExpired)
          && distance <= 200;
        if (shouldNotify) {
          state.claim = values[4];
          state.claimExpired = false;
        }
        return {
          rows: [{
            id: 'order-current',
            driver_lat: lat,
            driver_lng: lng,
            driver_location_updated_at: new Date(),
            passenger_uid: state.passengerUid,
            should_notify_approaching: shouldNotify,
            distance_to_pickup_meters: distance,
            was_already_notified: wasAlreadyNotified,
          }],
        };
      }
      if (query.startsWith('UPDATE orders SET driver_approaching_notified_at = now()')) {
        assert.match(query, /driver_approaching_claim_id = \$2::uuid/);
        if (state.claim !== values[1]) return { rowCount: 0, rows: [] };
        state.notified = true;
        state.claim = null;
        return { rowCount: 1, rows: [] };
      }
      if (query.startsWith('UPDATE orders SET driver_approaching_claim_id = NULL')) {
        assert.match(query, /driver_approaching_claim_id = \$2::uuid/);
        if (state.claim !== values[1]) return { rowCount: 0, rows: [] };
        state.claim = null;
        return { rowCount: 1, rows: [] };
      }
      if (query.includes('SELECT COALESCE(passenger.firebase_uid')) {
        return {
          rows: [{ passenger_uid: state.passengerUid, driver_uid: 'driver' }],
        };
      }
      throw new Error(`Unexpected query: ${query}`);
    },
  };
  const app = express();
  app.use(express.json());
  app.use('/api/orders', createOrdersRouter({
    pool,
    requireAuth(req, _res, next) {
      req.user = { uid: authenticatedDriver };
      next();
    },
    sendToUser(uid, payload) {
      state.realtime.push({ uid, payload });
    },
    sendToAvailableDrivers() {},
    async sendPushToUser(uid, payload) {
      state.pushes.push({ uid, payload });
      const result = pushResults.shift() ?? { successCount: 1, failureCount: 0 };
      if (result instanceof Error) throw result;
      return typeof result === 'function' ? result() : result;
    },
  }));
  return { app, state };
}

async function location(app, meters) {
  const lat = meters / 111194.9266;
  return request(app)
    .post('/api/orders/order-current/location')
    .send({ lat, lng: 0 });
}

test('claim migration keeps temporary reservations separate from delivery dedup', () => {
  const sql = fs.readFileSync(new URL(
    '../migrations/20260903_013_driver_approaching_claim.sql', import.meta.url,
  ), 'utf8');
  assert.match(sql, /ADD COLUMN IF NOT EXISTS driver_approaching_claim_id uuid/);
  assert.match(sql, /ADD COLUMN IF NOT EXISTS driver_approaching_claimed_at timestamptz/);
  assert.doesNotMatch(sql, /driver_approaching_notified_at/);
});

test('250m does not notify; first <=200m sample notifies current passenger', async () => {
  const { app, state } = appFor();
  assert.equal((await location(app, 250)).status, 200);
  assert.equal(state.pushes.length, 0);
  assert.equal((await location(app, 198)).status, 200);
  assert.equal(state.pushes.length, 1);
  assert.equal(state.pushes[0].uid, state.passengerUid);
  assert.deepEqual(state.pushes[0].payload.data, {
    type: 'driver_approaching_pickup',
    orderId: 'order-current',
  });
});

test('arrived is independent of approaching and sent once', async () => {
  const { app, state } = appFor();
  await location(app, 190);
  assert.equal(state.pushes.length, 1);
  const first = await request(app).post('/api/orders/order-current/arrive');
  assert.equal(first.status, 200);
  assert.equal(state.pushes.length, 2);
  assert.deepEqual(state.pushes[1].payload.data, {
    type: 'driver_arrived', orderId: 'order-current',
  });
  const repeat = await request(app).post('/api/orders/order-current/arrive');
  assert.equal(repeat.status, 409);
  assert.equal(state.pushes.length, 2);
});

test('210 -> 190m notifies once and later inside samples stay silent', async () => {
  const { app, state } = appFor();
  await location(app, 210);
  await location(app, 190);
  await location(app, 180);
  await location(app, 150);
  await location(app, 100);
  assert.equal(state.pushes.length, 1);
});

test('distance uses order pickup and does not depend on passenger GPS', async () => {
  const { app, state } = appFor();
  await location(app, 199);
  assert.equal(state.pushes.length, 1);
  assert.equal(state.pushes[0].uid, 'passenger-current-order');
});

test('198 -> 204 -> 193m remains one-shot for the order', async () => {
  const { app, state } = appFor();
  await location(app, 198);
  await location(app, 204);
  await location(app, 193);
  assert.equal(state.pushes.length, 1);
});

test('reprocessing the same order and location does not duplicate push', async () => {
  const { app, state } = appFor();
  await location(app, 180);
  await location(app, 180);
  assert.equal(state.pushes.length, 1);
});

test('in-progress order never sends approaching-pickup push', async () => {
  const { app, state } = appFor({ status: 'in_progress' });
  assert.equal((await location(app, 100)).status, 200);
  assert.equal(state.pushes.length, 0);
});

test('driver-arrived phase does not send approaching-pickup push', async () => {
  const { app, state } = appFor({ status: 'driver_arrived' });
  assert.equal((await location(app, 100)).status, 200);
  assert.equal(state.pushes.length, 0);
});

test('another driver cannot update or notify this order passenger', async () => {
  const { app, state } = appFor({ authenticatedDriver: 'other-driver' });
  assert.equal((await location(app, 100)).status, 403);
  assert.equal(state.pushes.length, 0);
});

test('zero successful FCM deliveries release claim for one later retry', async () => {
  const { app, state } = appFor({
    pushResults: [
      { successCount: 0, failureCount: 0 },
      { successCount: 1, failureCount: 0 },
    ],
  });
  await location(app, 190);
  assert.equal(state.notified, false);
  assert.equal(state.claim, null);
  await location(app, 180);
  assert.equal(state.pushes.length, 2);
  assert.equal(state.notified, true);
  await location(app, 170);
  assert.equal(state.pushes.length, 2);
});

test('FCM exception releases the claim and the next GPS update retries', async () => {
  const { app, state } = appFor({ pushResults: [new Error('FCM unavailable')] });
  assert.equal((await location(app, 190)).status, 200);
  assert.equal(state.notified, false);
  assert.equal(state.claim, null);
  await location(app, 180);
  await location(app, 170);
  assert.equal(state.pushes.length, 2);
  assert.equal(state.notified, true);
});

test('parallel GPS updates share one claim; dedup commits only after FCM success', async () => {
  let finishPush;
  let startedPush;
  const started = new Promise((resolve) => { startedPush = resolve; });
  const pending = new Promise((resolve) => { finishPush = resolve; });
  const { app, state } = appFor({ pushResults: [() => {
    startedPush();
    return pending;
  }] });
  const first = location(app, 190);
  await started;
  assert.equal(state.notified, false);
  assert.ok(state.claim);
  assert.equal((await location(app, 180)).status, 200);
  assert.equal(state.pushes.length, 1);
  finishPush({ successCount: 1 });
  assert.equal((await first).status, 200);
  assert.equal(state.notified, true);
  assert.equal(state.claim, null);
});

test('expired abandoned claim is reclaimable; a live claim is not', async () => {
  for (const claimExpired of [false, true]) {
    const { app, state } = appFor({ initialClaim: 'old-claim', claimExpired });
    await location(app, 190);
    assert.equal(state.pushes.length, claimExpired ? 1 : 0);
  }
});

test('failed old sender cannot clear a newer claim', async () => {
  let finishPush;
  let startedPush;
  const started = new Promise((resolve) => { startedPush = resolve; });
  const pending = new Promise((resolve) => { finishPush = resolve; });
  const { app, state } = appFor({ pushResults: [() => {
    startedPush();
    return pending;
  }] });
  const first = location(app, 190);
  await started;
  state.claim = 'newer-claim';
  finishPush({ successCount: 0 });
  await first;
  assert.equal(state.claim, 'newer-claim');
  assert.equal(state.notified, false);
});

test('completed and cancelled orders cannot trigger approaching push', async () => {
  for (const status of ['completed', 'cancelled']) {
    const { app, state } = appFor({ status });
    assert.equal((await location(app, 100)).status, 403);
    assert.equal(state.pushes.length, 0);
  }
});
