import express from 'express';
import { resolveCurrentUser } from '../terms-policy.js';

const contexts = new Set(['user', 'city_chat', 'intercity_chat', 'review']);
const reasons = new Set([
  'abuse', 'harassment', 'spam', 'unsafe_behavior', 'inappropriate_content', 'other',
]);

async function sharedContext(pool, reporterId, reportedId) {
  const result = await pool.query(
    `SELECT 1 FROM orders
      WHERE (passenger_id = $1 AND driver_id = $2)
         OR (passenger_id = $2 AND driver_id = $1)
     UNION ALL
     SELECT 1 FROM intercity_ride_bookings b
       JOIN intercity_rides r ON r.id = b.ride_id
      WHERE (b.passenger_id = $1 AND r.driver_id = $2)
         OR (b.passenger_id = $2 AND r.driver_id = $1)
     LIMIT 1`,
    [reporterId, reportedId],
  );
  return result.rowCount > 0;
}

async function requireAdmin(pool, req, res) {
  const user = await resolveCurrentUser(pool, req.user.uid);
  if (!user) {
    res.status(401).json({ code: 'account_unavailable', error: 'Account unavailable' });
    return null;
  }
  const result = await pool.query(
    'SELECT 1 FROM moderation_admins WHERE user_id = $1',
    [user.id],
  );
  if (!result.rowCount) {
    res.status(403).json({ code: 'admin_required', error: 'Administrator access required' });
    return null;
  }
  return user;
}

export function createStoreComplianceRouter({ pool, requireAuth, requireCurrentTerms }) {
  const router = express.Router();

  router.post('/reports', requireAuth, requireCurrentTerms, async (req, res) => {
    const context = req.body?.contextType;
    const reason = req.body?.reasonCode;
    let reportedUserId = req.body?.reportedUserId;
    const reasonText = typeof req.body?.reasonText === 'string'
      ? req.body.reasonText.trim() || null : null;
    if (!contexts.has(context) || !reasons.has(reason)
      || (context !== 'review' && typeof reportedUserId !== 'string')
      || (reasonText && reasonText.length > 500)) {
      return res.status(400).json({ code: 'invalid_report', error: 'Invalid report' });
    }
    const reporterId = req.currentUserId;
    if (context === 'review') {
      const review = await pool.query(
        'SELECT from_user_id FROM ratings WHERE id = $1',
        [req.body?.reviewId],
      );
      if (!review.rowCount) {
        return res.status(400).json({ code: 'invalid_report_context', error: 'Review not found' });
      }
      reportedUserId = review.rows[0].from_user_id;
    }
    if (reporterId === reportedUserId) {
      return res.status(400).json({ code: 'cannot_report_self', error: 'Cannot report yourself' });
    }
    if (context !== 'review' && !await sharedContext(pool, reporterId, reportedUserId)) {
      return res.status(403).json({ code: 'report_context_required', error: 'Shared trip context required' });
    }
    try {
      const result = await pool.query(
        `INSERT INTO content_reports (
          reporter_user_id, reported_user_id, context_type, reason_code, reason_text,
          order_id, booking_id, order_message_id, intercity_message_id, review_id
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id, status, created_at`,
        [reporterId, reportedUserId, context, reason, reasonText,
          req.body?.orderId ?? null, req.body?.bookingId ?? null,
          req.body?.orderMessageId ?? null, req.body?.intercityMessageId ?? null,
          req.body?.reviewId ?? null],
      );
      return res.status(201).json({
        id: result.rows[0].id,
        status: result.rows[0].status,
        createdAt: result.rows[0].created_at,
      });
    } catch (error) {
      if (error?.code === '23503' || error?.code === '23514') {
        return res.status(400).json({ code: 'invalid_report_context', error: 'Invalid report context' });
      }
      console.error('[Moderation] stage=create-report error=operation_failed');
      return res.status(500).json({ code: 'report_failed', error: 'Failed to create report' });
    }
  });

  router.post('/blocks', requireAuth, async (req, res) => {
    const blocker = await resolveCurrentUser(pool, req.user.uid);
    const blockedUserId = req.body?.blockedUserId;
    if (!blocker || typeof blockedUserId !== 'string' || blocker.id === blockedUserId) {
      return res.status(400).json({ code: 'invalid_block', error: 'Invalid block' });
    }
    if (!await sharedContext(pool, blocker.id, blockedUserId)) {
      return res.status(403).json({ code: 'block_context_required', error: 'Shared trip context required' });
    }
    await pool.query(
      `INSERT INTO user_blocks (blocker_user_id, blocked_user_id)
       VALUES ($1,$2) ON CONFLICT DO NOTHING`,
      [blocker.id, blockedUserId],
    );
    return res.status(201).json({ blocked: true });
  });

  router.delete('/blocks/:userId', requireAuth, async (req, res) => {
    const blocker = await resolveCurrentUser(pool, req.user.uid);
    if (!blocker) return res.status(404).json({ code: 'account_not_found', error: 'Account not found' });
    await pool.query(
      'DELETE FROM user_blocks WHERE blocker_user_id = $1 AND blocked_user_id = $2',
      [blocker.id, req.params.userId],
    );
    return res.json({ blocked: false });
  });

  router.get('/admin/reports', requireAuth, async (req, res) => {
    if (!await requireAdmin(pool, req, res)) return;
    const status = req.query.status ?? 'open';
    if (!['open', 'resolved', 'dismissed'].includes(status)) {
      return res.status(400).json({ code: 'invalid_status', error: 'Invalid status' });
    }
    const result = await pool.query(
      `SELECT id, reporter_user_id, reported_user_id, context_type, reason_code,
              reason_text, order_id, booking_id, order_message_id,
              intercity_message_id, review_id, status, created_at, resolved_at, resolved_by
         FROM content_reports WHERE status = $1 ORDER BY created_at LIMIT 100`,
      [status],
    );
    return res.json(result.rows);
  });

  router.get('/admin/reports/:reportId', requireAuth, async (req, res) => {
    if (!await requireAdmin(pool, req, res)) return;
    const result = await pool.query('SELECT * FROM content_reports WHERE id = $1', [req.params.reportId]);
    if (!result.rowCount) return res.status(404).json({ code: 'report_not_found', error: 'Report not found' });
    return res.json(result.rows[0]);
  });

  router.patch('/admin/reports/:reportId', requireAuth, async (req, res) => {
    const admin = await requireAdmin(pool, req, res);
    if (!admin) return;
    if (!['resolved', 'dismissed'].includes(req.body?.status)) {
      return res.status(400).json({ code: 'invalid_status', error: 'Invalid status' });
    }
    const result = await pool.query(
      `UPDATE content_reports SET status = $1, resolved_at = now(), resolved_by = $2
        WHERE id = $3 AND status = 'open'
        RETURNING id, status, resolved_at, resolved_by`,
      [req.body.status, admin.id, req.params.reportId],
    );
    if (!result.rowCount) return res.status(409).json({ code: 'report_not_open', error: 'Report is not open' });
    return res.json(result.rows[0]);
  });

  return router;
}
