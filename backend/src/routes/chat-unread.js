import express from 'express';
import { isUuid } from '../intercity-ride-policy.js';

export async function findChatViewer(pool, orderId, uid) {
  const result = await pool.query(
    `SELECT viewer.id
     FROM orders o
     JOIN users viewer
       ON (viewer.firebase_uid = $2 OR viewer.id::text = $2)
      AND viewer.id IN (o.passenger_id, o.driver_id)
     WHERE o.id = $1
     LIMIT 1`,
    [orderId, uid],
  );
  return result.rows[0]?.id ?? null;
}

export async function markChatRead(pool, orderId, viewerId, lastReadAt = null) {
  await pool.query(
    `INSERT INTO order_chat_reads (order_id, user_id, last_read_at)
     VALUES ($1, $2, COALESCE($3::timestamptz, now()))
     ON CONFLICT (order_id, user_id)
     DO UPDATE SET last_read_at = GREATEST(
       order_chat_reads.last_read_at, EXCLUDED.last_read_at
     )`,
    [orderId, viewerId, lastReadAt],
  );
}

export function createChatUnreadRouter({ pool, requireAuth }) {
  const router = express.Router({ mergeParams: true });

  router.get('/unread', requireAuth, async (req, res) => {
    if (!isUuid(req.params.orderId)) {
      return res.status(400).json({ error: 'Invalid orderId' });
    }
    try {
      const viewerId = await findChatViewer(pool, req.params.orderId, req.user.uid);
      if (!viewerId) return res.status(403).json({ error: 'Chat access denied' });

      const result = await pool.query(
        `SELECT COUNT(*)::int AS unread_count
         FROM order_messages m
         LEFT JOIN order_chat_reads r
           ON r.order_id = m.order_id AND r.user_id = $2
         JOIN users viewer ON viewer.id = $2
         WHERE m.order_id = $1
           AND m.sender_id <> viewer.id
           AND m.created_at > COALESCE(r.last_read_at, '-infinity'::timestamptz)`,
        [req.params.orderId, viewerId],
      );
      return res.json({ unreadCount: result.rows[0]?.unread_count ?? 0 });
    } catch (error) {
      console.error('[ChatUnreadGet]', error);
      return res.status(500).json({ error: 'Failed to load unread messages' });
    }
  });

  router.post('/read', requireAuth, async (req, res) => {
    if (!isUuid(req.params.orderId)) {
      return res.status(400).json({ error: 'Invalid orderId' });
    }
    try {
      const viewerId = await findChatViewer(pool, req.params.orderId, req.user.uid);
      if (!viewerId) return res.status(403).json({ error: 'Chat access denied' });
      await markChatRead(pool, req.params.orderId, viewerId);
      return res.json({ unreadCount: 0 });
    } catch (error) {
      console.error('[ChatUnreadRead]', error);
      return res.status(500).json({ error: 'Failed to mark messages as read' });
    }
  });

  return router;
}
