import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';
import { createOrdersRouter } from '../src/routes/orders.js';

// HTTP contract tests with a strict SQL stub; no production DB is contacted.
function harness({ status = 'active', exempt = true, paid = false, authenticated = true, workCityId = 1, blocked = false } = {}) {
  const orders = ['city', 'delivery', 'intercity'].map((type) => ({
    id: type, service_type: type, status: 'searching', driver_id: null,
    passenger_id: 'passenger', passenger_price: 900,
    created_at: '2026-09-03T00:00:00Z', item_description: 'Parcel',
    city_id: type === 'intercity' ? null : 1,
  }));
  orders.push({ ...orders[0], id: 'rudny-order', city_id: 5 });
  const driver = { id: 'driver', status, access_exempt: exempt,
    subscription_active: paid, work_city_id: workCityId };
  const statements = [];
  const pool = {
    async query(sql, values = []) {
      const q = sql.replace(/\s+/g, ' ').trim();
      statements.push(q);
      if (/^(BEGIN|COMMIT|ROLLBACK)$/.test(q) || q.startsWith('SELECT pg_advisory_xact_lock')) return { rows: [] };
      if (q.startsWith('UPDATE orders o')) return { rows: [] };
      if (q.includes('account_status')) return { rows: [{ id: 'driver', account_status: 'active' }] };
      if (q.includes('AS subscription_active')) {
        assert.match(q, /ds\.payment_status = 'paid'/);
        assert.match(q, /ds\.valid_until > now\(\)/);
        return { rows: [driver] };
      }
      if (q.includes('FROM orders o')) {
        assert.match(q, /\(\$1::text IS NULL OR o\.service_type = \$1\)/);
        assert.match(q, /ORDER BY o\.created_at DESC/);
        assert.match(q, /o\.status = 'searching'/);
        assert.match(q, /st\.enabled = TRUE/);
        return { rows: orders.filter((o) =>
          (values[0] == null || o.service_type === values[0]) &&
          (o.service_type === 'intercity' || o.city_id === values[1])) };
      }
      if (q.includes('FROM user_blocks')) {
        return { rows: blocked ? [{}] : [], rowCount: blocked ? 1 : 0 };
      }
      if (q.startsWith('SELECT id FROM orders')) return { rows: [] };
      if (q.includes('FROM orders WHERE id = $1 FOR UPDATE')) return { rows: orders.filter((o) => o.id === values[0]) };
      if (q.startsWith('UPDATE orders SET')) {
        assert.match(q, /AND status = 'searching' AND driver_id IS NULL/);
        const order = orders.find((o) => o.id === values[1]);
        order.status = 'accepted'; order.driver_id = values[0];
        return { rows: [{ ...order, agreed_price: order.passenger_price }] };
      }
      if (q.startsWith('UPDATE order_offers')) return { rows: [] };
      if (q.includes('AS identity_key')) return { rows: [{ identity_key: 'passenger' }] };
      throw new Error(`Unexpected SQL: ${q}`);
    },
    async connect() { return { query: this.query.bind(this), release() {} }; },
  };
  const app = express();
  app.use(express.json());
  app.use('/api/orders', createOrdersRouter({ pool,
    requireAuth(req, res, next) {
      if (!authenticated) return res.status(401).json({ error: 'Unauthorized' });
      req.user = { uid: 'driver' }; next();
    }, sendToUser() {}, sendToAvailableDrivers() {}, sendPushToUser() {},
  }));
  return { app, statements };
}

for (const access of [{ exempt: true }, { exempt: false, paid: true }]) {
  test(`one unfiltered request includes city and delivery: ${JSON.stringify(access)}`, async () => {
    const res = await request(harness(access).app).get('/api/orders/available').expect(200);
    assert.deepEqual(res.body.map((o) => o.serviceType), ['city', 'delivery', 'intercity']);
    assert.equal(res.body[1].delivery.itemDescription, 'Parcel');
  });
}
for (const type of ['city', 'delivery']) {
  test(`legacy ${type} filter remains exclusive`, async () => {
    const res = await request(harness().app).get(`/api/orders/available?serviceType=${type}`).expect(200);
    assert.deepEqual(res.body.map((o) => o.serviceType), [type]);
  });
  test(`existing atomic accept path handles ${type}`, async () => {
    const { app, statements } = harness();
    const res = await request(app).post(`/api/orders/${type}/accept`).expect(200);
    assert.equal(res.body.status, 'accepted');
    assert.equal(res.body.id, type);
    assert.ok(statements.includes('COMMIT'));
  });
}
for (const status of [null, 'pending', 'suspended']) {
  test(`profile ${status} cannot read available orders even with exemption`, async () => {
    await request(harness({ status }).app).get('/api/orders/available').expect(403);
  });
}
test('unauthenticated rejected', async () => {
  await request(harness({ authenticated: false }).app).get('/api/orders/available').expect(401);
});
test('approved driver has free access without paid shift or exemption', async () => {
  await request(harness({ exempt: false, paid: false }).app)
    .get('/api/orders/available').expect(200);
});
test('blocked pair cannot accept a future order', async () => {
  const response = await request(harness({ blocked: true }).app)
    .post('/api/orders/city/accept').expect(403);
  assert.equal(response.body.code, 'user_blocked');
});

test('driver cannot discover or accept an order from another city', async () => {
  const { app } = harness();
  const available = await request(app).get('/api/orders/available').expect(200);
  assert.ok(!available.body.some((order) => order.id === 'rudny-order'));
  const accept = await request(app).post('/api/orders/rudny-order/accept').expect(403);
  assert.equal(accept.body.code, 'wrong_city');
});
