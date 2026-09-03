import { createHash, randomBytes } from 'node:crypto';

import {
  createAccessToken,
  resolveAccessTokenTtlSeconds,
} from './access-token.js';

export const DEFAULT_REFRESH_TOKEN_TTL_SECONDS = 30 * 24 * 60 * 60;

export function hashRefreshToken(token) {
  if (typeof token !== 'string' || token.length < 32) {
    throw new Error('Invalid refresh token');
  }
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function resolveRefreshTtlSeconds(value = process.env.TULPAR_AUTH_REFRESH_TTL) {
  if (value === undefined || value === '') return DEFAULT_REFRESH_TOKEN_TTL_SECONDS;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 3600 || parsed > 31536000) {
    throw new Error('TULPAR_AUTH_REFRESH_TTL must be an integer from 3600 to 31536000 seconds');
  }
  return parsed;
}

function cleanMetadata(metadata = {}) {
  return {
    deviceId: metadata.deviceId ?? null,
    deviceName: metadata.deviceName ?? null,
    ipCreated: metadata.ipCreated ?? null,
    userAgent: metadata.userAgent ?? null,
  };
}

export class AuthSessionService {
  constructor({
    pool,
    accessTokenSecret,
    accessTokenTtlSeconds,
    refreshTokenTtlSeconds,
    now = () => new Date(),
    generateRefreshToken = () => randomBytes(48).toString('base64url'),
  } = {}) {
    if (!pool?.query) throw new Error('A PostgreSQL pool is required');
    this.pool = pool;
    this.accessTokenSecret = accessTokenSecret;
    this.accessTokenTtlSeconds = resolveAccessTokenTtlSeconds(
      accessTokenTtlSeconds,
    );
    this.refreshTokenTtlSeconds = resolveRefreshTtlSeconds(refreshTokenTtlSeconds);
    this.now = now;
    this.generateRefreshToken = generateRefreshToken;
  }

  _tokens(userId, sessionId, refreshToken, expiresAt) {
    return {
      sessionId,
      accessToken: createAccessToken({
        userId,
        sessionId,
        secret: this.accessTokenSecret,
        ttlSeconds: this.accessTokenTtlSeconds,
        now: this.now().getTime(),
      }),
      accessTokenExpiresIn: this.accessTokenTtlSeconds,
      refreshToken,
      refreshExpiresAt: expiresAt,
    };
  }

  async createSession(userId, metadata = {}) {
    const refreshToken = this.generateRefreshToken();
    const refreshTokenHash = hashRefreshToken(refreshToken);
    const createdAt = this.now();
    const expiresAt = new Date(
      createdAt.getTime() + this.refreshTokenTtlSeconds * 1000,
    );
    const clean = cleanMetadata(metadata);
    const result = await this.pool.query(
      `INSERT INTO auth_sessions (
         user_id, refresh_token_hash, created_at, expires_at,
         device_id, device_name, ip_created, user_agent
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, user_id, expires_at`,
      [
        userId,
        refreshTokenHash,
        createdAt,
        expiresAt,
        clean.deviceId,
        clean.deviceName,
        clean.ipCreated,
        clean.userAgent,
      ],
    );
    const session = result.rows[0];
    return this._tokens(
      session.user_id,
      session.id,
      refreshToken,
      session.expires_at,
    );
  }

  async verifyRefreshToken(refreshToken) {
    const result = await this.pool.query(
      `SELECT id, user_id, expires_at
         FROM auth_sessions
        WHERE refresh_token_hash = $1
          AND revoked_at IS NULL
          AND expires_at > $2
        LIMIT 1`,
      [hashRefreshToken(refreshToken), this.now()],
    );
    return result.rows[0] ?? null;
  }

  async rotateRefreshToken(refreshToken, metadata = {}) {
    const oldHash = hashRefreshToken(refreshToken);
    const nextRefreshToken = this.generateRefreshToken();
    const nextHash = hashRefreshToken(nextRefreshToken);
    const usedAt = this.now();
    const clean = cleanMetadata(metadata);
    const result = await this.pool.query(
      `UPDATE auth_sessions
          SET refresh_token_hash = $1,
              last_used_at = $2,
              device_id = COALESCE($3, device_id),
              device_name = COALESCE($4, device_name),
              user_agent = COALESCE($5, user_agent)
        WHERE refresh_token_hash = $6
          AND revoked_at IS NULL
          AND expires_at > $2
      RETURNING id, user_id, expires_at`,
      [
        nextHash,
        usedAt,
        clean.deviceId,
        clean.deviceName,
        clean.userAgent,
        oldHash,
      ],
    );
    const session = result.rows[0];
    if (!session) return null;
    return this._tokens(
      session.user_id,
      session.id,
      nextRefreshToken,
      session.expires_at,
    );
  }

  async revokeSession(sessionId, userId) {
    const result = await this.pool.query(
      `UPDATE auth_sessions
          SET revoked_at = COALESCE(revoked_at, $3)
        WHERE id = $1 AND user_id = $2
      RETURNING id`,
      [sessionId, userId, this.now()],
    );
    return result.rowCount > 0;
  }

  async revokeAllUserSessions(userId) {
    const result = await this.pool.query(
      `UPDATE auth_sessions
          SET revoked_at = $2
        WHERE user_id = $1 AND revoked_at IS NULL`,
      [userId, this.now()],
    );
    return result.rowCount;
  }
}
