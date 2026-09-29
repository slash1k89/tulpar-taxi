import express from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';

export const jsonBodyLimit = '64kb';

const defaultApiWindowMs = 5 * 60 * 1000;
const defaultApiMax = 600;
const defaultPushTestWindowMs = 10 * 60 * 1000;
const defaultPushTestMax = 3;
const defaultVerificationWindowMs = 10 * 60 * 1000;
const defaultVerificationMax = 10;
const defaultChatSendWindowMs = 60 * 1000;
const defaultChatSendMax = 30;
const maximumTrustProxyHops = 10;

export function parseTrustProxyHops(value = process.env.TRUST_PROXY_HOPS) {
  const raw = value === undefined ? '0' : String(value).trim();
  if (!/^\d+$/.test(raw)) {
    throw new Error('TRUST_PROXY_HOPS must be an integer from 0 to 10');
  }

  const hops = Number(raw);
  if (!Number.isSafeInteger(hops) || hops > maximumTrustProxyHops) {
    throw new Error('TRUST_PROXY_HOPS must be an integer from 0 to 10');
  }
  return hops;
}

export function configureTrustProxy(
  app,
  value = process.env.TRUST_PROXY_HOPS,
) {
  const hops = parseTrustProxyHops(value);
  app.set('trust proxy', hops);
  return hops;
}

function positiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function normalizeHttpOrigin(value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return null;
  }

  try {
    const url = new URL(value.trim());
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      return null;
    }
    return url.origin;
  } catch (_) {
    return null;
  }
}

export function parseAllowedWebOrigins(value = '') {
  return new Set(
    String(value)
      .split(',')
      .map(normalizeHttpOrigin)
      .filter(Boolean),
  );
}

function isLocalDevelopmentOrigin(origin) {
  try {
    const url = new URL(origin);
    return (
      (url.protocol === 'http:' || url.protocol === 'https:') &&
      (url.hostname === 'localhost' || url.hostname === '127.0.0.1')
    );
  } catch (_) {
    return false;
  }
}

export function createCorsMiddleware({
  allowedWebOrigins = process.env.ALLOWED_WEB_ORIGINS ?? '',
  nodeEnv = process.env.NODE_ENV ?? 'development',
} = {}) {
  const configuredOrigins = parseAllowedWebOrigins(allowedWebOrigins);
  const allowLocalDevelopmentOrigins = nodeEnv !== 'production';

  return (req, res, next) => {
    const origin = req.headers.origin;
    res.vary('Origin');

    if (origin === undefined) {
      if (req.method === 'OPTIONS') {
        return res.sendStatus(204);
      }
      return next();
    }

    const normalizedOrigin = normalizeHttpOrigin(origin);
    const allowed =
      normalizedOrigin !== null &&
      ((allowLocalDevelopmentOrigins &&
        isLocalDevelopmentOrigin(normalizedOrigin)) ||
        configuredOrigins.has(normalizedOrigin));

    if (!allowed) {
      return res.status(403).json({
        error: 'CORS origin denied',
      });
    }

    res.setHeader('Access-Control-Allow-Origin', normalizedOrigin);
    res.setHeader(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type, Accept',
    );
    res.setHeader(
      'Access-Control-Allow-Methods',
      'GET, POST, PATCH, PUT, DELETE, OPTIONS',
    );

    if (req.method === 'OPTIONS') {
      return res.sendStatus(204);
    }

    return next();
  };
}

function tooManyRequests(_req, res) {
  return res.status(429).json({
    error: 'Too many requests',
  });
}

function isChatMessagesRequest(req) {
  const path = req.originalUrl?.split('?')[0] ?? req.path ?? '';
  return /^\/api\/orders\/[^/]+\/messages(?:\/|$)/.test(path);
}

export function createApiRateLimiter({
  windowMs = positiveInteger(
    process.env.API_RATE_LIMIT_WINDOW_MS,
    defaultApiWindowMs,
  ),
  limit = positiveInteger(process.env.API_RATE_LIMIT_MAX, defaultApiMax),
} = {}) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    handler: tooManyRequests,
    skip: isChatMessagesRequest,
  });
}

export function createChatSendRateLimiter({
  windowMs = positiveInteger(
    process.env.CHAT_SEND_RATE_LIMIT_WINDOW_MS,
    defaultChatSendWindowMs,
  ),
  limit = positiveInteger(
    process.env.CHAT_SEND_RATE_LIMIT_MAX,
    defaultChatSendMax,
  ),
} = {}) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    keyGenerator: (req) => `uid:${req.user.uid}:order:${req.params.orderId}`,
    handler: (_req, res) => {
      const rawRetryAfter = Number(res.getHeader('Retry-After'));
      const retryAfterSeconds = Number.isFinite(rawRetryAfter)
        ? Math.max(1, Math.ceil(rawRetryAfter))
        : Math.max(1, Math.ceil(windowMs / 1000));
      return res.status(429).json({
        error: 'chat_rate_limited',
        retryAfterSeconds,
      });
    },
  });
}

export function createPushTestRateLimiter({
  windowMs = positiveInteger(
    process.env.PUSH_TEST_RATE_LIMIT_WINDOW_MS,
    defaultPushTestWindowMs,
  ),
  limit = positiveInteger(
    process.env.PUSH_TEST_RATE_LIMIT_MAX,
    defaultPushTestMax,
  ),
} = {}) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    keyGenerator: (req) => `uid:${req.user.uid}`,
    handler: tooManyRequests,
  });
}

export function createAuthVerificationRateLimiter({
  windowMs = positiveInteger(
    process.env.AUTH_VERIFICATION_RATE_LIMIT_WINDOW_MS,
    defaultVerificationWindowMs,
  ),
  limit = positiveInteger(
    process.env.AUTH_VERIFICATION_RATE_LIMIT_MAX,
    defaultVerificationMax,
  ),
} = {}) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    handler: tooManyRequests,
  });
}

export function createHelmetMiddleware() {
  return helmet({
    // Tulpar serves a JSON API, not HTML. CORS remains the browser boundary.
    contentSecurityPolicy: false,
  });
}

export function createJsonBodyParser() {
  return express.json({
    limit: jsonBodyLimit,
  });
}

export function apiErrorHandler(error, req, res, next) {
  if (res.headersSent) {
    return next(error);
  }

  if (error?.type === 'entity.too.large' || error?.status === 413) {
    return res.status(413).json({
      error: 'Request body too large',
    });
  }

  if (error?.type === 'entity.parse.failed' && error?.status === 400) {
    return res.status(400).json({
      error: 'Invalid JSON body',
    });
  }

  // Do not log headers, request bodies, tokens, passwords or secrets.
  console.error('[HTTPError]', {
    method: req.method,
    path: req.path,
    name: error?.name,
    code: error?.code,
    stack: error?.stack,
  });

  return res.status(500).json({
    error: 'Internal server error',
  });
}
