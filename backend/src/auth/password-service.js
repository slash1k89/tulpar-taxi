import { createHash, randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

import { normalizeKazakhstanPhone } from './phone-normalization.js';

const scrypt = promisify(scryptCallback);
const MIN_PASSWORD = 8;
const MAX_PASSWORD = 128;

export class PasswordAuthError extends Error {
  constructor(code) { super(code); this.code = code; }
}

function validatePassword(password) {
  if (typeof password !== 'string' || password.length < MIN_PASSWORD || password.length > MAX_PASSWORD) {
    throw new PasswordAuthError('invalid_password');
  }
}

export async function hashPassword(password) {
  validatePassword(password);
  const salt = randomBytes(16);
  const derived = await scrypt(password, salt, 64, { N: 16384, r: 8, p: 1 });
  return `scrypt$16384$8$1$${salt.toString('base64url')}$${derived.toString('base64url')}`;
}

export async function verifyPassword(password, encoded) {
  if (typeof password !== 'string' || typeof encoded !== 'string') return false;
  const parts = encoded.split('$');
  if (parts.length !== 6 || parts[0] !== 'scrypt') return false;
  const [, n, r, p, saltText, hashText] = parts;
  const expected = Buffer.from(hashText, 'base64url');
  const actual = await scrypt(password, Buffer.from(saltText, 'base64url'), expected.length, {
    N: Number(n), r: Number(r), p: Number(p),
  });
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

function tokenHash(token) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

export class PasswordAuthService {
  constructor({ pool, now = () => new Date() } = {}) {
    this.pool = pool;
    this.now = now;
  }

  async findVerifiedIdentity(phone) {
    const normalized = normalizeKazakhstanPhone(phone);
    const result = await this.pool.query(
      `SELECT i.user_id, u.password_hash
         FROM auth_phone_identities i JOIN users u ON u.id = i.user_id
        WHERE i.phone_normalized = $1 AND u.account_status = 'active' LIMIT 1`,
      [normalized],
    );
    return result.rows[0] ? { ...result.rows[0], phoneNormalized: normalized } : null;
  }

  async login(phone, password) {
    let identity;
    try { identity = await this.findVerifiedIdentity(phone); } catch (_) { return null; }
    if (!identity?.password_hash) {
      await scrypt(String(password ?? '').slice(0, MAX_PASSWORD), Buffer.alloc(16), 64, {
        N: 16384, r: 8, p: 1,
      });
      return null;
    }
    return await verifyPassword(password, identity.password_hash) ? identity.user_id : null;
  }

  async createVerificationContext({ challengeId, userId, phone, purpose }) {
    const token = randomBytes(32).toString('base64url');
    const expiresAt = new Date(this.now().getTime() + 10 * 60 * 1000);
    await this.pool.query(
      `INSERT INTO auth_password_verifications
         (challenge_id, user_id, phone_normalized, purpose, token_hash, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [challengeId, userId, normalizeKazakhstanPhone(phone), purpose, tokenHash(token), expiresAt],
    );
    return token;
  }

  async setPassword({ verificationToken, purpose, password }) {
    validatePassword(password);
    if (typeof verificationToken !== 'string' || verificationToken.length < 32) {
      throw new PasswordAuthError('verification_required');
    }
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const contextResult = await client.query(
        `SELECT id, user_id FROM auth_password_verifications
          WHERE token_hash = $1 AND purpose = $2 AND consumed_at IS NULL AND expires_at > $3
          FOR UPDATE`,
        [tokenHash(verificationToken), purpose, this.now()],
      );
      const context = contextResult.rows[0];
      if (!context) throw new PasswordAuthError('verification_required');
      const encoded = await hashPassword(password);
      if (purpose === 'setup') {
        const updated = await client.query(
          'UPDATE users SET password_hash = $1, updated_at = $2 WHERE id = $3 AND password_hash IS NULL RETURNING id',
          [encoded, this.now(), context.user_id],
        );
        if (updated.rowCount !== 1) throw new PasswordAuthError('password_already_set');
      } else {
        await client.query('UPDATE users SET password_hash = $1, updated_at = $2 WHERE id = $3', [encoded, this.now(), context.user_id]);
      }
      await client.query('UPDATE auth_password_verifications SET consumed_at = $2 WHERE id = $1', [context.id, this.now()]);
      await client.query('COMMIT');
      return context.user_id;
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch (_) {}
      throw error;
    } finally { client.release(); }
  }
}
