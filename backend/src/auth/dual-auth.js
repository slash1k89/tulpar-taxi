import { verifyAccessToken } from './access-token.js';

function bearerToken(header) {
  if (typeof header !== 'string' || !header.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

async function activeUserById(pool, userId, sessionId) {
  const result = await pool.query(
    `SELECT id, firebase_uid, phone
       FROM users
      WHERE id = $1 AND account_status = 'active'
        AND EXISTS (
          SELECT 1 FROM auth_sessions s
          WHERE s.id = $2 AND s.user_id = users.id
            AND s.revoked_at IS NULL AND s.expires_at > now()
        )
      LIMIT 1`,
    [userId, sessionId],
  );
  return result.rows[0] ?? null;
}

async function activeUserByFirebaseUid(pool, firebaseUid) {
  const result = await pool.query(
    `SELECT id, firebase_uid, phone
       FROM users
      WHERE firebase_uid = $1 AND account_status = 'active'
      LIMIT 1`,
    [firebaseUid],
  );
  return result.rows[0] ?? null;
}

export function createDualAuthIdentity({
  pool,
  firebaseAuth,
  accessTokenSecret,
} = {}) {
  if (!pool?.query || !firebaseAuth?.verifyIdToken) {
    throw new Error('Dual auth requires PostgreSQL and Firebase Auth adapters');
  }

  return async function authenticateToken(token) {
    try {
      const claims = verifyAccessToken(token, { secret: accessTokenSecret });
      const user = await activeUserById(pool, claims.sub, claims.sid);
      if (!user) throw new Error('Inactive Tulpar user');
      return {
        auth: {
          type: 'tulpar',
          userId: user.id,
          sessionId: claims.sid,
          firebaseUid: user.firebase_uid ?? null,
        },
        user: {
          uid: user.id,
          phone: user.phone ?? null,
          authTime: claims.iat,
        },
      };
    } catch (_) {
      const decoded = await firebaseAuth.verifyIdToken(token);
      const user = await activeUserByFirebaseUid(pool, decoded.uid);
      return {
        auth: {
          type: 'firebase',
          userId: user?.id ?? null,
          sessionId: null,
          firebaseUid: decoded.uid,
        },
        user: {
          uid: decoded.uid,
          phone: decoded.phone_number ?? user?.phone ?? null,
          authTime: decoded.auth_time,
        },
      };
    }
  };
}

export function createDualAuthMiddleware(options = {}) {
  const authenticateToken = createDualAuthIdentity(options);
  return async function requireAuth(req, res, next) {
    const token = bearerToken(req.headers.authorization);
    if (!token) {
      return res.status(401).json({ error: 'Missing authorization token' });
    }
    try {
      const identity = await authenticateToken(token);
      req.auth = identity.auth;
      req.user = identity.user;
      return next();
    } catch (error) {
      console.error('[Auth]', error?.code ?? 'invalid_token');
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
  };
}

export function authIdentityKey(req) {
  return req?.auth?.type === 'tulpar'
    ? req.auth.userId
    : req?.auth?.firebaseUid ?? req?.user?.uid ?? null;
}
