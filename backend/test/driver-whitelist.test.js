import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import { DriverWhitelistService } from '../src/driver-whitelist.js';
import { createDriverProfileRouter } from '../src/routes/driver-profile.js';
import { createOrdersRouter } from '../src/routes/orders.js';

const allowedPhone = '+77085305640';

class WhitelistPool {
  rows = new Map();

  async query(sql, values = []) {
    if (sql.includes('INSERT INTO driver_phone_whitelist')) {
      const existed = this.rows.has(values[0]);
      if (!existed) this.rows.set(values[0], { phone_normalized: values[0] });
      return { rowCount: existed ? 0 : 1, rows: existed ? [] : [this.rows.get(values[0])] };
    }
    if (sql.includes('SELECT EXISTS')) {
      return { rows: [{ allowed: this.rows.has(values[0]) }] };
    }
    if (sql.includes('DELETE FROM driver_phone_whitelist')) {
      const removed = this.rows.delete(values[0]);
      return { rowCount: removed ? 1 : 0, rows: removed ? [{ phone_normalized: values[0] }] : [] };
    }
    if (sql.includes('SELECT phone_normalized')) {
      return { rows: [...this.rows.values()] };
    }
    throw new Error(`Unexpected SQL: ${sql}`);
  }
}

test('migration seeds the approved test phone exactly once', () => {
  const sql = fs.readFileSync(
    new URL('../migrations/20260902_011_driver_phone_whitelist.sql', import.meta.url),
    'utf8',
  );
  assert.match(sql, /VALUES \('\+77085305640'\)/);
  assert.match(sql, /PRIMARY KEY/);
  assert.match(sql, /ON CONFLICT \(phone_normalized\) DO NOTHING/);
});

test('whitelist normalizes Kazakhstan phone variants and rejects duplicates', async () => {
  const pool = new WhitelistPool();
  const service = new DriverWhitelistService(pool);
  assert.equal((await service.add('8 708 530-56-40')).phoneNormalized, allowedPhone);
  assert.equal((await service.add('77085305640')).added, false);
  assert.equal(await service.has('+7 (708) 530-56-40'), true);
  assert.deepEqual((await service.list()).map((row) => row.phone_normalized), [allowedPhone]);
  assert.equal((await service.remove('87085305640')).removed, true);
});

function driverApp({ trustedPhone, whitelisted, captured }) {
  const pool = {
    async query(sql, values) {
      captured.sql = sql;
      captured.values = values;
      const trustedIdentityIsAllowed = trustedPhone === allowedPhone && whitelisted;
      captured.accessExempt = trustedIdentityIsAllowed;
      return {
        rows: [{
          user_id: '00000000-0000-4000-8000-000000000001',
          status: trustedIdentityIsAllowed ? 'active' : 'pending',
          access_exempt: trustedIdentityIsAllowed,
          car_model: values[0],
          car_color: values[1],
          car_number: values[2],
          agreement_version: '1.0',
          agreement_accepted_at: new Date(),
        }],
      };
    },
  };
  const app = express();
  app.use(express.json());
  app.use('/api/driver-profile', createDriverProfileRouter({
    pool,
    requireAuth: (req, _res, next) => {
      req.user = { uid: '00000000-0000-4000-8000-000000000001' };
      next();
    },
  }));
  return app;
}

test('valid profile becomes active only from the verified server identity whitelist', async () => {
  const captured = {};
  const response = await request(driverApp({
    trustedPhone: allowedPhone,
    whitelisted: true,
    captured,
  })).post('/api/driver-profile/vehicle').send({
    carModel: 'Toyota Camry',
    carColor: 'Белый',
    carNumber: '001 ABC',
    phone: '+77770000000',
  });
  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'active');
  assert.match(captured.sql, /FROM auth_phone_identities identity/);
  assert.match(captured.sql, /approved\.user_id = u\.id/);
  assert.match(captured.sql, /dp\.user_id = u\.id/);
  assert.match(captured.sql, /access_exempt = \(approved\.user_id IS NOT NULL\)/);
  assert.equal(captured.accessExempt, true);
  assert.doesNotMatch(captured.sql, /INSERT INTO driver_subscriptions/);
  assert.equal(captured.values.includes('+77770000000'), false);
});

test('non-whitelisted verified identity keeps the normal pending workflow', async () => {
  const captured = {};
  const response = await request(driverApp({
    trustedPhone: '+77770000000',
    whitelisted: false,
    captured,
  })).post('/api/driver-profile/vehicle').send({
    carModel: 'Toyota Camry', carColor: 'Белый', carNumber: '001 ABC',
    phone: allowedPhone, accessExempt: true, status: 'active',
  });
  assert.equal(response.status, 200);
  assert.equal(response.body.status, 'pending');
  assert.equal(captured.accessExempt, false);
  assert.equal(captured.values.includes(allowedPhone), false);
});

test('whitelisted active vehicle-model edit preserves approval and grants exemption', async () => {
  const captured = {};
  const response = await request(driverApp({
    trustedPhone: allowedPhone, whitelisted: true, captured,
  })).patch('/api/driver-profile/vehicle-model').send({ carModel: 'Toyota Prius' });
  assert.equal(response.status, 200);
  assert.match(captured.sql, /dp\.status = 'active'[\s\S]*AND approved\.user_id IS NULL/);
  assert.match(captured.sql, /access_exempt = dp\.access_exempt OR/);
  assert.match(captured.sql, /dp\.status = 'active' AND approved\.user_id IS NOT NULL/);
});

test('backfill is restricted to active profiles with verified whitelist identity', () => {
  const sql = fs.readFileSync(new URL(
    '../migrations/20260903_012_whitelist_access_exempt.sql', import.meta.url,
  ), 'utf8');
  assert.match(sql, /SET access_exempt = TRUE/);
  assert.match(sql, /dp\.status = 'active'/);
  assert.match(sql, /identity\.user_id = dp\.user_id/);
  assert.match(sql, /whitelist\.phone_normalized = identity\.phone_normalized/);
  assert.doesNotMatch(sql, /driver_subscriptions/);
});

test('available city orders are free for every approved active driver', async () => {
  for (const [status, exempt, paid, expected] of [
    ['active', true, false, 200],
    ['active', false, false, 200],
    ['active', false, true, 200],
    ['pending', true, false, 403],
    ['suspended', true, true, 403],
  ]) {
    const pool = { async query(sql) {
      if (sql.includes('AS subscription_active')) return { rows: [{
        id: 'driver', status, access_exempt: exempt, subscription_active: paid,
      }] };
      return { rows: [], rowCount: 0 };
    } };
    const app = express();
    app.use('/api/orders', createOrdersRouter({ pool,
      requireAuth(req, _res, next) { req.user = { uid: 'driver' }; next(); },
    }));
    const response = await request(app).get('/api/orders/available?serviceType=city');
    assert.equal(response.status, expected, `${status}/${exempt}/${paid}`);
  }
});
