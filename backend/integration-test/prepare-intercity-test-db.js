import { readFile } from 'node:fs/promises';

import {
  assertConnectedToSafeTestDatabase,
  createIntegrationPool,
  splitSqlStatements,
  stripPsqlMetaCommands,
} from './test-db.js';

const expectedDatabase = String(process.env.POSTGRES_DB ?? '').trim();
const pool = createIntegrationPool('tulpar-intercity-prepare');

async function readProjectFile(relativePath) {
  return readFile(new URL(relativePath, import.meta.url), 'utf8');
}

async function assertEmptyPreflight(relativePath) {
  const sql = await readProjectFile(relativePath);
  for (const statement of splitSqlStatements(sql)) {
    const result = await pool.query(statement);
    if (result.rows.length !== 0) {
      throw new Error(
        `Preflight ${relativePath} returned ${result.rows.length} row(s)`,
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
    ]],
  );
  if (objects.rowCount !== 5) {
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
    ],
    tables: objects.rows.map((row) => row.table_name),
  }));
} finally {
  await pool.end();
}
