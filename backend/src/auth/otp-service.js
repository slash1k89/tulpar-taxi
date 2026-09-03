import {
  createHmac,
  randomInt,
  randomUUID,
  timingSafeEqual,
} from 'node:crypto';

import { normalizeKazakhstanPhone } from './phone-normalization.js';

export const DEFAULT_OTP_TTL_SECONDS = 300;
export const DEFAULT_OTP_MAX_ATTEMPTS = 5;
export const DEFAULT_OTP_RESEND_COOLDOWN_SECONDS = 60;

export class OtpChallengeError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

function integerSetting(value, fallback, min, max, name) {
  if (value === undefined || value === '') return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < min || parsed > max) {
    throw new Error(`${name} must be an integer from ${min} to ${max}`);
  }
  return parsed;
}

function resolveSecret(secret = process.env.TULPAR_AUTH_OTP_SECRET) {
  if (typeof secret !== 'string' || secret.length < 32) {
    throw new Error('TULPAR_AUTH_OTP_SECRET must contain at least 32 characters');
  }
  return secret;
}

function otpHash({ challengeId, phone, purpose, method = 'sms', code, secret }) {
  const scope = method === 'sms'
    ? `${challengeId}:${phone}:${purpose}:${code}`
    : `${challengeId}:${phone}:${purpose}:${method}:${code}`;
  return createHmac('sha256', secret)
    .update(scope, 'utf8')
    .digest('hex');
}

function safeHashEqual(left, right) {
  const leftBytes = Buffer.from(left, 'hex');
  const rightBytes = Buffer.from(right, 'hex');
  return leftBytes.length === rightBytes.length &&
    timingSafeEqual(leftBytes, rightBytes);
}

function validateCode(code, method = 'sms') {
  const pattern = method === 'flash_call' ? /^\d{4}$/ : /^\d{6}$/;
  if (typeof code !== 'string' || !pattern.test(code)) {
    throw new OtpChallengeError('invalid_code');
  }
}

export class OtpChallengeService {
  constructor({
    pool,
    secret,
    ttlSeconds = process.env.TULPAR_AUTH_OTP_TTL,
    maxAttempts = process.env.TULPAR_AUTH_OTP_MAX_ATTEMPTS,
    resendCooldownSeconds = process.env.TULPAR_AUTH_OTP_RESEND_COOLDOWN,
    now = () => new Date(),
    generateId = randomUUID,
    generateCode = () => String(randomInt(0, 1_000_000)).padStart(6, '0'),
  } = {}) {
    if (!pool?.connect) throw new Error('A PostgreSQL pool is required');
    this.pool = pool;
    this.secret = resolveSecret(secret);
    this.ttlSeconds = integerSetting(
      ttlSeconds, DEFAULT_OTP_TTL_SECONDS, 60, 1800, 'TULPAR_AUTH_OTP_TTL',
    );
    this.maxAttempts = integerSetting(
      maxAttempts, DEFAULT_OTP_MAX_ATTEMPTS, 1, 20,
      'TULPAR_AUTH_OTP_MAX_ATTEMPTS',
    );
    this.resendCooldownSeconds = integerSetting(
      resendCooldownSeconds, DEFAULT_OTP_RESEND_COOLDOWN_SECONDS, 1, 3600,
      'TULPAR_AUTH_OTP_RESEND_COOLDOWN',
    );
    this.now = now;
    this.generateId = generateId;
    this.generateCode = generateCode;
  }

  async createOtpChallenge(phone, metadata = {}) {
    const normalizedPhone = normalizeKazakhstanPhone(phone);
    const purpose = 'login';
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
        [`otp:${purpose}:${normalizedPhone}`],
      );
      const currentTime = this.now();
      const recent = await client.query(
        `SELECT resend_available_at
           FROM auth_otp_challenges
          WHERE phone_normalized = $1 AND purpose = $2
            AND consumed_at IS NULL
          ORDER BY created_at DESC
          LIMIT 1`,
        [normalizedPhone, purpose],
      );
      if (recent.rows[0]?.resend_available_at > currentTime) {
        await client.query('ROLLBACK');
        throw new OtpChallengeError('resend_cooldown');
      }
      await client.query(
        `UPDATE auth_otp_challenges
            SET consumed_at = $3
          WHERE phone_normalized = $1 AND purpose = $2
            AND consumed_at IS NULL`,
        [normalizedPhone, purpose, currentTime],
      );
      const challengeId = this.generateId();
      const rawOtp = this.generateCode();
      validateCode(rawOtp);
      const expiresAt = new Date(currentTime.getTime() + this.ttlSeconds * 1000);
      const resendAvailableAt = new Date(
        currentTime.getTime() + this.resendCooldownSeconds * 1000,
      );
      await client.query(
        `INSERT INTO auth_otp_challenges (
           id, phone_normalized, code_hash, purpose, created_at, expires_at,
           max_attempts, resend_available_at, request_ip, device_id
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          challengeId,
          normalizedPhone,
          otpHash({
            challengeId,
            phone: normalizedPhone,
            purpose,
            code: rawOtp,
            secret: this.secret,
          }),
          purpose,
          currentTime,
          expiresAt,
          this.maxAttempts,
          resendAvailableAt,
          metadata.requestIp ?? null,
          metadata.deviceId ?? null,
        ],
      );
      await client.query('COMMIT');
      return {
        challengeId,
        phoneNormalized: normalizedPhone,
        rawOtp,
        expiresAt,
        resendAvailableAt,
      };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      throw error;
    } finally {
      client.release();
    }
  }

  async createExternalChallenge(phone, {
    method,
    provider,
    requestCode,
    metadata = {},
  } = {}) {
    const normalizedPhone = normalizeKazakhstanPhone(phone);
    if (method !== 'flash_call' || provider !== 'autocall') {
      throw new OtpChallengeError('unsupported_method');
    }
    if (typeof requestCode !== 'function') {
      throw new OtpChallengeError('provider_unavailable');
    }
    const purpose = 'login';
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
        [`verification:${purpose}:${method}:${normalizedPhone}`],
      );
      const currentTime = this.now();
      const recent = await client.query(
        `SELECT resend_available_at
           FROM auth_otp_challenges
          WHERE phone_normalized = $1 AND purpose = $2 AND method = $3
            AND consumed_at IS NULL
          ORDER BY created_at DESC
          LIMIT 1`,
        [normalizedPhone, purpose, method],
      );
      if (recent.rows[0]?.resend_available_at > currentTime) {
        throw new OtpChallengeError('resend_cooldown');
      }
      const providerResult = await requestCode(normalizedPhone);
      const rawCode = providerResult?.code;
      validateCode(rawCode, method);
      if (
        providerResult?.provider !== provider ||
        typeof providerResult?.providerRequestId !== 'string' ||
        providerResult.providerRequestId.length === 0 ||
        providerResult.providerRequestId.length > 200
      ) {
        throw new OtpChallengeError('invalid_provider_response');
      }
      await client.query(
        `UPDATE auth_otp_challenges
            SET consumed_at = $4
          WHERE phone_normalized = $1 AND purpose = $2 AND method = $3
            AND consumed_at IS NULL`,
        [normalizedPhone, purpose, method, currentTime],
      );
      const challengeId = this.generateId();
      const expiresAt = new Date(currentTime.getTime() + this.ttlSeconds * 1000);
      const resendAvailableAt = new Date(
        currentTime.getTime() + this.resendCooldownSeconds * 1000,
      );
      await client.query(
        `INSERT INTO auth_otp_challenges (
           id, phone_normalized, code_hash, purpose, method, provider,
           provider_request_id, created_at, expires_at, max_attempts,
           resend_available_at, request_ip, device_id
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
        [
          challengeId,
          normalizedPhone,
          otpHash({
            challengeId,
            phone: normalizedPhone,
            purpose,
            method,
            code: rawCode,
            secret: this.secret,
          }),
          purpose,
          method,
          provider,
          providerResult.providerRequestId,
          currentTime,
          expiresAt,
          this.maxAttempts,
          resendAvailableAt,
          metadata.requestIp ?? null,
          metadata.deviceId ?? null,
        ],
      );
      await client.query('COMMIT');
      return {
        challengeId,
        phoneNormalized: normalizedPhone,
        method,
        expiresAt,
        resendAvailableAt,
      };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      throw error;
    } finally {
      client.release();
    }
  }

  async verifyOtpChallenge(challengeId, phone, code) {
    return this.verifyChallenge(challengeId, phone, code, { method: 'sms' });
  }

  async verifyChallenge(challengeId, phone, code, { method } = {}) {
    const normalizedPhone = normalizeKazakhstanPhone(phone);
    if (!['sms', 'flash_call'].includes(method)) {
      throw new OtpChallengeError('unsupported_method');
    }
    validateCode(code, method);
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const currentTime = this.now();
      const result = await client.query(
        `SELECT id, phone_normalized, code_hash, purpose, method, expires_at,
                consumed_at, attempts_count, max_attempts
           FROM auth_otp_challenges
          WHERE id = $1 AND phone_normalized = $2 AND purpose = 'login'
            AND method = $3
          FOR UPDATE`,
        [challengeId, normalizedPhone, method],
      );
      const challenge = result.rows[0];
      if (!challenge) throw new OtpChallengeError('challenge_not_found');
      if (challenge.consumed_at) throw new OtpChallengeError('challenge_consumed');
      if (challenge.expires_at <= currentTime) {
        throw new OtpChallengeError('challenge_expired');
      }
      if (challenge.attempts_count >= challenge.max_attempts) {
        throw new OtpChallengeError('max_attempts_reached');
      }
      const candidateHash = otpHash({
        challengeId,
        phone: normalizedPhone,
        purpose: 'login',
        method,
        code,
        secret: this.secret,
      });
      if (!safeHashEqual(challenge.code_hash, candidateHash)) {
        const attempts = await client.query(
          `UPDATE auth_otp_challenges
              SET attempts_count = attempts_count + 1
            WHERE id = $1 AND consumed_at IS NULL
              AND expires_at > $2 AND attempts_count < max_attempts
          RETURNING attempts_count, max_attempts`,
          [challengeId, currentTime],
        );
        await client.query('COMMIT');
        const updated = attempts.rows[0];
        throw new OtpChallengeError(
          updated?.attempts_count >= updated?.max_attempts
            ? 'max_attempts_reached'
            : 'invalid_code',
        );
      }
      const consumed = await client.query(
        `UPDATE auth_otp_challenges
            SET consumed_at = $2
          WHERE id = $1 AND consumed_at IS NULL
            AND expires_at > $2 AND attempts_count < max_attempts
        RETURNING id`,
        [challengeId, currentTime],
      );
      if (consumed.rowCount !== 1) {
        throw new OtpChallengeError('challenge_not_active');
      }
      await client.query('COMMIT');
      return { verified: true, challengeId, phoneNormalized: normalizedPhone };
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      throw error;
    } finally {
      client.release();
    }
  }

  async invalidateOtpChallenge(challengeId) {
    const result = await this.pool.query(
      `UPDATE auth_otp_challenges
          SET consumed_at = COALESCE(consumed_at, $2)
        WHERE id = $1
      RETURNING id`,
      [challengeId, this.now()],
    );
    return result.rowCount > 0;
  }
}
