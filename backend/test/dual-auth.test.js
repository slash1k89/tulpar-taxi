import assert from 'node:assert/strict';
import test from 'node:test';

import { createAccessToken } from '../src/auth/access-token.js';
import {
  createDualAuthIdentity,
  createDualAuthMiddleware,
} from '../src/auth/dual-auth.js';

const secret = 'dual-auth-test-secret-at-least-32-characters';
const userId = '00000000-0000-4000-8000-000000000101';
const sessionId = '00000000-0000-4000-8000-000000000102';

function adapters() {
  const rows = [{
    id: userId,
    firebase_uid: 'legacy-firebase-uid',
    phone: '+77771234567',
  }];
  return {
    pool: {
      async query(text, params) {
        if (text.includes('WHERE id = $1')) {
          return { rows: rows.filter((row) => row.id === params[0]) };
        }
        return {
          rows: rows.filter((row) => row.firebase_uid === params[0]),
        };
      },
    },
    firebaseAuth: {
      async verifyIdToken(token) {
        if (token !== 'firebase-token') throw new Error('invalid firebase');
        return {
          uid: 'legacy-firebase-uid',
          phone_number: '+77771234567',
          auth_time: 123,
        };
      },
    },
  };
}

test('Tulpar access token resolves to internal users.id', async () => {
  const identity = createDualAuthIdentity({
    ...adapters(),
    accessTokenSecret: secret,
  });
  const token = createAccessToken({ userId, sessionId, secret });
  const resolved = await identity(token);
  assert.equal(resolved.auth.type, 'tulpar');
  assert.equal(resolved.auth.userId, userId);
  assert.equal(resolved.user.uid, userId);
});

test('legacy Firebase token resolves the same internal users.id', async () => {
  const identity = createDualAuthIdentity({
    ...adapters(),
    accessTokenSecret: secret,
  });
  const resolved = await identity('firebase-token');
  assert.equal(resolved.auth.type, 'firebase');
  assert.equal(resolved.auth.userId, userId);
  assert.equal(resolved.user.uid, 'legacy-firebase-uid');
});

test('dual auth middleware rejects malformed tokens generically', async () => {
  const middleware = createDualAuthMiddleware({
    ...adapters(),
    accessTokenSecret: secret,
  });
  let status;
  let body;
  await middleware(
    { headers: { authorization: 'Bearer invalid' } },
    {
      status(value) { status = value; return this; },
      json(value) { body = value; return this; },
    },
    () => assert.fail('next must not be called'),
  );
  assert.equal(status, 401);
  assert.deepEqual(body, { error: 'Invalid or expired token' });
});

test('WebSocket identity adapter accepts Tulpar access token', async () => {
  const identity = createDualAuthIdentity({
    ...adapters(),
    accessTokenSecret: secret,
  });
  const token = createAccessToken({ userId, sessionId, secret });
  const resolved = await identity(token);
  assert.equal(resolved.user.uid, userId);
  assert.equal(resolved.auth.sessionId, sessionId);
});
