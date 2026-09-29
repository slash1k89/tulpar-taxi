import { pathToFileURL } from 'node:url';

import pg from 'pg';

import { normalizeKazakhstanPhone } from '../src/auth/phone-normalization.js';
import { hashPassword } from '../src/auth/password-service.js';

const { Pool } = pg;

export const reviewAccountsHelp = `Usage:
  REVIEW_PASSENGER_PHONE=+7... REVIEW_PASSENGER_PASSWORD=... \\
  REVIEW_DRIVER_PHONE=+7... REVIEW_DRIVER_PASSWORD=... \\
  node scripts/provision-review-accounts.js --city <city-slug> \\
    --car-model <model> --car-color <color> --car-number <number>

Creates new ordinary phone/password accounts without invoking Flash Call. It
refuses to overwrite an existing phone identity. Passwords are accepted only
through environment variables and are never printed.`;

export function parseReviewAccountArgs(argv, env = process.env) {
  if (argv.includes('--help') || argv.includes('-h')) return { help: true };
  const values = new Map();
  for (let index = 0; index < argv.length; index += 2) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (!flag?.startsWith('--') || !value) throw new Error('invalid_arguments');
    values.set(flag, value.trim());
  }
  const passengerPhone = normalizeKazakhstanPhone(env.REVIEW_PASSENGER_PHONE);
  const driverPhone = normalizeKazakhstanPhone(env.REVIEW_DRIVER_PHONE);
  if (passengerPhone === driverPhone) throw new Error('review_phones_must_differ');
  const passengerPassword = env.REVIEW_PASSENGER_PASSWORD;
  const driverPassword = env.REVIEW_DRIVER_PASSWORD;
  if (!passengerPassword || !driverPassword) throw new Error('review_passwords_required');
  const required = ['--city', '--car-model', '--car-color', '--car-number'];
  for (const flag of required) if (!values.get(flag)) throw new Error('invalid_arguments');
  return {
    passengerPhone,
    passengerPassword,
    driverPhone,
    driverPassword,
    city: values.get('--city'),
    carModel: values.get('--car-model'),
    carColor: values.get('--car-color'),
    carNumber: values.get('--car-number').toUpperCase(),
  };
}

async function assertPhonesUnused(client, phones) {
  const result = await client.query(
    `SELECT phone_normalized FROM auth_phone_identities
      WHERE phone_normalized = ANY($1::varchar[])`,
    [phones],
  );
  if (result.rowCount > 0) throw new Error('review_phone_already_exists');
}

async function insertReviewUser(client, { phone, passwordHash, name }) {
  const inserted = await client.query(
    `INSERT INTO users (firebase_uid, phone, name, password_hash, locale)
     VALUES (NULL, $1, $2, $3, 'ru') RETURNING id`,
    [phone, name, passwordHash],
  );
  const userId = inserted.rows[0].id;
  await client.query(
    `INSERT INTO auth_phone_identities (phone_normalized, user_id)
     VALUES ($1, $2)`,
    [phone, userId],
  );
  return userId;
}

export async function provisionReviewAccounts(pool, options) {
  const passengerHash = await hashPassword(options.passengerPassword);
  const driverHash = await hashPassword(options.driverPassword);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `SELECT pg_advisory_xact_lock(hashtextextended('tulpar-review-account-provisioning', 0))`,
    );
    await assertPhonesUnused(client, [options.passengerPhone, options.driverPhone]);
    const city = await client.query(
      `SELECT id FROM cities WHERE slug = $1 AND is_enabled = TRUE LIMIT 1`,
      [options.city],
    );
    if (city.rowCount !== 1) throw new Error('enabled_city_not_found');
    const passengerUserId = await insertReviewUser(client, {
      phone: options.passengerPhone,
      passwordHash: passengerHash,
      name: 'Store Review Passenger',
    });
    const driverUserId = await insertReviewUser(client, {
      phone: options.driverPhone,
      passwordHash: driverHash,
      name: 'Store Review Driver',
    });
    await client.query(
      `INSERT INTO driver_profiles (
         user_id, status, car_model, car_color, car_number,
         agreement_version, agreement_accepted_at, work_city_id
       ) VALUES ($1, 'active', $2, $3, $4, '1.0', now(), $5)`,
      [driverUserId, options.carModel, options.carColor, options.carNumber, city.rows[0].id],
    );
    await client.query('COMMIT');
    return { passengerUserId, driverUserId, city: options.city };
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    throw error;
  } finally {
    client.release();
  }
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
    const options = parseReviewAccountArgs(process.argv.slice(2));
    if (options.help) console.log(reviewAccountsHelp);
    else {
      const result = await provisionReviewAccounts(pool, options);
      console.log(JSON.stringify(result, null, 2));
    }
  } catch (error) {
    if (error?.message === 'invalid_arguments') console.error(reviewAccountsHelp);
    else console.error(error?.message ?? 'Review account provisioning failed');
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}
