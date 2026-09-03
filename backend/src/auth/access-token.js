import { createHmac, timingSafeEqual } from 'node:crypto';

export const ACCESS_TOKEN_ISSUER = 'tulpar-api';
export const ACCESS_TOKEN_AUDIENCE = 'tulpar-mobile';
export const DEFAULT_ACCESS_TOKEN_TTL_SECONDS = 900;

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isUuid(value) {
  return typeof value === 'string' && UUID_PATTERN.test(value);
}

function encodeJson(value) {
  return Buffer.from(JSON.stringify(value), 'utf8').toString('base64url');
}

function decodeJson(value) {
  return JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
}

function resolveSecret(secret = process.env.TULPAR_AUTH_ACCESS_SECRET) {
  if (typeof secret !== 'string' || secret.length < 32) {
    throw new Error('TULPAR_AUTH_ACCESS_SECRET must contain at least 32 characters');
  }
  return secret;
}

export function resolveAccessTokenTtlSeconds(
  value = process.env.TULPAR_AUTH_ACCESS_TTL,
) {
  if (value === undefined || value === '') return DEFAULT_ACCESS_TOKEN_TTL_SECONDS;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 60 || parsed > 86400) {
    throw new Error('TULPAR_AUTH_ACCESS_TTL must be an integer from 60 to 86400 seconds');
  }
  return parsed;
}

function signatureFor(input, secret) {
  return createHmac('sha256', secret).update(input, 'utf8').digest();
}

export function createAccessToken({
  userId,
  sessionId,
  secret,
  ttlSeconds,
  now = Date.now(),
} = {}) {
  if (!isUuid(userId)) {
    throw new Error('userId must be a valid UUID');
  }
  if (!isUuid(sessionId)) {
    throw new Error('sessionId must be a valid UUID');
  }
  const signingSecret = resolveSecret(secret);
  const ttl = resolveAccessTokenTtlSeconds(ttlSeconds);
  const issuedAt = Math.floor(now / 1000);
  const header = encodeJson({ alg: 'HS256', typ: 'JWT' });
  const payload = encodeJson({
    iss: ACCESS_TOKEN_ISSUER,
    aud: ACCESS_TOKEN_AUDIENCE,
    sub: userId,
    sid: sessionId,
    iat: issuedAt,
    exp: issuedAt + ttl,
  });
  const input = `${header}.${payload}`;
  const signature = signatureFor(input, signingSecret).toString('base64url');
  return `${input}.${signature}`;
}

export function verifyAccessToken(token, { secret, now = Date.now() } = {}) {
  if (typeof token !== 'string') throw new Error('Invalid access token');
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Invalid access token');
  const [headerPart, payloadPart, signaturePart] = parts;
  const input = `${headerPart}.${payloadPart}`;
  const expected = signatureFor(input, resolveSecret(secret));
  let actual;
  try {
    actual = Buffer.from(signaturePart, 'base64url');
  } catch (_) {
    throw new Error('Invalid access token');
  }
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    throw new Error('Invalid access token signature');
  }
  let header;
  let payload;
  try {
    header = decodeJson(headerPart);
    payload = decodeJson(payloadPart);
  } catch (_) {
    throw new Error('Invalid access token');
  }
  const nowSeconds = Math.floor(now / 1000);
  if (
    header.alg !== 'HS256' ||
    header.typ !== 'JWT' ||
    payload.iss !== ACCESS_TOKEN_ISSUER ||
    payload.aud !== ACCESS_TOKEN_AUDIENCE ||
    !isUuid(payload.sub) ||
    !isUuid(payload.sid) ||
    !Number.isSafeInteger(payload.iat) ||
    !Number.isSafeInteger(payload.exp) ||
    payload.exp <= nowSeconds
  ) {
    throw new Error('Invalid or expired access token');
  }
  return payload;
}
