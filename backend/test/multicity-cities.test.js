import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';
import { createCitiesRouter } from '../src/routes/cities.js';

test('supported city list is authenticated and contains enabled cities only', async () => {
  const app = express();
  app.use('/api/cities', createCitiesRouter({
    pool: { async query(sql) {
      assert.match(sql, /WHERE is_enabled = TRUE/);
      return { rows: [{ id: 'esil', name_ru: 'Есиль' },
        { id: 'rudny', name_ru: 'Рудный' }] };
    } },
    requireAuth(req, res, next) {
      if (req.get('Authorization') !== 'Bearer test') return res.sendStatus(401);
      next();
    },
  }));
  await request(app).get('/api/cities').expect(401);
  const response = await request(app).get('/api/cities')
    .set('Authorization', 'Bearer test').expect(200);
  assert.deepEqual(response.body.map((city) => city.id), ['esil', 'rudny']);
});
