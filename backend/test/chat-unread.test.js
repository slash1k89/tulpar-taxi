import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';
import {
  createChatUnreadRouter,
  markChatRead,
} from '../src/routes/chat-unread.js';

const orderId = '11111111-1111-4111-8111-111111111111';
const viewerId = '22222222-2222-4222-8222-222222222222';

function appFor({ authenticated = true, participant = true } = {}) {
  const queries = [];
  const pool = {
    async query(sql, params) {
      queries.push({ sql, params });
      if (sql.includes('SELECT viewer.id')) {
        return { rows: participant ? [{ id: viewerId }] : [] };
      }
      if (sql.includes('COUNT(*)')) return { rows: [{ unread_count: 3 }] };
      return { rows: [] };
    },
  };
  const app = express();
  app.use('/api/orders/:orderId/messages', createChatUnreadRouter({
    pool,
    requireAuth: (req, res, next) => {
      if (!authenticated) return res.sendStatus(401);
      req.user = { uid: 'session-user' };
      next();
    },
  }));
  return { app, queries };
}

test('unread count is scoped to the authenticated order participant', async () => {
  const { app, queries } = appFor();
  const response = await request(app).get(`/api/orders/${orderId}/messages/unread`);
  assert.equal(response.status, 200);
  assert.deepEqual(response.body, { unreadCount: 3 });
  assert.deepEqual(queries[0].params, [orderId, 'session-user']);
  assert.deepEqual(queries[1].params, [orderId, viewerId]);
  assert.match(queries[1].sql, /m\.sender_id <> viewer\.id/);
  assert.match(queries[1].sql, /m\.created_at > COALESCE\(r\.last_read_at/);
});

test('read endpoint updates only the authenticated participant binding', async () => {
  const { app, queries } = appFor();
  const response = await request(app).post(`/api/orders/${orderId}/messages/read`);
  assert.equal(response.status, 200);
  assert.deepEqual(response.body, { unreadCount: 0 });
  assert.deepEqual(queries[1].params, [orderId, viewerId, null]);
  assert.match(queries[1].sql, /ON CONFLICT \(order_id, user_id\)/);
});

test('unauthenticated and nonparticipant callers cannot access or reset unread', async () => {
  for (const method of ['get', 'post']) {
    const path = `/api/orders/${orderId}/messages/${method === 'get' ? 'unread' : 'read'}`;
    const guest = appFor({ authenticated: false });
    assert.equal((await request(guest.app)[method](path)).status, 401);
    assert.equal(guest.queries.length, 0);

    const outsider = appFor({ participant: false });
    assert.equal((await request(outsider.app)[method](path)).status, 403);
    assert.equal(outsider.queries.length, 1);
  }
});

test('invalid order UUID is rejected before database access', async () => {
  const { app, queries } = appFor();
  assert.equal((await request(app).get('/api/orders/not-a-uuid/messages/unread')).status, 400);
  assert.equal((await request(app).post('/api/orders/not-a-uuid/messages/read')).status, 400);
  assert.equal(queries.length, 0);
});

test('opening a chat can mark only fetched messages as read', async () => {
  const queries = [];
  const pool = { query: async (sql, params) => { queries.push({ sql, params }); } };
  const latestVisible = new Date('2026-09-14T12:00:00Z');
  await markChatRead(pool, orderId, viewerId, latestVisible);
  assert.deepEqual(queries[0].params, [orderId, viewerId, latestVisible]);
  assert.match(queries[0].sql, /GREATEST/);
});
