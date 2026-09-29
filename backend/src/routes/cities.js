import express from 'express';

export function createCitiesRouter({ pool, requireAuth }) {
  const router = express.Router();
  router.get('/', requireAuth, async (_req, res) => {
    try {
      const result = await pool.query(
        `SELECT slug AS id, name_ru, name_kk, name_en,
                center_lat, center_lng, bbox_south, bbox_west, bbox_north, bbox_east
         FROM cities WHERE is_enabled = TRUE ORDER BY sort_order`,
      );
      return res.json(result.rows);
    } catch (error) {
      console.error('[CitiesList]', error);
      return res.status(503).json({ error: 'Cities are unavailable' });
    }
  });
  return router;
}
