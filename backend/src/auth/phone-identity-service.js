import { normalizeKazakhstanPhone } from './phone-normalization.js';

export class PhoneIdentityConflictError extends Error {
  constructor() {
    super('phone_identity_conflict');
    this.code = 'phone_identity_conflict';
  }
}

export class PhoneIdentityService {
  constructor({ pool, now = () => new Date() } = {}) {
    if (!pool?.connect) throw new Error('A PostgreSQL pool is required');
    this.pool = pool;
    this.now = now;
  }

  async resolveVerifiedPhone(phone) {
    const normalizedPhone = normalizeKazakhstanPhone(phone);
    const digits = normalizedPhone.slice(1);
    const legacyEightDigits = `8${digits.slice(1)}`;
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
        [`auth-phone:${normalizedPhone}`],
      );
      const mapped = await client.query(
        `SELECT i.user_id
           FROM auth_phone_identities i
           JOIN users u ON u.id = i.user_id
          WHERE i.phone_normalized = $1 AND u.account_status = 'active'
          FOR UPDATE OF i`,
        [normalizedPhone],
      );
      if (mapped.rowCount === 1) {
        await client.query('COMMIT');
        return { userId: mapped.rows[0].user_id, created: false };
      }
      const legacy = await client.query(
        `SELECT id
           FROM users
          WHERE account_status = 'active' AND phone IS NOT NULL
            AND regexp_replace(phone, '[^0-9]', '', 'g') = ANY($1::text[])
          FOR UPDATE`,
        [[digits, legacyEightDigits]],
      );
      if (legacy.rowCount > 1) {
        await client.query('ROLLBACK');
        throw new PhoneIdentityConflictError();
      }
      let userId;
      let created = false;
      if (legacy.rowCount === 1) {
        userId = legacy.rows[0].id;
      } else {
        const inserted = await client.query(
          `INSERT INTO users (
             firebase_uid, phone, name, rating, rating_sum, rating_count
           ) VALUES (NULL, $1, NULL, 5.00, 0, 0)
           RETURNING id`,
          [normalizedPhone],
        );
        userId = inserted.rows[0].id;
        created = true;
      }
      await client.query(
        `INSERT INTO auth_phone_identities (
           phone_normalized, user_id, verified_at
         ) VALUES ($1, $2, $3)`,
        [normalizedPhone, userId, this.now()],
      );
      await client.query('COMMIT');
      return { userId, created };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      throw error;
    } finally {
      client.release();
    }
  }
}
