import express from 'express';
import {
  CURRENT_TERMS_VERSION,
  hasAcceptedCurrentTerms,
  resolveCurrentUser,
} from '../terms-policy.js';

export function createTermsRouter({ pool, requireAuth }) {
  const router = express.Router();

  router.get('/status', requireAuth, async (req, res) => {
    const user = await resolveCurrentUser(pool, req.user.uid);
    if (!user || user.account_status !== 'active') {
      return res.status(404).json({ code: 'account_not_found', error: 'Account not found' });
    }
    return res.json({
      currentVersion: CURRENT_TERMS_VERSION,
      accepted: await hasAcceptedCurrentTerms(pool, user.id),
    });
  });

  router.post('/accept', requireAuth, async (req, res) => {
    if (req.body?.version !== CURRENT_TERMS_VERSION) {
      return res.status(409).json({
        code: 'terms_version_outdated',
        error: 'Terms version is not current',
        currentVersion: CURRENT_TERMS_VERSION,
      });
    }
    const user = await resolveCurrentUser(pool, req.user.uid);
    if (!user || user.account_status !== 'active') {
      return res.status(404).json({ code: 'account_not_found', error: 'Account not found' });
    }
    const result = await pool.query(
      `INSERT INTO user_terms_acceptances (user_id, terms_version)
       VALUES ($1, $2)
       ON CONFLICT (user_id, terms_version) DO UPDATE
       SET accepted_at = user_terms_acceptances.accepted_at
       RETURNING accepted_at`,
      [user.id, CURRENT_TERMS_VERSION],
    );
    return res.json({
      currentVersion: CURRENT_TERMS_VERSION,
      accepted: true,
      acceptedAt: result.rows[0].accepted_at,
    });
  });

  return router;
}
