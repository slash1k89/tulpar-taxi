import assert from 'node:assert/strict';
import test from 'node:test';

import { cleanupExpiredAuthHistory } from '../src/auth/auth-history-cleanup.js';

test('expired auth cleanup preserves active password and resend windows', async () => {
  const calls = [];
  const pool = {
    async query(sql, values) {
      calls.push({ sql, values });
      return { rowCount: calls.length, rows: [] };
    },
  };
  const now = new Date('2026-09-29T10:00:00.000Z');
  const result = await cleanupExpiredAuthHistory({ pool, now, limit: 25 });

  assert.deepEqual(result, {
    passwordVerifications: 1,
    otpChallenges: 2,
    sessions: 3,
  });
  assert.equal(calls.length, 3);
  assert.match(calls[0].sql, /consumed_at IS NOT NULL OR expires_at <= \$1/);
  assert.match(calls[1].sql, /c\.expires_at <= \$1/);
  assert.match(calls[1].sql, /c\.resend_available_at <= \$1/);
  assert.match(calls[1].sql, /NOT EXISTS[\s\S]*auth_password_verifications/);
  assert.match(calls[2].sql, /auth_sessions[\s\S]*expires_at <= \$1/);
  for (const call of calls) assert.deepEqual(call.values, [now, 25]);
});

test('expired auth cleanup rejects an unsafe batch size', async () => {
  await assert.rejects(
    cleanupExpiredAuthHistory({ pool: { query: async () => ({}) }, limit: 0 }),
    /batch size/,
  );
});
