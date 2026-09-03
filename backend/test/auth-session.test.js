import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';

import {
  createAccessToken,
  verifyAccessToken,
} from '../src/auth/access-token.js';
import {
  AuthSessionService,
  hashRefreshToken,
} from '../src/auth/session-service.js';

const secret = 'test-only-secret-that-is-at-least-32-characters';
const userId = '00000000-0000-4000-8000-000000000001';
const sessionId = '00000000-0000-4000-8000-000000000002';
const now = new Date('2026-08-30T12:00:00.000Z');

function signedToken(payload, header = { alg: 'HS256', typ: 'JWT' }) {
  const headerPart = Buffer.from(JSON.stringify(header)).toString('base64url');
  const payloadPart = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const input = `${headerPart}.${payloadPart}`;
  const signature = createHmac('sha256', secret)
    .update(input)
    .digest('base64url');
  return `${input}.${signature}`;
}

function validClaims(overrides = {}) {
  const issuedAt = Math.floor(now.getTime() / 1000);
  return {
    iss: 'tulpar-api',
    aud: 'tulpar-mobile',
    sub: userId,
    sid: sessionId,
    iat: issuedAt,
    exp: issuedAt + 900,
    ...overrides,
  };
}

class MemorySessionPool {
  constructor() {
    this.sessions = [];
    this.nextId = 1;
  }

  async query(sql, values) {
    if (sql.includes('INSERT INTO auth_sessions')) {
      const row = {
        id: `00000000-0000-4000-8000-${String(this.nextId++).padStart(12, '0')}`,
        user_id: values[0],
        refresh_token_hash: values[1],
        created_at: values[2],
        expires_at: values[3],
        revoked_at: null,
      };
      this.sessions.push(row);
      return { rows: [row], rowCount: 1 };
    }
    if (sql.includes('SET refresh_token_hash')) {
      const row = this.sessions.find((item) =>
        item.refresh_token_hash === values[5] &&
        item.revoked_at === null &&
        item.expires_at > values[1]);
      if (!row) return { rows: [], rowCount: 0 };
      row.refresh_token_hash = values[0];
      row.last_used_at = values[1];
      return { rows: [row], rowCount: 1 };
    }
    if (sql.includes('WHERE refresh_token_hash')) {
      const row = this.sessions.find((item) =>
        item.refresh_token_hash === values[0] &&
        item.revoked_at === null &&
        item.expires_at > values[1]);
      return { rows: row ? [row] : [], rowCount: row ? 1 : 0 };
    }
    if (sql.includes('WHERE id = $1 AND user_id = $2')) {
      const row = this.sessions.find((item) =>
        item.id === values[0] && item.user_id === values[1]);
      if (!row) return { rows: [], rowCount: 0 };
      row.revoked_at ??= values[2];
      return { rows: [{ id: row.id }], rowCount: 1 };
    }
    if (sql.includes('WHERE user_id = $1 AND revoked_at IS NULL')) {
      const rows = this.sessions.filter((item) =>
        item.user_id === values[0] && item.revoked_at === null);
      for (const row of rows) row.revoked_at = values[1];
      return { rows: [], rowCount: rows.length };
    }
    throw new Error(`Unexpected SQL: ${sql}`);
  }
}

function createService(pool = new MemorySessionPool()) {
  let tokenNumber = 0;
  return {
    pool,
    service: new AuthSessionService({
      pool,
      accessTokenSecret: secret,
      now: () => new Date(now),
      generateRefreshToken: () => `refresh-token-${++tokenNumber}-`.padEnd(64, 'x'),
    }),
  };
}

test('createSession stores only refresh token hash', async () => {
  const { pool, service } = createService();
  const created = await service.createSession(userId, { deviceId: 'phone-1' });
  assert.equal(pool.sessions.length, 1);
  assert.notEqual(pool.sessions[0].refresh_token_hash, created.refreshToken);
  assert.equal(
    pool.sessions[0].refresh_token_hash,
    hashRefreshToken(created.refreshToken),
  );
});

test('access token verifies internal user and session identity', () => {
  const token = createAccessToken({
    userId,
    sessionId,
    secret,
    now: now.getTime(),
  });
  const claims = verifyAccessToken(token, {
    secret,
    now: now.getTime() + 1000,
  });
  assert.equal(claims.sub, userId);
  assert.equal(claims.sid, sessionId);
});

test('malformed and tampered access JWTs are rejected', () => {
  assert.throws(() => verifyAccessToken('not-a-jwt', { secret }));
  const token = signedToken(validClaims());
  const [header, payload] = token.split('.');
  assert.throws(() => verifyAccessToken(`${header}.${payload}.invalid`, { secret }));
  const malformedPayload = `${header}.e25vdC1qc29ufQ.${token.split('.')[2]}`;
  assert.throws(() => verifyAccessToken(malformedPayload, { secret }));
});

test('access JWT rejects algorithm substitution', () => {
  assert.throws(() => verifyAccessToken(
    signedToken(validClaims(), { alg: 'none', typ: 'JWT' }),
    { secret, now: now.getTime() },
  ));
});

test('access JWT rejects wrong issuer and audience', () => {
  assert.throws(() => verifyAccessToken(signedToken(
    validClaims({ iss: 'attacker' }),
  ), { secret, now: now.getTime() }));
  assert.throws(() => verifyAccessToken(signedToken(
    validClaims({ aud: 'other-client' }),
  ), { secret, now: now.getTime() }));
});

test('expired access JWT is rejected', () => {
  const issuedAt = Math.floor(now.getTime() / 1000);
  const token = signedToken(validClaims({ exp: issuedAt - 1 }));
  assert.throws(() => verifyAccessToken(token, { secret, now: now.getTime() }));
});

test('access JWT requires UUID subject and session claims', () => {
  assert.throws(() => verifyAccessToken(
    signedToken(validClaims({ sub: 'user-1' })),
    { secret, now: now.getTime() },
  ));
  assert.throws(() => verifyAccessToken(
    signedToken(validClaims({ sid: 'session-1' })),
    { secret, now: now.getTime() },
  ));
});

test('empty and short access token secrets are rejected', () => {
  assert.throws(() => createAccessToken({ userId, sessionId, secret: '' }));
  assert.throws(() => createAccessToken({ userId, sessionId, secret: 'short' }));
});

test('refresh token rotation returns a new token', async () => {
  const { service } = createService();
  const created = await service.createSession(userId);
  const rotated = await service.rotateRefreshToken(created.refreshToken);
  assert.ok(rotated);
  assert.notEqual(rotated.refreshToken, created.refreshToken);
  assert.equal(rotated.sessionId, created.sessionId);
});

test('old refresh token is rejected after rotation', async () => {
  const { service } = createService();
  const created = await service.createSession(userId);
  const rotated = await service.rotateRefreshToken(created.refreshToken);
  assert.ok(rotated);
  assert.equal(await service.verifyRefreshToken(created.refreshToken), null);
  assert.equal(
    (await service.verifyRefreshToken(rotated.refreshToken)).id,
    created.sessionId,
  );
});

test('revokeSession invalidates the selected session', async () => {
  const { service } = createService();
  const created = await service.createSession(userId);
  assert.equal(await service.revokeSession(created.sessionId, userId), true);
  assert.equal(await service.verifyRefreshToken(created.refreshToken), null);
});

test('expired refresh token is rejected', async () => {
  const { pool, service } = createService();
  const created = await service.createSession(userId);
  pool.sessions[0].expires_at = new Date(now.getTime() - 1);
  assert.equal(await service.verifyRefreshToken(created.refreshToken), null);
});

test('revokeAllUserSessions invalidates every active user session', async () => {
  const { service } = createService();
  const first = await service.createSession(userId);
  const second = await service.createSession(userId);
  assert.equal(await service.revokeAllUserSessions(userId), 2);
  assert.equal(await service.verifyRefreshToken(first.refreshToken), null);
  assert.equal(await service.verifyRefreshToken(second.refreshToken), null);
});
