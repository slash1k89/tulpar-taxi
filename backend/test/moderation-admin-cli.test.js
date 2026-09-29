import assert from 'node:assert/strict';
import test from 'node:test';

import {
  parseModerationAdminArgs,
  setModerationAdmin,
} from '../scripts/set-moderation-admin.js';

test('moderation admin arguments accept safe user identifiers', () => {
  assert.deepEqual(
    parseModerationAdminArgs(['add', '--user-id', '11111111-1111-4111-8111-111111111111']),
    { command: 'add', identifier: { userId: '11111111-1111-4111-8111-111111111111' } },
  );
  assert.deepEqual(
    parseModerationAdminArgs(['revoke', '--phone', '8 (700) 123-45-67']),
    { command: 'revoke', identifier: { phone: '+77001234567' } },
  );
});

test('adding an existing active user is idempotent', async () => {
  const calls = [];
  const pool = {
    async query(sql, values) {
      calls.push({ sql, values });
      if (sql.includes('SELECT id FROM users')) {
        return { rowCount: 1, rows: [{ id: 'user-1' }] };
      }
      return { rowCount: 0, rows: [] };
    },
  };
  const result = await setModerationAdmin(pool, {
    command: 'add',
    identifier: { userId: '11111111-1111-4111-8111-111111111111' },
  });
  assert.deepEqual(result, { action: 'add', userId: 'user-1', changed: false });
  assert.match(calls[1].sql, /ON CONFLICT \(user_id\) DO NOTHING/);
});

test('revoking is idempotent and can clean up an existing inactive user', async () => {
  const calls = [];
  const pool = {
    async query(sql) {
      calls.push(sql);
      if (sql.includes('SELECT id FROM users')) {
        assert.doesNotMatch(sql, /account_status = 'active'/);
        return { rowCount: 1, rows: [{ id: 'user-1' }] };
      }
      return { rowCount: 0, rows: [] };
    },
  };
  assert.deepEqual(
    await setModerationAdmin(pool, {
      command: 'revoke',
      identifier: { userId: '11111111-1111-4111-8111-111111111111' },
    }),
    { action: 'revoke', userId: 'user-1', changed: false },
  );
  assert.match(calls[1], /DELETE FROM moderation_admins/);
});

test('moderation role cannot be granted to a missing user', async () => {
  const pool = { query: async () => ({ rowCount: 0, rows: [] }) };
  await assert.rejects(
    setModerationAdmin(pool, {
      command: 'add',
      identifier: { userId: '11111111-1111-4111-8111-111111111111' },
    }),
    /active_user_not_found/,
  );
});
