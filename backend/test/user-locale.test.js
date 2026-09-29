import test from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import request from 'supertest';
import { createUserLocaleRouter } from '../src/routes/user-locale.js';

function appFor({ rows = [{ locale: 'kk' }], authenticated = true } = {}) {
  const queries = [];
  const app = express();
  app.use(express.json());
  app.use('/api/users', createUserLocaleRouter({
    pool: { query: async (sql, params) => { queries.push({ sql, params }); return { rows }; } },
    requireAuth: (req, res, next) => {
      if (!authenticated) return res.sendStatus(401);
      req.user = { uid: 'user-1' };
      next();
    },
  }));
  return { app, queries };
}

test('guest cannot synchronize locale', async () => {
  const { app, queries } = appFor({ authenticated: false });
  const response = await request(app).patch('/api/users/me/locale').send({ locale: 'kk' });
  assert.equal(response.status, 401);
  assert.equal(queries.length, 0);
});

test('only ru, kk and en reach the user update', async () => {
  const { app, queries } = appFor();
  for (const locale of ['ru', 'kk', 'en']) {
    const response = await request(app).patch('/api/users/me/locale').send({ locale });
    assert.equal(response.status, 200);
    assert.deepEqual(queries.at(-1).params, [locale, 'user-1']);
  }
  const count = queries.length;
  for (const locale of ['kz', 'de', '', null, 42]) {
    const response = await request(app).patch('/api/users/me/locale').send({ locale });
    assert.equal(response.status, 400);
  }
  assert.equal(queries.length, count);
});

test('missing user does not report a successful sync', async () => {
  const { app } = appFor({ rows: [] });
  const response = await request(app).patch('/api/users/me/locale').send({ locale: 'en' });
  assert.equal(response.status, 404);
});
