import express from 'express';

export function createUserLocaleRouter({ pool, requireAuth }) {
  const router = express.Router();

  router.patch('/me/locale', requireAuth, async (req, res) => {
    const locale = req.body?.locale;
    if (typeof locale !== 'string' || !['ru', 'kk', 'en'].includes(locale)) {
      return res.status(400).json({ error: 'Unsupported locale' });
    }
    try {
      const result = await pool.query(
        `UPDATE users SET locale = $1, updated_at = now()
         WHERE (firebase_uid = $2 OR id::text = $2)
         RETURNING locale`,
        [locale, req.user.uid],
      );
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'User profile not found' });
      }
      return res.json({ locale: result.rows[0].locale });
    } catch (error) {
      console.error('[UserLocaleUpdate]', error);
      return res.status(500).json({ error: 'Failed to update locale' });
    }
  });

  return router;
}
