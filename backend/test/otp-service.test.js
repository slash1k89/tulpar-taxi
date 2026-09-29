import assert from 'node:assert/strict';
import test from 'node:test';

import { normalizeKazakhstanPhone } from '../src/auth/phone-normalization.js';
import {
  OtpChallengeError,
  OtpChallengeService,
} from '../src/auth/otp-service.js';

const secret = 'test-only-otp-secret-at-least-32-characters';
const challengeIds = [
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000003',
];

class MemoryOtpPool {
  constructor() {
    this.rows = [];
  }

  async connect() {
    return {
      query: (sql, values) => this.query(sql, values),
      release() {},
    };
  }

  async query(sql, values = []) {
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(sql)) return { rows: [], rowCount: 0 };
    if (sql.includes('pg_advisory_xact_lock')) return { rows: [{}], rowCount: 1 };
    if (sql.includes('SELECT resend_available_at')) {
      const rows = this.rows
        .filter((row) => row.phone_normalized === values[0] &&
          row.purpose === values[1] && !row.consumed_at)
        .sort((a, b) => b.created_at - a.created_at);
      return { rows: rows.slice(0, 1), rowCount: Math.min(rows.length, 1) };
    }
    if (sql.includes('SET consumed_at = $3')) {
      const rows = this.rows.filter((row) =>
        row.phone_normalized === values[0] && row.purpose === values[1] && !row.consumed_at);
      for (const row of rows) row.consumed_at = values[2];
      return { rows: [], rowCount: rows.length };
    }
    if (sql.includes('INSERT INTO auth_otp_challenges')) {
      this.rows.push({
        id: values[0], phone_normalized: values[1], code_hash: values[2],
        purpose: values[3], method: 'sms',
        created_at: values[4], expires_at: values[5],
        attempts_count: 0, max_attempts: values[6],
        resend_available_at: values[7], consumed_at: null,
        request_ip: values[8], device_id: values[9],
      });
      return { rows: [], rowCount: 1 };
    }
    if (sql.includes('purpose = $4') && sql.includes('FOR UPDATE')) {
      const row = this.rows.find((item) =>
        item.id === values[0] && item.phone_normalized === values[1] &&
        item.method === values[2] && item.purpose === values[3]);
      return { rows: row ? [row] : [], rowCount: row ? 1 : 0 };
    }
    if (sql.includes('SET attempts_count = attempts_count + 1')) {
      const row = this.rows.find((item) =>
        item.id === values[0] && !item.consumed_at && item.expires_at > values[1] &&
        item.attempts_count < item.max_attempts);
      if (!row) return { rows: [], rowCount: 0 };
      row.attempts_count += 1;
      return { rows: [row], rowCount: 1 };
    }
    if (sql.includes('SET consumed_at = $2')) {
      const row = this.rows.find((item) =>
        item.id === values[0] && !item.consumed_at && item.expires_at > values[1] &&
        item.attempts_count < item.max_attempts);
      if (!row) return { rows: [], rowCount: 0 };
      row.consumed_at = values[1];
      return { rows: [{ id: row.id }], rowCount: 1 };
    }
    if (sql.includes('SET consumed_at = COALESCE')) {
      const row = this.rows.find((item) => item.id === values[0]);
      if (!row) return { rows: [], rowCount: 0 };
      row.consumed_at ??= values[1];
      return { rows: [{ id: row.id }], rowCount: 1 };
    }
    throw new Error(`Unexpected SQL: ${sql}`);
  }
}

function fixture({ maxAttempts = 3 } = {}) {
  const pool = new MemoryOtpPool();
  let currentTime = new Date('2026-08-30T12:00:00.000Z');
  let idIndex = 0;
  let codeIndex = 0;
  const codes = ['123456', '654321', '111222'];
  const service = new OtpChallengeService({
    pool, secret, maxAttempts,
    now: () => new Date(currentTime),
    generateId: () => challengeIds[idIndex++],
    generateCode: () => codes[codeIndex++],
  });
  return {
    pool,
    service,
    advance(seconds) {
      currentTime = new Date(currentTime.getTime() + seconds * 1000);
    },
  };
}

test('Kazakhstan phone normalization accepts supported forms', () => {
  for (const value of [
    '+7 777 123-45-67', '77771234567', '8 (777) 123-45-67',
  ]) {
    assert.equal(normalizeKazakhstanPhone(value), '+77771234567');
  }
});

test('malformed or non-Kazakhstan phone is rejected', () => {
  for (const value of ['+7abc', '123', '+74951234567', null]) {
    assert.throws(() => normalizeKazakhstanPhone(value));
  }
});

test('OTP challenge is created without persisting raw OTP', async () => {
  const { pool, service } = fixture();
  const created = await service.createOtpChallenge('+7 777 123-45-67', {
    requestIp: '127.0.0.1', deviceId: 'phone-1',
  });
  assert.equal(created.rawOtp, '123456');
  assert.equal(pool.rows.length, 1);
  assert.notEqual(pool.rows[0].code_hash, created.rawOtp);
  assert.equal(Object.hasOwn(pool.rows[0], 'rawOtp'), false);
  assert.equal(Object.hasOwn(pool.rows[0], 'code'), false);
});

test('valid OTP verifies once and consumed challenge is rejected', async () => {
  const { service } = fixture();
  const created = await service.createOtpChallenge('87771234567');
  assert.equal((await service.verifyOtpChallenge(
    created.challengeId, created.phoneNormalized, created.rawOtp,
  )).verified, true);
  await assert.rejects(
    service.verifyOtpChallenge(created.challengeId, created.phoneNormalized, created.rawOtp),
    (error) => error instanceof OtpChallengeError && error.code === 'challenge_consumed',
  );
});

test('wrong OTP atomically increments attempts', async () => {
  const { pool, service } = fixture();
  const created = await service.createOtpChallenge('87771234567');
  await assert.rejects(
    service.verifyOtpChallenge(created.challengeId, created.phoneNormalized, '000000'),
    (error) => error.code === 'invalid_code',
  );
  assert.equal(pool.rows[0].attempts_count, 1);
});

test('maximum attempts blocks further verification', async () => {
  const { service } = fixture({ maxAttempts: 2 });
  const created = await service.createOtpChallenge('87771234567');
  await assert.rejects(service.verifyOtpChallenge(
    created.challengeId, created.phoneNormalized, '000000',
  ));
  await assert.rejects(
    service.verifyOtpChallenge(created.challengeId, created.phoneNormalized, '000001'),
    (error) => error.code === 'max_attempts_reached',
  );
  await assert.rejects(
    service.verifyOtpChallenge(created.challengeId, created.phoneNormalized, created.rawOtp),
    (error) => error.code === 'max_attempts_reached',
  );
});

test('expired challenge is rejected', async () => {
  const { service, advance } = fixture();
  const created = await service.createOtpChallenge('87771234567');
  advance(301);
  await assert.rejects(
    service.verifyOtpChallenge(created.challengeId, created.phoneNormalized, created.rawOtp),
    (error) => error.code === 'challenge_expired',
  );
});

test('resend cooldown rejects an immediate replacement', async () => {
  const { service } = fixture();
  await service.createOtpChallenge('87771234567');
  await assert.rejects(
    service.createOtpChallenge('87771234567'),
    (error) => error.code === 'resend_cooldown',
  );
});

test('replacement invalidates the old challenge', async () => {
  const { service, advance } = fixture();
  const oldChallenge = await service.createOtpChallenge('87771234567');
  advance(61);
  await service.createOtpChallenge('87771234567');
  await assert.rejects(
    service.verifyOtpChallenge(
      oldChallenge.challengeId, oldChallenge.phoneNormalized, oldChallenge.rawOtp,
    ),
    (error) => error.code === 'challenge_consumed',
  );
});

test('malformed OTP code and mismatched phone are rejected', async () => {
  const { service } = fixture();
  const created = await service.createOtpChallenge('87771234567');
  await assert.rejects(service.verifyOtpChallenge(
    created.challengeId, created.phoneNormalized, '12345x',
  ));
  await assert.rejects(
    service.verifyOtpChallenge(created.challengeId, '+77661234567', created.rawOtp),
    (error) => error.code === 'challenge_not_found',
  );
});
