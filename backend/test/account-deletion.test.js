import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import {
  MAX_RETRY_ATTEMPTS,
  attemptFirebaseDeletion,
  beginAccountDeletion,
  claimAccountDeletionJob,
  firebaseUidHash,
  hasRecentAuthentication,
  isDeletedFirebaseUid,
  processClaimedFirebaseDeletion,
  retryPendingAccountDeletions,
} from '../src/account-deletion.js';
import { createAccountRouter } from '../src/routes/account.js';

const nowSeconds = 2_000_000_000;

function createApp({
  authTime = nowSeconds,
  beginDeletion = async () => ({
    kind: 'created',
    job: { id: 'job-1', user_id: 'user-1', firebase_uid: 'firebase-1', status: 'pending' },
  }),
  attemptDeletion = async () => ({ completed: true }),
  authenticated = true,
} = {}) {
  const app = express();
  app.use(express.json());
  const requireAuth = (req, res, next) => {
    if (!authenticated || req.headers.authorization !== 'Bearer test') {
      return res.status(401).json({ error: 'Missing authorization token' });
    }
    req.user = { uid: 'firebase-1', authTime };
    next();
  };
  app.use('/api/account', createAccountRouter({
    pool: {},
    requireAuth,
    deleteFirebaseUser: async () => {},
    nowSeconds: () => nowSeconds,
    beginDeletion,
    attemptDeletion,
  }));
  return app;
}

test('account deletion requires authentication', async () => {
  const response = await request(createApp({ authenticated: false }))
    .delete('/api/account');
  assert.equal(response.status, 401);
});

for (const [name, authTime] of [
  ['old', nowSeconds - 301],
  ['missing', null],
  ['invalid', 'not-a-number'],
]) {
  test(`${name} auth_time fails closed`, async () => {
    let began = false;
    const response = await request(createApp({
      authTime,
      beginDeletion: async () => {
        began = true;
      },
    })).delete('/api/account').set('Authorization', 'Bearer test');
    assert.equal(response.status, 401);
    assert.equal(response.body.code, 'recent_login_required');
    assert.equal(began, false);
  });
}

test('fresh auth_time allows deletion validation', async () => {
  const response = await request(createApp())
    .delete('/api/account')
    .set('Authorization', 'Bearer test');
  assert.equal(response.status, 200);
  assert.deepEqual(response.body, { status: 'deleted' });
});

test('body cannot override uid or auth_time and unknown fields are rejected', async () => {
  let began = false;
  const response = await request(createApp({
    beginDeletion: async () => {
      began = true;
    },
  }))
    .delete('/api/account')
    .set('Authorization', 'Bearer test')
    .send({ uid: 'victim', userId: 'victim', auth_time: nowSeconds });
  assert.equal(response.status, 400);
  assert.equal(response.body.code, 'invalid_request');
  assert.equal(began, false);
});

for (const code of [
  'active_order',
  'active_driver_order',
  'active_ride',
  'active_booking',
  'active_ride_request',
]) {
  test(`${code} returns a stable 409 blocker`, async () => {
    let firebaseCalls = 0;
    const response = await request(createApp({
      beginDeletion: async () => ({ kind: 'blocked', code }),
      attemptDeletion: async () => {
        firebaseCalls++;
      },
    })).delete('/api/account').set('Authorization', 'Bearer test');
    assert.equal(response.status, 409);
    assert.equal(response.body.code, code);
    assert.equal(firebaseCalls, 0);
  });
}

test('database failure returns stable error and never calls Firebase', async () => {
  let firebaseCalls = 0;
  const response = await request(createApp({
    beginDeletion: async () => { throw new Error('database detail with PII'); },
    attemptDeletion: async () => {
      firebaseCalls++;
    },
  })).delete('/api/account').set('Authorization', 'Bearer test');
  assert.equal(response.status, 500);
  assert.equal(response.body.code, 'account_deletion_failed');
  assert.doesNotMatch(JSON.stringify(response.body), /database detail|firebase-1/);
  assert.equal(firebaseCalls, 0);
});

test('Firebase deletion is invoked only after deletion transaction completes', async () => {
  const events = [];
  const response = await request(createApp({
    beginDeletion: async () => {
      events.push('database_commit');
      return {
        kind: 'created',
        job: { id: 'job-1', firebase_uid: 'firebase-1', status: 'pending' },
      };
    },
    attemptDeletion: async () => {
      events.push('firebase_delete');
      return { completed: true };
    },
  })).delete('/api/account').set('Authorization', 'Bearer test');
  assert.equal(response.status, 200);
  assert.deepEqual(events, ['database_commit', 'firebase_delete']);
});

test('anonymization SQL failure rolls back the whole transaction', async () => {
  const statements = [];
  let released = false;
  const client = {
    async query(sql) {
      const normalized = sql.trim();
      statements.push(normalized);
      if (normalized === 'BEGIN' || normalized === 'ROLLBACK') return { rowCount: 0, rows: [] };
      if (normalized.startsWith('SELECT id FROM users')) {
        return { rowCount: 1, rows: [{ id: 'user-1' }] };
      }
      if (normalized.startsWith('SELECT 1')) return { rowCount: 0, rows: [] };
      if (normalized.startsWith('INSERT INTO account_deletion_jobs')) {
        return {
          rowCount: 1,
          rows: [{ id: 'job-1', user_id: 'user-1', firebase_uid: 'firebase-1', status: 'pending' }],
        };
      }
      if (normalized.startsWith('DELETE FROM user_push_tokens')) {
        throw new Error('fixture transaction failure');
      }
      return { rowCount: 0, rows: [] };
    },
    release() { released = true; },
  };
  await assert.rejects(
    beginAccountDeletion({
      pool: { connect: async () => client },
      firebaseUid: 'firebase-1',
    }),
    /fixture transaction failure/,
  );
  assert.ok(statements.includes('ROLLBACK'));
  assert.equal(statements.includes('COMMIT'), false);
  assert.equal(released, true);
});

test('Firebase retryable failure returns deletion_pending', async () => {
  const response = await request(createApp({
    attemptDeletion: async () => ({ completed: false }),
  })).delete('/api/account').set('Authorization', 'Bearer test');
  assert.equal(response.status, 202);
  assert.deepEqual(response.body, { status: 'deletion_pending' });
});

test('terminal failed deletion does not return a retryable 202', async () => {
  const response = await request(createApp({
    beginDeletion: async () => ({
      kind: 'existing',
      job: { id: 'job-1', status: 'failed', firebase_uid: 'firebase-1' },
    }),
  })).delete('/api/account').set('Authorization', 'Bearer test');
  assert.equal(response.status, 503);
  assert.equal(
    response.body.code,
    'account_deletion_manual_recovery_required',
  );
});

test('completed repeated deletion is idempotent and skips Firebase', async () => {
  let firebaseCalls = 0;
  const response = await request(createApp({
    beginDeletion: async () => ({
      kind: 'existing',
      job: { id: 'job-1', status: 'completed', firebase_uid: null },
    }),
    attemptDeletion: async () => {
      firebaseCalls++;
    },
  })).delete('/api/account').set('Authorization', 'Bearer test');
  assert.equal(response.status, 200);
  assert.equal(firebaseCalls, 0);
});

test('Firebase user-not-found completes deletion idempotently', async () => {
  const queries = [];
  const outcome = await attemptFirebaseDeletion({
    pool: {
      query: async (...args) => {
        queries.push(args);
        if (args[0].includes('WITH candidate')) {
          return {
            rows: [{
              id: 'job-1',
              firebase_uid: 'firebase-1',
              status: 'pending',
              claim_token: args[1][1],
            }],
          };
        }
        return { rowCount: 1, rows: [] };
      },
    },
    deleteFirebaseUser: async () => {
      const error = new Error('missing');
      error.code = 'auth/user-not-found';
      throw error;
    },
    job: { id: 'job-1', firebase_uid: 'firebase-1', status: 'pending' },
  });
  assert.deepEqual(outcome, { completed: true, status: 'completed' });
  assert.match(queries[1][0], /status = 'completed'/);
});

test('Firebase failure persists only a sanitized retry code', async () => {
  const queries = [];
  const outcome = await attemptFirebaseDeletion({
    pool: {
      query: async (...args) => {
        queries.push(args);
        if (args[0].includes('WITH candidate')) {
          return {
            rows: [{
              id: 'job-1',
              firebase_uid: 'firebase-1',
              status: 'pending',
              claim_token: args[1][1],
            }],
          };
        }
        return { rowCount: 1, rows: [{ status: 'pending' }] };
      },
    },
    deleteFirebaseUser: async () => {
      const error = new Error('secret phone +777');
      error.code = 'auth/internal-error';
      throw error;
    },
    job: { id: 'job-1', firebase_uid: 'firebase-1', status: 'pending' },
  });
  assert.deepEqual(outcome, { completed: false, status: 'pending' });
  assert.equal(queries[1][1][0], 'job-1');
  assert.equal(queries[1][1][1], 20);
  assert.equal(queries[1][1][2], 'auth/internal-error');
  assert.doesNotMatch(JSON.stringify(queries), /secret phone|firebase-1/);
});

test('retry worker continues after one bad claimed job', async () => {
  const jobs = [
    { id: 'bad', user_id: 'user-1', firebase_uid: 'uid-1' },
    { id: 'good', user_id: 'user-2', firebase_uid: 'uid-2' },
  ];
  const completed = [];
  const pool = {
    async query(sql, values) {
      if (sql.includes('WITH candidate')) {
        const job = jobs.shift();
        return {
          rows: job
            ? [{ ...job, status: 'pending', claim_token: values[1] }]
            : [],
        };
      }
      if (sql.includes("status = 'completed'")) {
        if (values[0] === 'bad') throw new Error('database unavailable');
        completed.push(values[0]);
        return { rowCount: 1, rows: [] };
      }
      return { rowCount: 1, rows: [{ status: 'pending' }] };
    },
  };
  const processed = await retryPendingAccountDeletions({
    pool,
    deleteFirebaseUser: async () => {},
    limit: 3,
  });
  assert.equal(processed, 2);
  assert.deepEqual(completed, ['good']);
});

test('durable claim is pending-only, skip-locked and lease-recoverable', async () => {
  let captured;
  const claimed = await claimAccountDeletionJob({
    pool: {
      query: async (sql, values) => {
        captured = { sql, values };
        return {
          rows: [{
            id: 'job-1',
            firebase_uid: 'fixture-uid',
            status: 'pending',
            claim_token: values[1],
          }],
        };
      },
    },
    jobId: '11111111-1111-4111-8111-111111111111',
    leaseSeconds: 90,
  });
  assert.equal(claimed.id, 'job-1');
  assert.match(captured.sql, /status = 'pending'/);
  assert.match(captured.sql, /lease_until IS NULL OR lease_until <= now\(\)/);
  assert.match(captured.sql, /FOR UPDATE SKIP LOCKED/);
  assert.match(captured.sql, /claim_token = \$2::uuid/);
  assert.equal(captured.values[2], 90);
});

test('maximum retry becomes terminal and cannot be automatically reclaimed', async () => {
  const calls = [];
  const pool = {
    query: async (sql, values) => {
      calls.push({ sql, values });
      return { rows: [{ status: 'failed' }], rowCount: 1 };
    },
  };
  const error = new Error('private remote detail');
  error.code = 'auth/internal-error';
  const outcome = await processClaimedFirebaseDeletion({
    pool,
    job: {
      id: 'job-1',
      firebase_uid: 'fixture-uid',
      attempt_count: MAX_RETRY_ATTEMPTS - 1,
      claim_token: '11111111-1111-4111-8111-111111111111',
    },
    deleteFirebaseUser: async () => { throw error; },
  });
  assert.deepEqual(outcome, { completed: false, status: 'failed' });
  assert.match(calls[0].sql, /THEN 'failed' ELSE 'pending'/);
  assert.equal(calls[0].values[1], MAX_RETRY_ATTEMPTS);
  assert.doesNotMatch(JSON.stringify(calls), /private remote detail|fixture-uid/);
});

test('UID hashing is deterministic and does not expose the UID', () => {
  const hash = firebaseUidHash('firebase-1');
  assert.equal(hash.length, 64);
  assert.equal(hash, firebaseUidHash('firebase-1'));
  assert.doesNotMatch(hash, /firebase/);
  assert.equal(hasRecentAuthentication(nowSeconds - 300, { nowSeconds }), true);
});

test('/users/sync tombstone lookup blocks a deleted Firebase UID', async () => {
  let parameter;
  const deleted = await isDeletedFirebaseUid({
    query: async (_sql, values) => {
      parameter = values[0];
      return { rowCount: 1 };
    },
  }, 'firebase-1');
  assert.equal(deleted, true);
  assert.equal(parameter, firebaseUidHash('firebase-1'));
  assert.notEqual(parameter, 'firebase-1');
});
