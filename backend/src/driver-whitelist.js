import { normalizeKazakhstanPhone } from './auth/phone-normalization.js';

export class DriverWhitelistService {
  constructor(pool) {
    this.pool = pool;
  }

  async add(phone) {
    const phoneNormalized = normalizeKazakhstanPhone(phone);
    const result = await this.pool.query(
      `INSERT INTO driver_phone_whitelist (phone_normalized)
       VALUES ($1)
       ON CONFLICT (phone_normalized) DO NOTHING
       RETURNING phone_normalized, created_at`,
      [phoneNormalized],
    );
    return { phoneNormalized, added: result.rowCount === 1 };
  }

  async list() {
    const result = await this.pool.query(
      `SELECT phone_normalized, created_at
       FROM driver_phone_whitelist
       ORDER BY created_at, phone_normalized`,
    );
    return result.rows;
  }

  async remove(phone) {
    const phoneNormalized = normalizeKazakhstanPhone(phone);
    const result = await this.pool.query(
      `DELETE FROM driver_phone_whitelist
       WHERE phone_normalized = $1
       RETURNING phone_normalized`,
      [phoneNormalized],
    );
    return { phoneNormalized, removed: result.rowCount === 1 };
  }

  async has(phone) {
    const phoneNormalized = normalizeKazakhstanPhone(phone);
    const result = await this.pool.query(
      `SELECT EXISTS (
         SELECT 1 FROM driver_phone_whitelist
         WHERE phone_normalized = $1
       ) AS allowed`,
      [phoneNormalized],
    );
    return result.rows[0]?.allowed === true;
  }
}
