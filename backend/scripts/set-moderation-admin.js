import { pathToFileURL } from 'node:url';

import pg from 'pg';

import { normalizeKazakhstanPhone } from '../src/auth/phone-normalization.js';

const { Pool } = pg;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const moderationAdminHelp = `Usage:
  node scripts/set-moderation-admin.js add --user-id <uuid>
  node scripts/set-moderation-admin.js add --phone <+7...>
  node scripts/set-moderation-admin.js revoke --user-id <uuid>
  node scripts/set-moderation-admin.js revoke --phone <+7...>
  node scripts/set-moderation-admin.js list

The target must already be an active Tulpar user. Database credentials are read
from the standard DB_HOST, DB_PORT, POSTGRES_DB, POSTGRES_USER and
POSTGRES_PASSWORD environment variables.`;

export function parseModerationAdminArgs(argv) {
  const [command, flag, value] = argv;
  if (command === 'list' && argv.length === 1) return { command };
  if (!['add', 'revoke'].includes(command) || !['--user-id', '--phone'].includes(flag) || !value || argv.length !== 3) {
    throw new Error('invalid_arguments');
  }
  if (flag === '--user-id' && !UUID_PATTERN.test(value)) {
    throw new Error('invalid_user_id');
  }
  return { command, identifier: flag === '--user-id' ? { userId: value } : { phone: normalizeKazakhstanPhone(value) } };
}

export async function resolveModerationUser(pool, identifier, { requireActive = true } = {}) {
  const activeClause = requireActive ? "AND u.account_status = 'active'" : '';
  const result = identifier.userId
    ? await pool.query(
      `SELECT id FROM users u WHERE id = $1 ${activeClause} LIMIT 1`,
      [identifier.userId],
    )
    : await pool.query(
      `SELECT u.id
         FROM auth_phone_identities i
         JOIN users u ON u.id = i.user_id
        WHERE i.phone_normalized = $1 ${activeClause}
        LIMIT 1`,
      [identifier.phone],
    );
  if (result.rowCount !== 1) {
    throw new Error(requireActive ? 'active_user_not_found' : 'user_not_found');
  }
  return result.rows[0].id;
}

export async function setModerationAdmin(pool, { command, identifier }) {
  const userId = await resolveModerationUser(pool, identifier, {
    requireActive: command === 'add',
  });
  const result = command === 'add'
    ? await pool.query(
      `INSERT INTO moderation_admins (user_id)
       VALUES ($1) ON CONFLICT (user_id) DO NOTHING RETURNING user_id`,
      [userId],
    )
    : await pool.query(
      `DELETE FROM moderation_admins WHERE user_id = $1 RETURNING user_id`,
      [userId],
    );
  return { action: command, userId, changed: result.rowCount === 1 };
}

export async function listModerationAdmins(pool) {
  const result = await pool.query(
    `SELECT user_id, granted_at FROM moderation_admins ORDER BY granted_at, user_id`,
  );
  return result.rows.map((row) => ({
    userId: row.user_id,
    grantedAt: row.granted_at,
  }));
}

export async function runModerationAdminCli(argv, { pool, output = console.log } = {}) {
  if (argv.includes('--help') || argv.includes('-h')) {
    output(moderationAdminHelp);
    return;
  }
  const parsed = parseModerationAdminArgs(argv);
  const result = parsed.command === 'list'
    ? await listModerationAdmins(pool)
    : await setModerationAdmin(pool, parsed);
  output(JSON.stringify(result, null, 2));
}

function createPool() {
  return new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
  });
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const pool = createPool();
  try {
    await runModerationAdminCli(process.argv.slice(2), { pool });
  } catch (error) {
    if (error?.message === 'invalid_arguments') console.error(moderationAdminHelp);
    else console.error(error?.message ?? 'Moderation admin operation failed');
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}
