import assert from 'node:assert/strict';
import test from 'node:test';

import { acquireAccountLifecycleLock } from '../src/account-lifecycle.js';
import { syncActiveUser } from '../src/user-sync.js';

function mockPool(query) {
  let released = false;
  const client = {
    query,
    release() {
      released = true;
    },
  };
  return {
    pool: { connect: async () => client },
    get released() {
      return released;
    },
  };
}

test('lifecycle advisory key is deterministic and never sends raw UID', async () => {
  const calls = [];
  const client = {
    query: async (sql, values) => {
      calls.push({ sql, values });
      return { rows: [], rowCount: 0 };
    },
  };
  await acquireAccountLifecycleLock(client, 'private-firebase-uid');
  await acquireAccountLifecycleLock(client, 'private-firebase-uid');
  assert.deepEqual(calls[0].values, calls[1].values);
  assert.equal(calls[0].values.length, 2);
  assert.doesNotMatch(JSON.stringify(calls[0].values), /private-firebase-uid/);
});

test('user sync checks tombstone under lifecycle lock and rolls back', async () => {
  const statements = [];
  const fixture = mockPool(async (sql) => {
    const normalized = sql.trim();
    statements.push(normalized);
    if (normalized.startsWith('SELECT id, name, phone, account_status')) {
      return { rows: [], rowCount: 0 };
    }
    if (normalized.startsWith('SELECT 1 FROM account_deletion_jobs')) {
      return { rows: [{ exists: 1 }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  });
  const result = await syncActiveUser({
    pool: fixture.pool,
    firebaseUid: 'deleted-uid',
    phone: '+70000000000',
    name: 'Deleted',
  });
  assert.deepEqual(result, { kind: 'deleted' });
  assert.equal(statements[0], 'BEGIN');
  assert.match(statements[1], /pg_advisory_xact_lock/);
  assert.equal(statements.some((sql) => sql.startsWith('INSERT INTO users')), false);
  assert.equal(statements.at(-1), 'ROLLBACK');
  assert.equal(fixture.released, true);
});

test('user sync commits active upsert while lifecycle lock is held', async () => {
  const statements = [];
  const fixture = mockPool(async (sql) => {
    const normalized = sql.trim();
    statements.push(normalized);
    if (normalized.startsWith('SELECT id, name, phone, account_status')) {
      return {
        rows: [{ id: 'user-1', account_status: 'active' }],
        rowCount: 1,
      };
    }
    if (normalized.startsWith('INSERT INTO users')) {
      return {
        rows: [{ id: 'user-1', firebase_uid: 'active-uid' }],
        rowCount: 1,
      };
    }
    return { rows: [], rowCount: 0 };
  });
  const result = await syncActiveUser({
    pool: fixture.pool,
    firebaseUid: 'active-uid',
    phone: '+70000000001',
    name: 'Active',
  });
  assert.equal(result.kind, 'active');
  assert.equal(statements[0], 'BEGIN');
  assert.match(statements[1], /pg_advisory_xact_lock/);
  assert.match(statements.at(-2), /INSERT INTO users/);
  assert.equal(statements.at(-1), 'COMMIT');
  assert.equal(fixture.released, true);
});
