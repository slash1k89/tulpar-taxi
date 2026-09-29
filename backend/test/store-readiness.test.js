import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';
import { readFile } from 'node:fs/promises';

import { createTermsRouter } from '../src/routes/terms.js';
import { createRequireCurrentTerms, CURRENT_TERMS_VERSION } from '../src/terms-policy.js';
import { createStoreComplianceRouter } from '../src/routes/store-compliance.js';
import { createAccountRouter } from '../src/routes/account.js';
import { canBlockedPairWriteChat } from '../src/block-policy.js';

test('migration 024 is additive and contains store-readiness constraints', async () => {
  const sql = await readFile(new URL(
    '../migrations/20260923_024_store_readiness.sql', import.meta.url,
  ), 'utf8');
  assert.match(sql, /CREATE TABLE public\.user_terms_acceptances/);
  assert.match(sql, /CREATE TABLE public\.user_blocks/);
  assert.match(sql, /CREATE TABLE public\.content_reports/);
  assert.match(sql, /CREATE TABLE public\.moderation_admins/);
  assert.match(sql, /CHECK \(blocker_user_id <> blocked_user_id\)/);
  assert.match(sql, /WHERE status = 'open'/);
  assert.doesNotMatch(sql, /\b(DROP TABLE|TRUNCATE|DELETE FROM|UPDATE public\.)\b/i);
});

test('migration 025 scrubs exact PII without deleting historical orders', async () => {
  const sql = await readFile(new URL(
    '../migrations/20260929_025_account_deletion_privacy_cleanup.sql',
    import.meta.url,
  ), 'utf8');
  assert.match(sql, /ALTER TABLE public\.order_stops/);
  assert.match(sql, /ALTER COLUMN address DROP NOT NULL/);
  assert.match(sql, /UPDATE public\.order_stops/);
  assert.match(sql, /address = NULL, latitude = NULL, longitude = NULL/);
  assert.match(sql, /UPDATE public\.intercity_rides/);
  assert.match(sql, /origin_lat = NULL/);
  assert.match(sql, /DELETE FROM public\.auth_otp_challenges/);
  assert.match(sql, /DELETE FROM public\.auth_password_verifications/);
  assert.doesNotMatch(sql, /DELETE FROM public\.orders\b/);
  assert.doesNotMatch(sql, /DROP TABLE|TRUNCATE/i);
});

test('block preserves active-trip safety chat but denies post-trip chat', () => {
  assert.equal(canBlockedPairWriteChat({ blocked: true, activeTrip: true }), true);
  assert.equal(canBlockedPairWriteChat({ blocked: true, activeTrip: false }), false);
  assert.equal(canBlockedPairWriteChat({ blocked: false, activeTrip: false }), true);
});

function auth(type = 'firebase') {
  return (req, _res, next) => {
    req.user = { uid: type === 'tulpar' ? 'user-1' : 'firebase-1', authTime: 2_000_000_000 };
    req.auth = { type, userId: 'user-1' };
    next();
  };
}

test('current Terms are versioned, persisted, and required again for a new version', async () => {
  const acceptances = new Set();
  const pool = { async query(sql, values) {
    if (sql.includes('SELECT id, account_status FROM users')) {
      return { rowCount: 1, rows: [{ id: 'user-1', account_status: 'active' }] };
    }
    if (sql.includes('SELECT 1 FROM user_terms_acceptances')) {
      return { rowCount: acceptances.has(values[1]) ? 1 : 0, rows: [] };
    }
    if (sql.includes('INSERT INTO user_terms_acceptances')) {
      acceptances.add(values[1]);
      return { rowCount: 1, rows: [{ accepted_at: new Date().toISOString() }] };
    }
    throw new Error(`Unexpected SQL: ${sql}`);
  } };
  const app = express(); app.use(express.json());
  app.use('/api/terms', createTermsRouter({ pool, requireAuth: auth() }));
  let response = await request(app).get('/api/terms/status');
  assert.equal(response.body.accepted, false);
  assert.equal(response.body.currentVersion, CURRENT_TERMS_VERSION);
  await request(app).post('/api/terms/accept').send({ version: 'old' }).expect(409);
  await request(app).post('/api/terms/accept')
    .send({ version: CURRENT_TERMS_VERSION }).expect(200);
  response = await request(app).get('/api/terms/status');
  assert.equal(response.body.accepted, true);
  assert.equal(acceptances.has('future-version'), false);
});

test('UGC middleware rejects publishing without current Terms', async () => {
  const pool = { async query(sql) {
    if (sql.includes('SELECT id, account_status FROM users')) {
      return { rowCount: 1, rows: [{ id: 'user-1', account_status: 'active' }] };
    }
    return { rowCount: 0, rows: [] };
  } };
  const app = express();
  app.post('/ugc', auth(), createRequireCurrentTerms({ pool }), (_req, res) => res.sendStatus(201));
  const response = await request(app).post('/ugc').expect(403);
  assert.equal(response.body.code, 'terms_acceptance_required');
});

test('report, block, and admin moderation use authenticated ownership', async () => {
  const reports = [];
  const blocks = new Set();
  const pool = { async query(sql, values = []) {
    if (sql.includes('SELECT id, account_status FROM users')) {
      return { rowCount: 1, rows: [{ id: 'user-1', account_status: 'active' }] };
    }
    if (sql.includes('FROM orders') && sql.includes('UNION ALL')) return { rowCount: 1, rows: [{}] };
    if (sql.includes('INSERT INTO content_reports')) {
      reports.push({ id: 'report-1', status: 'open' });
      return { rowCount: 1, rows: [{ id: 'report-1', status: 'open', created_at: new Date() }] };
    }
    if (sql.includes('INSERT INTO user_blocks')) {
      blocks.add(`${values[0]}:${values[1]}`); return { rowCount: 1, rows: [] };
    }
    if (sql.includes('FROM moderation_admins')) return { rowCount: 0, rows: [] };
    throw new Error(`Unexpected SQL: ${sql}`);
  } };
  const app = express(); app.use(express.json());
  app.use('/api/compliance', createStoreComplianceRouter({
    pool, requireAuth: auth(), requireCurrentTerms: (_req, _res, next) => next(),
  }));
  await request(app).post('/api/compliance/reports').send({
    reportedUserId: 'user-2', contextType: 'city_chat', reasonCode: 'spam', orderId: 'order-1',
  }).expect(201);
  await request(app).post('/api/compliance/blocks')
    .send({ blockedUserId: 'user-2' }).expect(201);
  assert.equal(reports.length, 1);
  assert.equal(blocks.has('user-1:user-2'), true);
  const admin = await request(app).get('/api/compliance/admin/reports');
  assert.equal(admin.status, 403);
  assert.equal(admin.body.code, 'admin_required');
});

test('Tulpar password session deletes with current password and never requests Flash Call', async () => {
  let deletedUserId;
  const pool = { async query(sql) {
    if (sql.includes('SELECT password_hash FROM users')) {
      return { rowCount: 1, rows: [{ password_hash: 'encoded' }] };
    }
    throw new Error(`Unexpected SQL: ${sql}`);
  } };
  const app = express(); app.use(express.json());
  app.use('/api/account', createAccountRouter({
    pool,
    requireAuth: auth('tulpar'),
    deleteFirebaseUser: async () => {},
    passwordVerifier: async (password, encoded) => password === 'correct-pass' && encoded === 'encoded',
    beginPasswordDeletion: async ({ userId }) => {
      deletedUserId = userId;
      return { kind: 'created', job: { status: 'completed' } };
    },
  }));
  await request(app).delete('/api/account').send({ password: 'wrong-pass' }).expect(401);
  const response = await request(app).delete('/api/account')
    .send({ password: 'correct-pass' }).expect(200);
  assert.equal(response.body.status, 'deleted');
  assert.equal(deletedUserId, 'user-1');
});
