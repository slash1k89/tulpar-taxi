import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';
import { createOrdersRouter } from '../src/routes/orders.js';

const orderId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
function harness({ caller = 'passenger', status = 'completed', assigned = true, authenticated = true } = {}) {
  const saved = [];
  const history = [
    { score: 5, comment: 'Быстро', direction: 'passenger-driver', created_at: '2026-09-03T00:00:00Z' },
    { score: 3, comment: null, direction: 'passenger-driver', created_at: '2026-09-02T00:00:00Z' },
    { score: 1, comment: 'Wrong role', direction: 'driver-passenger', created_at: '2026-09-04T00:00:00Z' },
  ];
  let released = 0;
  const pool = {
    async query(sql, values = []) {
      const q = sql.replace(/\s+/g, ' ').trim();
      if (/^(BEGIN|COMMIT|ROLLBACK)$/.test(q)) return { rows: [] };
      if (q.includes('JOIN users caller')) {
        assert.match(q, /o\.passenger_id = caller\.id/);
        assert.match(q, /caller\.firebase_uid = \$2 OR caller\.id::text = \$2/);
        assert.match(q, /o\.status IN \('accepted', 'driver_arrived', 'in_progress', 'completed', 'queued'\)/);
        assert.equal(values[0], orderId);
        if (values[1] !== 'passenger' || !assigned || !['accepted', 'driver_arrived', 'in_progress', 'completed', 'queued'].includes(status)) return { rows: [] };
        return { rows: [{ driver_id: 'driver', name: 'Иван', car_model: 'ВАЗ', car_color: 'Черный', car_number: '908ALI03', phone: 'secret', access_exempt: true }] };
      }
      if (q.includes('FROM ratings r')) {
        assert.equal(values[0], 'driver');
        assert.match(q, /rated_order\.driver_id = r\.to_user_id/);
        assert.match(q, /rated_order\.passenger_id = r\.from_user_id/);
        assert.match(q, /rated_order\.status = 'completed'/);
        const ratings = history.filter((r) => r.direction === 'passenger-driver');
        if (q.includes('AVG(r.score)')) return { rows: [{ average_rating: 4, ratings_count: ratings.length }] };
        assert.match(q, /NULLIF\(btrim\(r\.comment\), ''\) IS NOT NULL/);
        assert.match(q, /ORDER BY r\.created_at DESC, r\.id DESC LIMIT 20/);
        return { rows: ratings.filter((r) => r.comment) };
      }
      if (q.startsWith('SELECT id FROM users')) return { rows: [{ id: caller }] };
      if (q.includes('FROM orders WHERE id = $1 FOR UPDATE')) return { rows: [{ id: orderId, status, passenger_id: 'passenger', driver_id: assigned ? 'driver' : null }] };
      if (q.startsWith('INSERT INTO ratings')) {
        assert.match(q, /score, comment/);
        assert.equal(values.length, 5);
        if (saved.some((r) => r[0] === values[0] && r[1] === values[1])) throw Object.assign(new Error('duplicate'), { code: '23505' });
        saved.push(values);
        return { rows: [] };
      }
      if (q.startsWith('UPDATE users')) return { rows: [{ id: values[1], rating: values[0], rating_sum: values[0], rating_count: 1 }] };
      throw new Error(`Unexpected SQL: ${q}`);
    },
    async connect() { return { query: this.query.bind(this), release() { released++; } }; },
  };
  const app = express();
  app.use(express.json());
  app.use('/api/orders', createOrdersRouter({ pool, requireAuth(req, res, next) {
    if (!authenticated) return res.status(401).json({ error: 'Unauthorized' });
    req.user = { uid: caller }; next();
  } }));
  return { app, saved, history, get released() { return released; } };
}

test('completed passenger review is trimmed and assigned driver is derived from order', async () => {
  const h = harness();
  await request(h.app).post(`/api/orders/${orderId}/rating`).send({ score: 5, comment: ' Хорошо ', driverId: 'attacker', targetUserId: 'attacker' }).expect(201);
  assert.deepEqual(h.saved[0], [orderId, 'passenger', 'driver', 5, 'Хорошо']);
  assert.equal(h.released, 1);
});
for (const comment of [undefined, null, '', ' \n ']) {
  test(`empty/legacy comment ${JSON.stringify(comment)} stores NULL`, async () => {
    const h = harness();
    await request(h.app).post(`/api/orders/${orderId}/rating`).send({ score: 4, comment }).expect(201);
    assert.equal(h.saved[0][4], null);
  });
}
for (const comment of ['x'.repeat(501), 123, {}]) {
  test(`invalid comment (${typeof comment}) rejected`, async () => {
    const h = harness();
    await request(h.app).post(`/api/orders/${orderId}/rating`).send({ score: 5, comment }).expect(400);
    assert.equal(h.saved.length, 0);
  });
}
for (const status of ['searching', 'accepted', 'pending', 'cancelled', 'in_progress']) {
  test(`cannot review ${status} order`, async () => {
    const h = harness({ status });
    await request(h.app).post(`/api/orders/${orderId}/rating`).send({ score: 5, comment: 'x' }).expect(409);
    assert.equal(h.saved.length, 0);
  });
}
test('unrelated passenger cannot submit review', async () => {
  const h = harness({ caller: 'other' });
  await request(h.app).post(`/api/orders/${orderId}/rating`).send({ score: 5, comment: 'x' }).expect(403);
});
test('duplicate passenger rating rejected', async () => {
  const h = harness();
  const post = () => request(h.app).post(`/api/orders/${orderId}/rating`).send({ score: 4, comment: 'x' });
  await post().expect(201); await post().expect(409);
  assert.equal(h.saved.length, 1);
});
test('driver cannot spoof driver review; stars-only passenger rating is preserved', async () => {
  const h = harness({ caller: 'driver' });
  await request(h.app).post(`/api/orders/${orderId}/rating`).send({ score: 5, comment: 'self', driverId: 'driver' }).expect(403);
  await request(h.app).post(`/api/orders/${orderId}/rating`).send({ score: 4, targetUserId: 'driver' }).expect(201);
  assert.equal(h.saved[0][2], 'passenger');
});
test('passenger assigned profile contains role-scoped rating, reviews, no private fields', async () => {
  const h = harness({ status: 'accepted' });
  const res = await request(h.app).get(`/api/orders/${orderId}/driver-profile`).expect(200);
  assert.equal(res.body.averageRating, 4);
  assert.equal(res.body.ratingsCount, 2);
  assert.deepEqual(Object.keys(res.body).sort(), ['averageRating','carColor','carModel','carNumber','driverId','name','ratingsCount','reviews'].sort());
  assert.deepEqual(res.body.reviews, [{ score: 5, comment: 'Быстро', createdAt: '2026-09-03T00:00:00Z' }]);
});
for (const options of [{ caller: 'other' }, { caller: 'driver' }, { assigned: false }, { status: 'searching' }, { status: 'cancelled' }]) {
  test(`profile denied ${JSON.stringify(options)}`, async () => {
    await request(harness(options).app).get(`/api/orders/${orderId}/driver-profile`).expect(404);
  });
}
test('profile requires authentication', async () => {
  await request(harness({ authenticated: false }).app).get(`/api/orders/${orderId}/driver-profile`).expect(401);
});
test('old ratings with NULL comments contribute to average but not empty review cards', async () => {
  const h = harness(); h.history.forEach((r) => { r.comment = null; });
  const res = await request(h.app).get(`/api/orders/${orderId}/driver-profile`).expect(200);
  assert.equal(res.body.ratingsCount, 2); assert.deepEqual(res.body.reviews, []);
});
