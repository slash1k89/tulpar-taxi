import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import {
  apiErrorHandler,
  configureTrustProxy,
  createApiRateLimiter,
  createCorsMiddleware,
  createHelmetMiddleware,
  createJsonBodyParser,
  createPushTestRateLimiter,
} from '../src/http-security.js';
import { isSelfOrder, selectUserSyncPhone } from '../src/security-policy.js';
import { createOrdersRouter } from '../src/routes/orders.js';

function createHttpApp({
  allowedWebOrigins = '',
  apiLimit = 100,
  nodeEnv = 'test',
  trustProxyHops = 0,
} = {}) {
  const app = express();
  configureTrustProxy(app, trustProxyHops);
  app.use(createHelmetMiddleware());
  app.use(createCorsMiddleware({ allowedWebOrigins, nodeEnv }));
  app.use(
    '/api',
    createApiRateLimiter({
      windowMs: 60_000,
      limit: apiLimit,
    }),
  );
  app.use(createJsonBodyParser());

  app.get('/health', (_req, res) => res.json({ ok: true }));
  app.get('/api/ping', (_req, res) => res.json({ ok: true }));
  app.post('/api/echo', (req, res) => res.json(req.body));
  app.get('/api/fail', () => {
    throw new Error('sensitive SQL and filesystem details');
  });

  app.use(apiErrorHandler);
  return app;
}

function createSelfOrderRouteApp() {
  const queries = [];
  let released = false;
  const client = {
    async query(sql) {
      const normalizedSql = String(sql).replace(/\s+/g, ' ').trim();
      queries.push(normalizedSql);

      if (normalizedSql === 'BEGIN' || normalizedSql === 'ROLLBACK') {
        return { rows: [] };
      }
      if (normalizedSql.startsWith('SELECT pg_advisory_xact_lock')) {
        return { rows: [{}], rowCount: 1 };
      }
      if (normalizedSql.startsWith('SELECT id, name, phone, account_status FROM users')) {
        return {
          rows: [{
            id: 42,
            name: 'Fixture User',
            phone: '+70000000000',
            account_status: 'active',
          }],
          rowCount: 1,
        };
      }
      if (normalizedSql.startsWith('SELECT 1 FROM account_deletion_jobs')) {
        return { rows: [], rowCount: 0 };
      }
      if (normalizedSql.includes('FROM users u')) {
        return {
          rows: [
            {
              id: 42,
              status: 'active',
              access_exempt: true,
              subscription_active: false,
            },
          ],
        };
      }
      if (normalizedSql.includes('FROM orders')) {
        return {
          rows: [
            {
              id: 'order-1',
              passenger_id: 42,
              passenger_price: 1000,
              status: 'searching',
              driver_id: null,
              passenger_firebase_uid: 'same-user',
            },
          ],
        };
      }

      throw new Error(`Unexpected test query: ${normalizedSql}`);
    },
    release() {
      released = true;
    },
  };
  const pool = {
    async connect() {
      return client;
    },
  };
  const requireAuth = (req, _res, next) => {
    req.user = { uid: 'same-user' };
    next();
  };
  const app = express();
  app.use(express.json());
  app.use(
    '/api/orders',
    createOrdersRouter({
      pool,
      requireAuth,
      sendToUser: () => {},
      sendToAvailableDrivers: () => {},
      sendPushToUser: async () => ({ successCount: 0, failureCount: 0 }),
    }),
  );

  return {
    app,
    queries,
    wasReleased: () => released,
  };
}

test('malformed JSON returns a stable 400 JSON error', async () => {
  const response = await request(createHttpApp())
    .post('/api/echo')
    .set('Content-Type', 'application/json')
    .send('{"broken":');

  assert.equal(response.status, 400);
  assert.deepEqual(response.body, { error: 'Invalid JSON body' });
  assert.equal(response.text.includes('SyntaxError'), false);
});

test('JSON bodies larger than 64kb return a stable 413 JSON error', async () => {
  const response = await request(createHttpApp())
    .post('/api/echo')
    .send({ value: 'x'.repeat(70 * 1024) });

  assert.equal(response.status, 413);
  assert.deepEqual(response.body, { error: 'Request body too large' });
});

test('unexpected errors do not disclose stack traces or internal details', async (t) => {
  const originalConsoleError = console.error;
  console.error = () => {};
  t.after(() => {
    console.error = originalConsoleError;
  });

  const response = await request(createHttpApp()).get('/api/fail');

  assert.equal(response.status, 500);
  assert.deepEqual(response.body, { error: 'Internal server error' });
  assert.equal(response.text.includes('sensitive SQL'), false);
  assert.equal(response.text.includes('http-security.test.js'), false);
});

test('Helmet adds API-safe security headers without an HTML CSP', async () => {
  const response = await request(createHttpApp()).get('/health');

  assert.equal(response.status, 200);
  assert.equal(response.headers['x-content-type-options'], 'nosniff');
  assert.equal(response.headers['content-security-policy'], undefined);
});

test('CORS allows localhost with any local port', async () => {
  const response = await request(createHttpApp())
    .get('/api/ping')
    .set('Origin', 'http://localhost:5173');

  assert.equal(response.status, 200);
  assert.equal(response.headers['access-control-allow-origin'], 'http://localhost:5173');
  assert.match(response.headers.vary, /Origin/i);
});

test('production CORS rejects localhost unless explicitly configured', async () => {
  const response = await request(createHttpApp({ nodeEnv: 'production' }))
    .get('/api/ping')
    .set('Origin', 'http://localhost:5173');

  assert.equal(response.status, 403);
});

test('production CORS allows an exact configured web origin', async () => {
  const response = await request(createHttpApp({
    nodeEnv: 'production',
    allowedWebOrigins: 'https://app.tulpar.example',
  }))
    .get('/api/ping')
    .set('Origin', 'https://app.tulpar.example');

  assert.equal(response.status, 200);
});

test('production CORS keeps native requests without Origin working', async () => {
  const response = await request(createHttpApp({ nodeEnv: 'production' }))
    .get('/api/ping');

  assert.equal(response.status, 200);
});

test('trust proxy defaults to zero and ignores spoofed forwarded IP', async () => {
  const app = express();
  configureTrustProxy(app);
  app.get('/ip', (req, res) => res.json({ ip: req.ip }));

  const response = await request(app)
    .get('/ip')
    .set('X-Forwarded-For', '203.0.113.10');

  assert.notEqual(response.body.ip, '203.0.113.10');
});

test('one trusted proxy hop uses the client IP supplied by Nginx', async () => {
  const app = express();
  configureTrustProxy(app, 1);
  app.get('/ip', (req, res) => res.json({ ip: req.ip }));

  const response = await request(app)
    .get('/ip')
    .set('X-Forwarded-For', '203.0.113.10');

  assert.equal(response.body.ip, '203.0.113.10');
});

test('different client IPs behind one proxy use separate rate-limit buckets', async () => {
  const app = createHttpApp({ apiLimit: 1, trustProxyHops: 1 });
  const first = await request(app)
    .get('/api/ping')
    .set('X-Forwarded-For', '203.0.113.10');
  const second = await request(app)
    .get('/api/ping')
    .set('X-Forwarded-For', '203.0.113.11');

  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
});

test('invalid TRUST_PROXY_HOPS values fail closed', () => {
  for (const value of ['-1', '1.5', 'true', '11', '']) {
    assert.throws(
      () => configureTrustProxy(express(), value),
      /TRUST_PROXY_HOPS/,
    );
  }
});

test('trust proxy is configured with a numeric hop count, never true', () => {
  const app = express();
  configureTrustProxy(app, 1);
  assert.equal(app.get('trust proxy'), 1);
  assert.notEqual(app.get('trust proxy'), true);
});

test('CORS allows 127.0.0.1 with any local port', async () => {
  const response = await request(createHttpApp())
    .get('/api/ping')
    .set('Origin', 'http://127.0.0.1:8080');

  assert.equal(response.status, 200);
  assert.equal(response.headers['access-control-allow-origin'], 'http://127.0.0.1:8080');
});

test('CORS rejects an arbitrary web origin', async () => {
  const response = await request(createHttpApp())
    .get('/api/ping')
    .set('Origin', 'https://attacker.example');

  assert.equal(response.status, 403);
  assert.deepEqual(response.body, { error: 'CORS origin denied' });
  assert.equal(response.headers['access-control-allow-origin'], undefined);
});

test('CORS allows an exact ALLOWED_WEB_ORIGINS entry', async () => {
  const app = createHttpApp({
    allowedWebOrigins: 'https://app.tulpar.example,https://admin.tulpar.example',
  });
  const response = await request(app)
    .get('/api/ping')
    .set('Origin', 'https://app.tulpar.example');

  assert.equal(response.status, 200);
  assert.equal(
    response.headers['access-control-allow-origin'],
    'https://app.tulpar.example',
  );
});

test('CORS rejects an origin-prefix attack', async () => {
  const app = createHttpApp({
    allowedWebOrigins: 'https://app.tulpar.example',
  });
  const response = await request(app)
    .get('/api/ping')
    .set('Origin', 'https://app.tulpar.example.attacker.test');

  assert.equal(response.status, 403);
  assert.equal(response.headers['access-control-allow-origin'], undefined);
});

test('native clients without Origin remain allowed', async () => {
  const response = await request(createHttpApp()).get('/api/ping');

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, { ok: true });
  assert.match(response.headers.vary, /Origin/i);
});

test('allowed CORS preflight receives explicit methods and headers', async () => {
  const response = await request(createHttpApp())
    .options('/api/ping')
    .set('Origin', 'http://localhost:3000')
    .set('Access-Control-Request-Method', 'POST');

  assert.equal(response.status, 204);
  assert.equal(response.headers['access-control-allow-origin'], 'http://localhost:3000');
  assert.match(response.headers['access-control-allow-methods'], /POST/);
  assert.match(response.headers['access-control-allow-headers'], /Authorization/);
  assert.equal(response.headers['access-control-allow-credentials'], undefined);
});

test('the general API rate limit returns JSON 429', async () => {
  const app = createHttpApp({ apiLimit: 2 });

  assert.equal((await request(app).get('/api/ping')).status, 200);
  assert.equal((await request(app).get('/api/ping')).status, 200);
  const limited = await request(app).get('/api/ping');

  assert.equal(limited.status, 429);
  assert.deepEqual(limited.body, { error: 'Too many requests' });
});

test('/health is excluded from the general API rate limit', async () => {
  const app = createHttpApp({ apiLimit: 1 });

  assert.equal((await request(app).get('/api/ping')).status, 200);
  assert.equal((await request(app).get('/api/ping')).status, 429);
  assert.equal((await request(app).get('/health')).status, 200);
  assert.equal((await request(app).get('/health')).status, 200);
});

test('/api/push/test is limited by authenticated UID', async () => {
  const app = express();
  const limiter = createPushTestRateLimiter({ windowMs: 60_000, limit: 1 });
  const fakeAuth = (req, _res, next) => {
    req.user = { uid: req.get('X-Test-Uid') };
    next();
  };

  app.post('/api/push/test', fakeAuth, limiter, (_req, res) => {
    res.json({ sent: true });
  });

  assert.equal(
    (await request(app).post('/api/push/test').set('X-Test-Uid', 'user-a')).status,
    200,
  );
  assert.equal(
    (await request(app).post('/api/push/test').set('X-Test-Uid', 'user-a')).status,
    429,
  );
  assert.equal(
    (await request(app).post('/api/push/test').set('X-Test-Uid', 'user-b')).status,
    200,
  );
});

test('verified Firebase phone wins over a conflicting body phone', () => {
  const selected = selectUserSyncPhone({
    verifiedPhone: '+77001234567',
    legacyBodyPhone: '+79999999999',
  });

  assert.equal(selected, '+77001234567');
});

test('body phone remains a temporary fallback without a verified claim', () => {
  const selected = selectUserSyncPhone({
    verifiedPhone: null,
    legacyBodyPhone: '+77007654321',
  });

  assert.equal(selected, '+77007654321');
});

test('a driver cannot directly accept their own passenger order', async () => {
  const harness = createSelfOrderRouteApp();
  const response = await request(harness.app).post('/api/orders/order-1/accept');

  assert.equal(response.status, 409);
  assert.deepEqual(response.body, {
    error: 'Driver cannot accept their own passenger order',
  });
  assert.equal(harness.queries.at(-1), 'ROLLBACK');
  assert.equal(harness.queries.some((query) => query.startsWith('UPDATE orders')), false);
  assert.equal(harness.wasReleased(), true);
});

test('a driver cannot offer on their own passenger order', async () => {
  const harness = createSelfOrderRouteApp();
  const response = await request(harness.app)
    .post('/api/orders/order-1/offers')
    .send({ price: 1500 });

  assert.equal(response.status, 409);
  assert.deepEqual(response.body, {
    error: 'Driver cannot offer on their own passenger order',
  });
  assert.equal(harness.queries.at(-1), 'ROLLBACK');
  assert.equal(harness.queries.some((query) => query.startsWith('INSERT INTO order_offers')), false);
  assert.equal(harness.wasReleased(), true);
  assert.equal(isSelfOrder({ passengerId: 42, driverId: 43 }), false);
});
