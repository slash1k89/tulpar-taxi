import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';
import { createDriverProfileRouter } from '../src/routes/driver-profile.js';

function harness({ active = false, enabled = true } = {}) {
  const state = { workCityId: 1, updates: 0 };
  const client = { async query(sql, values = []) {
    const q = sql.replace(/\s+/g, ' ').trim();
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(q)) return { rows: [] };
    if (q.includes('FROM driver_profiles dp JOIN users u')) {
      return { rows: [{ user_id: 'driver', work_city_id: state.workCityId }] };
    }
    if (q.includes('FROM cities WHERE slug')) {
      return { rows: enabled && values[0] === 'rudny' ? [{ id: 5, slug: 'rudny' }] : [] };
    }
    if (q.includes('FROM orders WHERE driver_id')) {
      return { rows: active ? [{ one: 1 }] : [] };
    }
    if (q.startsWith('UPDATE driver_profiles SET work_city_id')) {
      state.workCityId = values[0]; state.updates++;
      return { rows: [] };
    }
    throw new Error(`Unexpected SQL: ${q}`);
  }, release() {} };
  const app = express();
  app.use(express.json());
  app.use('/api/driver-profile', createDriverProfileRouter({
    pool: { async connect() { return client; } },
    requireAuth(req, _res, next) { req.user = { uid: 'driver-uid' }; next(); },
  }));
  return { app, state };
}

test('driver work city changes only to an enabled city', async () => {
  const { app, state } = harness();
  const changed = await request(app).post('/api/driver-profile/work-city')
    .send({ cityId: 'rudny' }).expect(200);
  assert.equal(changed.body.cityId, 'rudny');
  assert.equal(state.workCityId, 5);
  assert.equal(state.updates, 1);
});

test('active local order prevents work-city change', async () => {
  const { app, state } = harness({ active: true });
  const response = await request(app).post('/api/driver-profile/work-city')
    .send({ cityId: 'rudny' }).expect(409);
  assert.equal(response.body.code, 'active_order');
  assert.equal(state.workCityId, 1);
});

test('unsupported city cannot become driver work city', async () => {
  const { app, state } = harness({ enabled: false });
  await request(app).post('/api/driver-profile/work-city')
    .send({ cityId: 'rudny' }).expect(400);
  assert.equal(state.updates, 0);
});
