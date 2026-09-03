import pg from 'pg';

import { DriverWhitelistService } from '../driver-whitelist.js';

const { Pool } = pg;
const [command, phone] = process.argv.slice(2);

if (!['add', 'list', 'remove'].includes(command) || (command !== 'list' && !phone)) {
  console.error('Usage: node src/admin/driver-whitelist-cli.js <add|list|remove> [phone]');
  process.exitCode = 2;
} else {
  const pool = new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
  });
  try {
    const whitelist = new DriverWhitelistService(pool);
    const result = command === 'list'
      ? await whitelist.list()
      : await whitelist[command](phone);
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error(error?.message ?? 'Whitelist operation failed');
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}
