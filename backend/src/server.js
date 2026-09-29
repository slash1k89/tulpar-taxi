import express from 'express';
import pg from 'pg';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getMessaging } from 'firebase-admin/messaging';
import { createDriverProfileRouter } from './routes/driver-profile.js';
import { createCitiesRouter } from './routes/cities.js';
import { createOrdersRouter } from './routes/orders.js';
import { createRoutingRouter } from './routes/routing.js';
import { createGeocodingRouter } from './routes/geocoding.js';
import { createIntercityRidesRouter } from './routes/intercity-rides.js';
import { createIntercityChatRouter } from './routes/intercity-chat.js';
import { createAccountRouter } from './routes/account.js';
import { createAuthRouter } from './routes/auth.js';
import { PasswordAuthService } from './auth/password-service.js';
import { cleanupExpiredAuthHistory } from './auth/auth-history-cleanup.js';
import { createUserLocaleRouter } from './routes/user-locale.js';
import { createTermsRouter } from './routes/terms.js';
import { createStoreComplianceRouter } from './routes/store-compliance.js';
import { createRequireCurrentTerms } from './terms-policy.js';
import {
  createChatUnreadRouter,
  findChatViewer,
  markChatRead,
} from './routes/chat-unread.js';
import { isUuid } from './intercity-ride-policy.js';
import { localizedPushCopy } from './push-copy.js';
import { resolveFirebaseCredential } from './firebase-credential.js';
import { isPermanentlyInvalidPushTokenError } from './push-token-policy.js';
import { canReceiveLocalOrderNotification } from './city-scope.js';
import { areUsersBlocked, canBlockedPairWriteChat } from './block-policy.js';
import { createAccessTokenMiddleware } from './auth/authenticate-access-token.js';
import {
  createDualAuthIdentity,
  createDualAuthMiddleware,
} from './auth/dual-auth.js';
import { AuthSessionService } from './auth/session-service.js';
import { OtpChallengeService } from './auth/otp-service.js';
import { PhoneIdentityService } from './auth/phone-identity-service.js';
import { createSmsSenderFromEnv } from './auth/sms-sender.js';
import { createVerificationProviderFromEnv } from './auth/verification-provider.js';
import {
  retryPendingAccountDeletions,
} from './account-deletion.js';
import { syncActiveUser } from './user-sync.js';
import {
  apiErrorHandler,
  configureTrustProxy,
  createApiRateLimiter,
  createAuthVerificationRateLimiter,
  createChatSendRateLimiter,
  createCorsMiddleware,
  createHelmetMiddleware,
  createJsonBodyParser,
  createPushTestRateLimiter,
} from './http-security.js';
import { selectUserSyncPhone } from './security-policy.js';
import http from 'http';
import { WebSocketServer } from 'ws';

const { Pool } = pg;

const app = express();
configureTrustProxy(app);
app.use(createHelmetMiddleware());
app.use(createCorsMiddleware());
app.use('/api', createApiRateLimiter());
app.use(createJsonBodyParser());

const pushTestRateLimiter = createPushTestRateLimiter();
const authVerificationRateLimiter = createAuthVerificationRateLimiter();
const chatSendRateLimiter = createChatSendRateLimiter();


const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
});

initializeApp({
  credential: resolveFirebaseCredential(),
});


async function sendPushToUser(uid, {
  title = 'MEKEN',
  body = '',
  data = {},
} = {}) {
  const event = data?.type?.toString() || 'unknown';
  let result;
  try {
    result = await pool.query(
      `
      SELECT t.id, t.token, u.locale
      FROM user_push_tokens t
      JOIN users u
        ON u.id = t.user_id
      WHERE (u.firebase_uid = $1 OR u.id::text = $1)
      ORDER BY t.updated_at DESC
      `,
      [uid],
    );
  } catch (error) {
    console.error(
      `[Push] event=${event} recipientUserId=${uid} stage=token_lookup errorCode=${error?.code ?? 'unknown'}`,
    );
    throw error;
  }

  if (result.rows.length === 0) {
    console.log(
      `[Push] event=${event} recipientUserId=${uid} tokenCount=0 successCount=0 failureCount=0`,
    );
    return {
      successCount: 0,
      failureCount: 0,
    };
  }

  const tokens = result.rows.map((row) => row.token);
  const locale = result.rows[0]?.locale;
  console.log(
    `[Push] event=${event} recipientUserId=${uid} tokenCount=${tokens.length} locale=${locale ?? 'ru'} stage=send_attempt`,
  );
  const localized = localizedPushCopy({
    eventType: data?.type,
    locale,
    data,
    fallbackTitle: title,
    fallbackBody: body,
  });

  const stringData = {};

  for (const [key, value] of Object.entries(data)) {
    if (value !== null && value !== undefined) {
      stringData[key] = String(value);
    }
  }

  let response;
  try {
    response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: localized.title,
        body: localized.body,
      },
      data: stringData,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'tulpar_orders',
        },
      },
    });
  } catch (error) {
    console.error(
      `[Push] event=${event} recipientUserId=${uid} tokenCount=${tokens.length} stage=firebase_send errorCode=${error?.code ?? 'unknown'}`,
    );
    throw error;
  }

  const invalidTokens = [];

  response.responses.forEach((item, index) => {
    if (item.success) {
      return;
    }

    const code = item.error?.code ?? 'unknown';

    console.error(
      `[Push] event=${event} recipientUserId=${uid} tokenFailureCode=${code}`,
    );

    if (isPermanentlyInvalidPushTokenError(code)) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length > 0) {
    await pool.query(
      `
      DELETE FROM user_push_tokens
      WHERE token = ANY($1::text[])
      `,
      [invalidTokens],
    );
  }

  console.log(
    `[Push] event=${event} recipientUserId=${uid} tokenCount=${tokens.length} successCount=${response.successCount} failureCount=${response.failureCount} invalidTokenCount=${invalidTokens.length}`,
  );

  return {
    successCount: response.successCount,
    failureCount: response.failureCount,
  };
}


const authenticateIdentity = createDualAuthIdentity({
  pool,
  firebaseAuth: getAuth(),
});
const requireAuth = createDualAuthMiddleware({
  pool,
  firebaseAuth: getAuth(),
});
const requireCurrentTerms = createRequireCurrentTerms({ pool });
app.use('/api/users', createUserLocaleRouter({ pool, requireAuth }));
app.use('/api/terms', createTermsRouter({ pool, requireAuth }));
app.use('/api/compliance', createStoreComplianceRouter({
  pool,
  requireAuth,
  requireCurrentTerms,
}));

const tulparSessionService = new AuthSessionService({ pool });
const tulparOtpService = process.env.TULPAR_AUTH_OTP_SECRET
  ? new OtpChallengeService({ pool })
  : null;

app.use('/api/auth/verification', authVerificationRateLimiter);
app.use('/api/auth/login', authVerificationRateLimiter);

app.use(
  '/api/auth',
  createAuthRouter({
    otpService: tulparOtpService,
    identityService: new PhoneIdentityService({ pool }),
    sessionService: tulparSessionService,
    smsSender: createSmsSenderFromEnv(),
    authenticateAccessToken: createAccessTokenMiddleware(),
    verificationProvider: createVerificationProviderFromEnv(),
    passwordService: new PasswordAuthService({ pool }),
  }),
);

app.use(
  '/api/driver-profile',
  createDriverProfileRouter({
    pool,
    requireAuth,
  }),
);

app.use('/api/cities', createCitiesRouter({ pool, requireAuth }));

app.use(
  '/api/orders',
  createOrdersRouter({
    pool,
    requireAuth,
    sendToUser,
    sendToAvailableDrivers,
    sendPushToUser,
    requireCurrentTerms,
  }),
);

app.use(
  '/api/routing',
  createRoutingRouter({ requireAuth }),
);

app.use(
  '/api/geocoding',
  createGeocodingRouter({ requireAuth, pool }),
);

app.use(
  '/api/intercity-rides',
  createIntercityRidesRouter({ pool, requireAuth, sendPushToUser }),
);
app.use(
  '/api/intercity-bookings/:bookingId/messages',
  createIntercityChatRouter({
    pool,
    requireAuth,
    sendPushToUser,
    chatSendRateLimiter,
    requireCurrentTerms,
  }),
);

app.use(
  '/api/account',
  createAccountRouter({
    pool,
    requireAuth,
    deleteFirebaseUser: (uid) => getAuth().deleteUser(uid),
  }),
);

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');

    res.json({
      status: 'ok',
      service: 'tulpar-api',
      database: 'connected',
    });
  } catch (error) {
    console.error('[Health]', error);

    res.status(503).json({
      status: 'error',
      database: 'unavailable',
    });
  }
});

app.get('/api/config', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        st.code,
        st.name,
        st.enabled,
        t.minimum_day_fare,
        t.minimum_night_fare,
        t.shift_fee,
        t.shift_hours,
        t.day_start_hour,
        t.night_start_hour
      FROM service_types st
      LEFT JOIN service_tariffs t
        ON t.service_type = st.code
      ORDER BY st.code
    `);

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'Configuration not found',
      });
    }

    const services = {};

    for (const row of result.rows) {
      services[row.code] = {
        name: row.name,
        enabled: row.enabled,
        minimumDayFare: row.minimum_day_fare,
        minimumNightFare: row.minimum_night_fare,
        shiftFee: row.shift_fee,
        shiftHours: row.shift_hours,
        dayStartHour: row.day_start_hour,
        nightStartHour: row.night_start_hour,
      };
    }

    res.json({
      services,
    });
  } catch (error) {
    console.error('[Config]', error);

    res.status(500).json({
      error: 'Failed to load configuration',
    });
  }
});

app.post('/api/users/sync', requireAuth, async (req, res) => {
  try {
    if (req.auth?.type === 'tulpar') {
      return res.status(409).json({
        code: 'profile_update_required',
        error: 'Use the current user profile endpoint',
      });
    }
    const firebaseUid = req.user.uid;

    const phone = selectUserSyncPhone({
      verifiedPhone: req.user.phone,
      legacyBodyPhone: req.body?.phone,
    });

    const rawName =
      typeof req.body?.name === 'string'
        ? req.body.name.trim()
        : '';

    const name = rawName || null;

    if (phone !== null && (phone.length < 5 || phone.length > 32)) {
      return res.status(400).json({
        error: 'Invalid phone number',
      });
    }

    if (name !== null && (name.length < 2 || name.length > 120)) {
      return res.status(400).json({
        error: 'Name must contain from 2 to 120 characters',
      });
    }

    const synced = await syncActiveUser({ pool, firebaseUid, phone, name });
    if (synced.kind === 'deleted') {
      return res.status(410).json({
        code: 'account_deleted',
        error: 'Account has been deleted',
      });
    }
    const user = synced.user;

    res.json({
      id: user.id,
      firebaseUid: user.firebase_uid,
      phone: user.phone,
      name: user.name,
      rating: Number(user.rating),
      ratingSum: user.rating_sum,
      ratingCount: user.rating_count,
      createdAt: user.created_at,
      updatedAt: user.updated_at,
    });
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({
        error: 'Phone number is already registered',
      });
    }

    console.error('[UserSync]', error);

    res.status(500).json({
      error: 'Failed to synchronize user',
    });
  }
});

app.get('/api/users/me', requireAuth, async (req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT
        id,
        firebase_uid,
        phone,
        name,
        rating,
        rating_sum,
        rating_count,
        created_at,
        updated_at
      FROM users
      WHERE (firebase_uid = $1 OR id::text = $1)
      `,
      [req.user.uid],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'User profile not found',
      });
    }

    const user = result.rows[0];

    res.json({
      id: user.id,
      firebaseUid: user.firebase_uid,
      phone: user.phone,
      name: user.name,
      rating: Number(user.rating),
      ratingSum: user.rating_sum,
      ratingCount: user.rating_count,
      createdAt: user.created_at,
      updatedAt: user.updated_at,
    });
  } catch (error) {
    console.error('[UserMe]', error);

    res.status(500).json({
      error: 'Failed to load user profile',
    });
  }
});

app.patch('/api/users/me', requireAuth, async (req, res) => {
  try {
    const rawName = req.body?.name;

    if (typeof rawName !== 'string') {
      return res.status(400).json({
        error: 'Name is required',
      });
    }

    const name = rawName.trim();

    if (name.length < 2 || name.length > 120) {
      return res.status(400).json({
        error: 'Name must contain from 2 to 120 characters',
      });
    }

    const result = await pool.query(
      `
      UPDATE users
      SET
        name = $1,
        updated_at = now()
      WHERE (firebase_uid = $2 OR id::text = $2)
      RETURNING
        id,
        firebase_uid,
        phone,
        name,
        rating,
        rating_sum,
        rating_count,
        created_at,
        updated_at
      `,
      [name, req.user.uid],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'User profile not found',
      });
    }

    const user = result.rows[0];

    res.json({
      id: user.id,
      firebaseUid: user.firebase_uid,
      phone: user.phone,
      name: user.name,
      rating: Number(user.rating),
      ratingSum: user.rating_sum,
      ratingCount: user.rating_count,
      createdAt: user.created_at,
      updatedAt: user.updated_at,
    });
  } catch (error) {
    console.error('[UserUpdate]', error);

    res.status(500).json({
      error: 'Failed to update user profile',
    });
  }
});

  app.post('/api/push/token', requireAuth, async (req, res) => {
    try {
      const token = req.body?.token;
      const platform = req.body?.platform ?? 'android';

      if (
        typeof token !== 'string' ||
        token.trim().length < 20
      ) {
        return res.status(400).json({
          error: 'Invalid push token',
        });
      }

      const userResult = await pool.query(
        `
        SELECT id
        FROM users
        WHERE (firebase_uid = $1 OR id::text = $1)
        LIMIT 1
        `,
        [req.user.uid],
      );

      if (userResult.rows.length === 0) {
        return res.status(404).json({
          error: 'User not found',
        });
      }

      const userId = userResult.rows[0].id;

      await pool.query(
        `
        INSERT INTO user_push_tokens (
          user_id,
          token,
          platform,
          updated_at
        )
        VALUES (
          $1,
          $2,
          $3,
          now()
        )
        ON CONFLICT (token)
        DO UPDATE SET
          user_id = EXCLUDED.user_id,
          platform = EXCLUDED.platform,
          updated_at = now()
        `,
        [
          userId,
          token.trim(),
          platform,
        ],
      );

      res.json({
        registered: true,
      });
    } catch (error) {
      console.error('[PushTokenRegister]', error);

      res.status(500).json({
        error: 'Failed to register push token',
      });
    }
  });


  app.post(
    '/api/push/test',
    requireAuth,
    pushTestRateLimiter,
    async (req, res) => {
    try {
      const result = await sendPushToUser(req.user.uid, {
        title: 'MEKEN',
        body: 'Тестовое push-уведомление работает!',
        data: {
          type: 'test_push',
        },
      });

      res.json({
        sent: true,
        successCount: result.successCount,
        failureCount: result.failureCount,
      });
    } catch (error) {
      console.error('[PushTest]', error);

      res.status(500).json({
        error: 'Failed to send test push',
      });
    }
    },
  );

  // Сообщения чата конкретного заказа.
  app.get('/api/orders/:orderId/messages', requireAuth, async (req, res) => {
    if (!isUuid(req.params.orderId)) {
      return res.status(400).json({ error: 'Invalid orderId' });
    }
    try {
      const viewerId = await findChatViewer(pool, req.params.orderId, req.user.uid);
      if (!viewerId) {
        return res.status(403).json({
          error: 'Chat access denied',
        });
      }

      const result = await pool.query(
        `
        SELECT
          m.id,
          COALESCE(sender.firebase_uid, sender.id::text) AS sender_uid,
          sender.name AS sender_name,
          m.text,
          m.created_at

        FROM order_messages m

        JOIN users sender
          ON sender.id = m.sender_id

        WHERE m.order_id = $1

        ORDER BY m.created_at DESC
        LIMIT 100
        `,
        [req.params.orderId],
      );

      await markChatRead(
        pool,
        req.params.orderId,
        viewerId,
        result.rows[0]?.created_at ?? null,
      );

      res.json({
        messages: result.rows.map((row) => ({
          id: row.id,
          senderId: row.sender_uid,
          senderName: row.sender_name,
          text: row.text,
          createdAt: row.created_at,
        })),
      });
    } catch (error) {
      console.error('[ChatMessagesGet]', error);

      res.status(500).json({
        error: 'Failed to load messages',
      });
    }
  });

  app.use(
    '/api/orders/:orderId/messages',
    createChatUnreadRouter({ pool, requireAuth }),
  );


  // Отправка сообщения и push второму участнику заказа.
  app.post(
    '/api/orders/:orderId/messages',
    requireAuth,
    requireCurrentTerms,
    chatSendRateLimiter,
    async (req, res) => {
    try {
      const text =
        typeof req.body?.text === 'string'
          ? req.body.text.trim()
          : '';

      if (text.length === 0 || text.length > 2000) {
        return res.status(400).json({
          error: 'Message must contain from 1 to 2000 characters',
        });
      }

      const orderResult = await pool.query(
        `
        SELECT
          o.id,
          o.status,
          passenger.id AS passenger_id,
          driver.id AS driver_id,

          COALESCE(passenger.firebase_uid, passenger.id::text) AS passenger_uid,
          COALESCE(driver.firebase_uid, driver.id::text) AS driver_uid,

          sender.id AS sender_id,
          sender.name AS sender_name

        FROM orders o

        JOIN users passenger
          ON passenger.id = o.passenger_id

        LEFT JOIN users driver
          ON driver.id = o.driver_id

        JOIN users sender
          ON (sender.firebase_uid = $2 OR sender.id::text = $2)

        WHERE
          o.id = $1
          AND (
            passenger.firebase_uid = $2 OR passenger.id::text = $2
            OR driver.firebase_uid = $2 OR driver.id::text = $2
          )

        LIMIT 1
        `,
        [
          req.params.orderId,
          req.user.uid,
        ],
      );

      if (orderResult.rows.length === 0) {
        return res.status(403).json({
          error: 'Chat access denied',
        });
      }

      const order = orderResult.rows[0];

      const recipientId = order.sender_id === order.passenger_id
        ? order.driver_id : order.passenger_id;
      const isActiveTrip = ['accepted', 'driver_arrived', 'in_progress', 'queued']
        .includes(order.status);
      const blocked = await areUsersBlocked(pool, order.sender_id, recipientId);
      if (!canBlockedPairWriteChat({ blocked, activeTrip: isActiveTrip })) {
        return res.status(403).json({ code: 'user_blocked', error: 'Chat is blocked after the trip' });
      }

      const messageResult = await pool.query(
        `
        INSERT INTO order_messages (
          order_id,
          sender_id,
          text
        )
        VALUES (
          $1,
          $2,
          $3
        )
        RETURNING
          id,
          text,
          created_at
        `,
        [
          req.params.orderId,
          order.sender_id,
          text,
        ],
      );

      const message = messageResult.rows[0];

      const recipientUid =
        req.user.uid === order.passenger_uid
          ? order.driver_uid
          : order.passenger_uid;

      if (recipientUid) {
        try {
          await sendPushToUser(recipientUid, {
            title:
              order.sender_name &&
              String(order.sender_name).trim().length > 0
                ? String(order.sender_name).trim()
                : 'Новое сообщение',
            body:
              text.length > 160
                ? `${text.substring(0, 157)}...`
                : text,
            data: {
              type: 'chat_message',
              orderId: req.params.orderId,
              messageId: message.id,
            },
          });
        } catch (pushError) {
          console.error('[ChatMessagePush]', pushError);
        }
      }

      res.status(201).json({
        message: {
          id: message.id,
          senderId: req.user.uid,
          senderName: order.sender_name,
          text: message.text,
          createdAt: message.created_at,
        },
      });
    } catch (error) {
      console.error('[ChatMessageSend]', error);

      res.status(500).json({
        error: 'Failed to send message',
      });
    }
    },
  );


app.get('/api/me', requireAuth, async (req, res) => {
  res.json({
    authenticated: true,
    userId: req.auth?.userId ?? null,
    phone: req.user.phone,
    authType: req.auth?.type ?? 'firebase',
  });
});

app.use(apiErrorHandler);

const port = Number(process.env.PORT || 3000);

const server = http.createServer(app);

const wss = new WebSocketServer({
  server,
  path: '/ws',
});

const clients = new Map();

function sendToUser(uid, payload) {
  const sockets = clients.get(uid);

  if (!sockets) {
    return;
  }

  const message = JSON.stringify(payload);

  for (const socket of sockets) {
    if (socket.readyState === socket.OPEN) {
      socket.send(message);
    }
  }
}

function broadcast(payload) {
  const message = JSON.stringify(payload);

  for (const sockets of clients.values()) {
    for (const socket of sockets) {
      if (socket.readyState === socket.OPEN) {
        socket.send(message);
      }
    }
  }
}

async function sendToAvailableDrivers(payload) {
  try {
    const result = await pool.query(`
      SELECT COALESCE(u.firebase_uid, u.id::text) AS identity_key,
             work_city.slug AS work_city_slug
      FROM users u
      JOIN driver_profiles dp
        ON dp.user_id = u.id
      JOIN cities work_city ON work_city.id = dp.work_city_id
      WHERE
        dp.status = 'active'
        AND ($1::boolean = FALSE OR dp.work_city_id = (
          SELECT id FROM cities WHERE slug = $2 AND is_enabled = TRUE
        ))
        AND NOT EXISTS (
          SELECT 1 FROM orders notification_order
          JOIN user_blocks ub
            ON (ub.blocker_user_id = notification_order.passenger_id AND ub.blocked_user_id = u.id)
            OR (ub.blocker_user_id = u.id AND ub.blocked_user_id = notification_order.passenger_id)
          WHERE notification_order.id = $3
        )
    `, [
      ['city', 'delivery'].includes(payload?.order?.serviceType),
      payload?.order?.cityId ?? null,
      payload?.order?.id ?? null,
    ]);

    const recipients = result.rows.filter((row) =>
      canReceiveLocalOrderNotification(payload?.order, row.work_city_slug));
    for (const row of recipients) {
      if (row.identity_key) {
        sendToUser(row.identity_key, payload);
      }
    }
    if (payload?.type === 'order_created' && payload.order?.id) {
      await Promise.allSettled(recipients
        .filter((row) => row.identity_key)
        .map((row) => sendPushToUser(row.identity_key, {
          data: {
            type: 'new_driver_order',
            orderId: payload.order.id,
            serviceType: payload.order.serviceType,
          },
        })));
    }
  } catch (error) {
    console.error('[WebSocketDrivers]', error);
  }
}

wss.on('connection', async (socket, request) => {
  try {
    const url = new URL(request.url, 'http://localhost');
    const token = url.searchParams.get('token');

    if (!token) {
      socket.close(1008, 'Missing token');
      return;
    }

    const identity = await authenticateIdentity(token);
    const identityKeys = new Set([
      identity.auth.userId,
      identity.auth.firebaseUid,
      identity.user.uid,
    ].filter(Boolean));

    for (const key of identityKeys) {
      if (!clients.has(key)) clients.set(key, new Set());
      clients.get(key).add(socket);
    }

    console.log('[WebSocket] authenticated client connected');

    socket.send(JSON.stringify({
      type: 'connected',
      userId: identity.auth.userId,
      timestamp: new Date().toISOString(),
    }));

    socket.on('message', (message) => {
      try {
        const data = JSON.parse(message.toString());

        if (data.type === 'ping') {
          socket.send(JSON.stringify({
            type: 'pong',
            timestamp: new Date().toISOString(),
          }));
        }
      } catch (error) {
        console.error('[WebSocket] invalid message', error);
      }
    });

    socket.on('close', () => {
      for (const key of identityKeys) {
        const userSockets = clients.get(key);
        if (userSockets) {
          userSockets.delete(socket);
          if (userSockets.size === 0) clients.delete(key);
        }
      }

      console.log('[WebSocket] client disconnected');
    });
  } catch (error) {
    console.error('[WebSocketAuth]', error.code || error.message);
    socket.close(1008, 'Invalid token');
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Tulpar API listening on port ${port}`);
  console.log('Tulpar WebSocket listening on /ws');
});

let accountDeletionRetryRunning = false;
async function runAccountDeletionRetry() {
  if (accountDeletionRetryRunning) return;
  accountDeletionRetryRunning = true;
  try {
    await retryPendingAccountDeletions({
      pool,
      deleteFirebaseUser: (uid) => getAuth().deleteUser(uid),
    });
  } catch (_) {
    console.error('[AccountDeletionRetry] status=failed');
  } finally {
    accountDeletionRetryRunning = false;
  }
}

const accountDeletionRetryTimer = setInterval(
  runAccountDeletionRetry,
  5 * 60 * 1000,
);
accountDeletionRetryTimer.unref();
setTimeout(runAccountDeletionRetry, 10 * 1000).unref();

let authHistoryCleanupRunning = false;
async function runAuthHistoryCleanup() {
  if (authHistoryCleanupRunning) return;
  authHistoryCleanupRunning = true;
  try {
    const removed = await cleanupExpiredAuthHistory({ pool });
    const total = removed.passwordVerifications
      + removed.otpChallenges
      + removed.sessions;
    if (total > 0) {
      console.log(`[AuthHistoryCleanup] removed=${total}`);
    }
  } catch (_) {
    console.error('[AuthHistoryCleanup] status=failed');
  } finally {
    authHistoryCleanupRunning = false;
  }
}

const authHistoryCleanupTimer = setInterval(
  runAuthHistoryCleanup,
  5 * 60 * 1000,
);
authHistoryCleanupTimer.unref();
setTimeout(runAuthHistoryCleanup, 20 * 1000).unref();
