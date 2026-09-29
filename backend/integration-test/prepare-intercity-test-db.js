import { readFile } from 'node:fs/promises';

import {
  assertConnectedToSafeTestDatabase,
  createIntegrationPool,
  splitSqlStatements,
  stripPsqlMetaCommands,
} from './test-db.js';

const expectedDatabase = String(process.env.POSTGRES_DB ?? '').trim();
const requestedLastMigration = String(
  process.env.INTEGRATION_LAST_MIGRATION
    ?? '20260929_025_account_deletion_privacy_cleanup.sql',
).trim();
const pool = createIntegrationPool('tulpar-intercity-prepare');

async function readProjectFile(relativePath) {
  return readFile(new URL(relativePath, import.meta.url), 'utf8');
}

async function assertEmptyPreflight(relativePath) {
  const sql = await readProjectFile(relativePath);
  const statements = splitSqlStatements(sql);
  for (const [index, statement] of statements.entries()) {
    const result = await pool.query(statement);
    if (result.rows.length !== 0) {
      throw new Error(
        `Preflight ${relativePath} statement ${index + 1} returned `
        + `${result.rows.length} row(s): ${JSON.stringify(result.rows[0])}`,
      );
    }
  }
}

async function apply(relativePath, { stripMeta = false } = {}) {
  const source = await readProjectFile(relativePath);
  await pool.query(stripMeta ? stripPsqlMetaCommands(source) : source);
}

try {
  const identity = await assertConnectedToSafeTestDatabase(
    pool,
    expectedDatabase,
  );
  await pool.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public');
  await apply('../../tulpar-schema.sql', { stripMeta: true });
  // pg_dump intentionally clears search_path. Production migrations run in
  // fresh sessions, so restore the normal migration search path in this
  // long-lived integration-test session before applying unqualified DDL.
  await pool.query('SET search_path TO "$user", public');

  await assertEmptyPreflight(
    '../migrations/preflight/20260825_001_security_hardening_1b_preflight.sql',
  );
  await apply('../migrations/20260825_001_security_hardening_1b.sql');
  await assertEmptyPreflight(
    '../migrations/preflight/20260825_002_intercity_rides_preflight.sql',
  );
  await apply('../migrations/20260825_002_intercity_rides.sql');
  await assertEmptyPreflight(
    '../migrations/preflight/20260826_003_intercity_pickup_points_preflight.sql',
  );
  await apply('../migrations/20260826_003_intercity_pickup_points.sql');
  await assertEmptyPreflight(
    '../migrations/preflight/20260827_004_account_deletion_preflight.sql',
  );
  await apply('../migrations/20260827_004_account_deletion.sql');
  const laterMigrations = [
    '20260830_005_driver_approaching_notification.sql',
    '20260830_006_queued_city_orders.sql',
    '20260830_007_auth_sessions.sql',
    '20260830_008_auth_otp_challenges.sql',
    '20260830_009_auth_phone_identities.sql',
    '20260831_010_auth_verification_transports.sql',
    '20260902_011_driver_phone_whitelist.sql',
    '20260903_012_whitelist_access_exempt.sql',
    '20260903_013_driver_approaching_claim.sql',
    '20260907_014_tulpar_places.sql',
    '20260907_015_password_auth.sql',
    '20260907_016_chat_read_state.sql',
    '20260914_017_user_locale.sql',
    '20260914_018_password_verification_purposes.sql',
    '20260915_019_order_stops.sql',
    '20260921_020_intercity_booking_chat.sql',
    '20260921_021_intercity_pickup_reached.sql',
    '20260922_022_city_order_cancellation_audit.sql',
    '20260922_023_multicity.sql',
    '20260923_024_store_readiness.sql',
    '20260929_025_account_deletion_privacy_cleanup.sql',
  ];
  const lastMigrationIndex = laterMigrations.indexOf(requestedLastMigration);
  if (lastMigrationIndex < 0) {
    throw new Error(`Unsupported INTEGRATION_LAST_MIGRATION: ${requestedLastMigration}`);
  }
  const selectedMigrations = laterMigrations.slice(0, lastMigrationIndex + 1);
  for (const migration of selectedMigrations) {
    try {
      await apply(`../migrations/${migration}`);
    } catch (error) {
      throw new Error(`Failed applying ${migration}: ${error.message}`, {
        cause: error,
      });
    }
  }

  const objects = await pool.query(
    `SELECT table_name
       FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name = ANY($1::text[])
      ORDER BY table_name`,
    [[
      'intercity_rides',
      'intercity_ride_bookings',
      'intercity_ride_requests',
      'intercity_ride_request_notifications',
      'account_deletion_jobs',
      'auth_otp_challenges',
      'auth_password_verifications',
      'order_stops',
      'content_reports',
    ]],
  );
  if (objects.rowCount !== 9) {
    throw new Error('Required migrations did not create all tables');
  }

  console.log(JSON.stringify({
    database: identity.database_name,
    serverVersion: identity.server_version,
    preflights: [
      '20260825_001', '20260825_002', '20260826_003', '20260827_004',
    ],
    migrations: [
      '20260825_001', '20260825_002', '20260826_003', '20260827_004',
      ...selectedMigrations.map((name) => name.replace('.sql', '')),
    ],
    tables: objects.rows.map((row) => row.table_name),
  }));
} finally {
  await pool.end();
}
