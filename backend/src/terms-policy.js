export const CURRENT_TERMS_VERSION = '1.0';

export async function resolveCurrentUser(pool, identity) {
  const result = await pool.query(
    `SELECT id, account_status FROM users
      WHERE (firebase_uid = $1 OR id::text = $1) LIMIT 1`,
    [identity],
  );
  return result.rows[0] ?? null;
}

export async function hasAcceptedCurrentTerms(pool, userId) {
  const result = await pool.query(
    `SELECT 1 FROM user_terms_acceptances
      WHERE user_id = $1 AND terms_version = $2 LIMIT 1`,
    [userId, CURRENT_TERMS_VERSION],
  );
  return result.rowCount === 1;
}

export function createRequireCurrentTerms({ pool }) {
  return async function requireCurrentTerms(req, res, next) {
    try {
      const user = await resolveCurrentUser(pool, req.user.uid);
      if (!user || user.account_status !== 'active') {
        return res.status(401).json({ code: 'account_unavailable', error: 'Account unavailable' });
      }
      if (!await hasAcceptedCurrentTerms(pool, user.id)) {
        return res.status(403).json({
          code: 'terms_acceptance_required',
          error: 'Current Terms must be accepted before publishing content',
          currentVersion: CURRENT_TERMS_VERSION,
        });
      }
      req.currentUserId = user.id;
      return next();
    } catch (error) {
      console.error('[Terms] stage=ugc-gate error=operation_failed');
      return res.status(500).json({ code: 'terms_check_failed', error: 'Terms check failed' });
    }
  };
}
