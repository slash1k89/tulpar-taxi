import { verifyAccessToken } from './access-token.js';

export function createAccessTokenMiddleware({ secret } = {}) {
  return function authenticateAccessToken(req, res, next) {
    try {
      const header = req.headers.authorization;
      if (!header?.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Missing authorization token' });
      }
      const claims = verifyAccessToken(header.slice(7), { secret });
      req.auth = { userId: claims.sub, sessionId: claims.sid };
      return next();
    } catch (_) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
  };
}
