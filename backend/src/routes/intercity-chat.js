import express from 'express';
import { isUuid } from '../intercity-ride-policy.js';
import { areUsersBlocked, canBlockedPairWriteChat } from '../block-policy.js';

async function loadContext(pool, bookingId, uid) {
  const result = await pool.query(
    `SELECT b.id AS booking_id, b.status AS booking_status, b.completed_at,
            r.id AS ride_id, r.status AS ride_status,
            passenger.id AS passenger_id,
            driver.id AS driver_id,
            viewer.id AS viewer_id,
            viewer.name AS viewer_name,
            COALESCE(passenger.firebase_uid, passenger.id::text) AS passenger_uid,
            COALESCE(driver.firebase_uid, driver.id::text) AS driver_uid
     FROM intercity_ride_bookings b
     JOIN intercity_rides r ON r.id = b.ride_id
     JOIN users passenger ON passenger.id = b.passenger_id
     JOIN users driver ON driver.id = r.driver_id
     JOIN users viewer
       ON (viewer.firebase_uid = $2 OR viewer.id::text = $2)
      AND viewer.id IN (passenger.id, driver.id)
     WHERE b.id = $1
     LIMIT 1`,
    [bookingId, uid],
  );
  return result.rows[0] ?? null;
}

export function intercityChatAccess(context) {
  if (!context || context.booking_status === 'cancelled') return 'denied';
  if (context.booking_status === 'confirmed') return 'write';
  if (context.booking_status === 'completed' && context.completed_at) {
    const expiresAt = new Date(context.completed_at).getTime() + 24 * 60 * 60 * 1000;
    return Date.now() <= expiresAt ? 'write' : 'denied';
  }
  return 'denied';
}

async function markRead(pool, bookingId, viewerId, lastReadAt = null) {
  await pool.query(
    `INSERT INTO intercity_booking_chat_reads (booking_id, user_id, last_read_at)
     VALUES ($1, $2, COALESCE($3::timestamptz, now()))
     ON CONFLICT (booking_id, user_id)
     DO UPDATE SET last_read_at = GREATEST(
       intercity_booking_chat_reads.last_read_at, EXCLUDED.last_read_at
     )`,
    [bookingId, viewerId, lastReadAt],
  );
}

export function createIntercityChatRouter({
  pool,
  requireAuth,
  sendPushToUser,
  chatSendRateLimiter,
  requireCurrentTerms = (_req, _res, next) => next(),
}) {
  const router = express.Router({ mergeParams: true });
  router.use(requireAuth);
  router.use(async (req, res, next) => {
    if (!isUuid(req.params.bookingId)) {
      return res.status(400).json({ error: 'Invalid bookingId' });
    }
    try {
      req.intercityChat = await loadContext(
        pool,
        req.params.bookingId,
        req.user.uid,
      );
      if (intercityChatAccess(req.intercityChat) === 'denied') {
        return res.status(403).json({ error: 'Chat access denied' });
      }
      return next();
    } catch (error) {
      console.error('[IntercityChatAccess]', error);
      return res.status(500).json({ error: 'Failed to validate chat access' });
    }
  });

  router.get('/', async (req, res) => {
    try {
      const result = await pool.query(
        `SELECT m.id,
                COALESCE(sender.firebase_uid, sender.id::text) AS sender_uid,
                sender.name AS sender_name, m.text, m.created_at
         FROM intercity_booking_messages m
         JOIN users sender ON sender.id = m.sender_id
         WHERE m.booking_id = $1
         ORDER BY m.created_at DESC LIMIT 100`,
        [req.params.bookingId],
      );
      await markRead(
        pool,
        req.params.bookingId,
        req.intercityChat.viewer_id,
        result.rows[0]?.created_at ?? null,
      );
      return res.json({
        messages: result.rows.map((row) => ({
          id: row.id,
          senderId: row.sender_uid,
          senderName: row.sender_name,
          text: row.text,
          createdAt: row.created_at,
        })),
      });
    } catch (error) {
      console.error('[IntercityChatGet]', error);
      return res.status(500).json({ error: 'Failed to load messages' });
    }
  });

  router.get('/unread', async (req, res) => {
    try {
      const result = await pool.query(
        `SELECT COUNT(*)::int AS unread_count
         FROM intercity_booking_messages m
         LEFT JOIN intercity_booking_chat_reads r
           ON r.booking_id = m.booking_id AND r.user_id = $2
         WHERE m.booking_id = $1 AND m.sender_id <> $2
           AND m.created_at > COALESCE(r.last_read_at, '-infinity'::timestamptz)`,
        [req.params.bookingId, req.intercityChat.viewer_id],
      );
      return res.json({ unreadCount: result.rows[0]?.unread_count ?? 0 });
    } catch (error) {
      console.error('[IntercityChatUnread]', error);
      return res.status(500).json({ error: 'Failed to load unread messages' });
    }
  });

  router.post('/read', async (req, res) => {
    try {
      await markRead(pool, req.params.bookingId, req.intercityChat.viewer_id);
      return res.json({ unreadCount: 0 });
    } catch (error) {
      console.error('[IntercityChatRead]', error);
      return res.status(500).json({ error: 'Failed to mark messages as read' });
    }
  });

  router.post('/', requireCurrentTerms, chatSendRateLimiter, async (req, res) => {
    const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
    if (text.length === 0 || text.length > 2000) {
      return res.status(400).json({ error: 'Message must contain from 1 to 2000 characters' });
    }
    try {
      const counterpartId = req.intercityChat.viewer_id === req.intercityChat.passenger_id
        ? req.intercityChat.driver_id : req.intercityChat.passenger_id;
      const activeTrip = req.intercityChat.booking_status === 'confirmed'
        && ['scheduled', 'departed'].includes(req.intercityChat.ride_status);
      const blocked = await areUsersBlocked(
        pool,
        req.intercityChat.viewer_id,
        counterpartId,
      );
      if (!canBlockedPairWriteChat({ blocked, activeTrip })) {
        return res.status(403).json({
          code: 'user_blocked',
          error: 'Chat is blocked after the trip',
        });
      }
      const result = await pool.query(
        `INSERT INTO intercity_booking_messages (booking_id, sender_id, text)
         VALUES ($1, $2, $3) RETURNING id, text, created_at`,
        [req.params.bookingId, req.intercityChat.viewer_id, text],
      );
      const message = result.rows[0];
      const recipientUid = req.intercityChat.viewer_id === req.intercityChat.passenger_id
        ? req.intercityChat.driver_uid
        : req.intercityChat.passenger_uid;
      try {
        await sendPushToUser(recipientUid, {
          data: {
            type: 'intercity_chat_message',
            bookingId: req.params.bookingId,
            rideId: req.intercityChat.ride_id,
            messageId: message.id,
            senderName: req.intercityChat.viewer_name ?? '',
            messagePreview: text.length > 160 ? `${text.slice(0, 157)}...` : text,
            recipientRole: req.intercityChat.viewer_id === req.intercityChat.passenger_id
              ? 'driver'
              : 'passenger',
          },
        });
      } catch (pushError) {
        console.error('[IntercityChatPush]', pushError);
      }
      return res.status(201).json({
        message: {
          id: message.id,
          senderId: req.user.uid,
          senderName: req.intercityChat.viewer_name,
          text: message.text,
          createdAt: message.created_at,
        },
      });
    } catch (error) {
      console.error('[IntercityChatSend]', error);
      return res.status(500).json({ error: 'Failed to send message' });
    }
  });

  return router;
}
