import express from 'express';
import pg from 'pg';
import { createOrdersRouter } from './routes/orders.js';
import { assertSafeDestructiveTestDatabase } from './smoke-test-guard.js';

assertSafeDestructiveTestDatabase();

const { Pool } = pg;

const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
});

function check(condition, message) {
  if (!condition) {
    throw new Error(`FAILED: ${message}`);
  }

  console.log(`PASS: ${message}`);
}

const suffix = Date.now().toString();

const passengerUid = `api-smoke-passenger-${suffix}`;
const driverUid = `api-smoke-driver-${suffix}`;

const passengerPhone = `+7700${suffix.slice(-7)}`;
const driverPhone = `+7701${suffix.slice(-7)}`;

let passengerId = null;
let driverId = null;

const app = express();
app.use(express.json());

// Это НЕ production-auth.
// Работает только внутри этого отдельного smoke-test процесса.
async function requireTestAuth(req, res, next) {
  const uid = req.header('x-test-uid');

  if (!uid) {
    return res.status(401).json({
      error: 'Missing test uid',
    });
  }

  const result = await pool.query(
    `
    SELECT firebase_uid, phone
    FROM users
    WHERE firebase_uid = $1
    `,
    [uid],
  );

  if (result.rows.length === 0) {
    return res.status(401).json({
      error: 'Unknown test user',
    });
  }

  req.user = {
    uid: result.rows[0].firebase_uid,
    phone: result.rows[0].phone,
  };

  next();
}

async function sendToUser() {}

async function sendToAvailableDrivers() {}

app.use(
  '/api/orders',
  createOrdersRouter({
    pool,
    requireAuth: requireTestAuth,
    sendToUser,
    sendToAvailableDrivers,
  }),
);

const server = app.listen(0, '127.0.0.1');

await new Promise((resolve) => {
  if (server.listening) {
    resolve();
  } else {
    server.once('listening', resolve);
  }
});

const address = server.address();
const baseUrl = `http://127.0.0.1:${address.port}`;

async function api(path, {
  method = 'GET',
  uid,
  body,
} = {}) {
  const headers = {};

  if (uid) {
    headers['x-test-uid'] = uid;
  }

  if (body !== undefined) {
    headers['content-type'] = 'application/json';
  }

  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers,
    body: body !== undefined
      ? JSON.stringify(body)
      : undefined,
  });

  let data = null;

  try {
    data = await response.json();
  } catch (_) {}

  return {
    status: response.status,
    data,
  };
}

async function cleanup() {
  try {
    if (passengerId) {
      await pool.query(
        `
        DELETE FROM orders
        WHERE passenger_id = $1
           OR driver_id = $1
        `,
        [passengerId],
      );
    }

    if (driverId) {
      await pool.query(
        `
        DELETE FROM orders
        WHERE passenger_id = $1
           OR driver_id = $1
        `,
        [driverId],
      );

      await pool.query(
        `
        DELETE FROM driver_profiles
        WHERE user_id = $1
        `,
        [driverId],
      );
    }

    await pool.query(
      `
      DELETE FROM users
      WHERE firebase_uid = ANY($1::text[])
      `,
      [[passengerUid, driverUid]],
    );
  } catch (error) {
    console.error('Cleanup error:', error.message);
  }
}

try {
  console.log('--- Tulpar API services smoke test ---');

  const passengerResult = await pool.query(
    `
    INSERT INTO users (
      firebase_uid,
      phone,
      name
    )
    VALUES ($1, $2, 'API Smoke Passenger')
    RETURNING id
    `,
    [passengerUid, passengerPhone],
  );

  passengerId = passengerResult.rows[0].id;

  const driverResult = await pool.query(
    `
    INSERT INTO users (
      firebase_uid,
      phone,
      name
    )
    VALUES ($1, $2, 'API Smoke Driver')
    RETURNING id
    `,
    [driverUid, driverPhone],
  );

  driverId = driverResult.rows[0].id;

  await pool.query(
    `
    INSERT INTO driver_profiles (
      user_id,
      status,
      car_model,
      car_color,
      car_number,
      agreement_version,
      agreement_accepted_at,
      access_exempt
    )
    VALUES (
      $1,
      'active',
      'Toyota Camry',
      'Black',
      'TEST001',
      '1.0',
      now(),
      TRUE
    )
    `,
    [driverId],
  );

  check(passengerId, 'Passenger prepared');
  check(driverId, 'Driver prepared');
  check(true, 'Driver has permanent test access');

  // 1. Delivery без recipientPhone должен быть отклонён
  const invalidDelivery = await api(
    '/api/orders',
    {
      method: 'POST',
      uid: passengerUid,
      body: {
        serviceType: 'delivery',
        passengerPrice: 900,
        pickupAddress: 'Test pickup',
        destinationAddress: 'Test destination',
        itemDescription: 'Документы',
      },
    },
  );

  check(
    invalidDelivery.status === 400,
    'Delivery without recipient phone rejected',
  );

  // 2. Создаём нормальную доставку
  const deliveryCreate = await api(
    '/api/orders',
    {
      method: 'POST',
      uid: passengerUid,
      body: {
        serviceType: 'delivery',
        passengerPrice: 900,
        pickupAddress: 'ул. Мира, 17',
        destinationAddress: 'ул. Абая, 25',
        pickupLat: 51.1605,
        pickupLng: 71.4704,
        destinationLat: 51.1700,
        destinationLng: 71.4800,
        distanceMeters: 4200,

        itemDescription: 'Документы',

        senderName: 'Отправитель',
        senderPhone: passengerPhone,

        recipientName: 'Получатель',
        recipientPhone: '+77001234567',

        pickupHandoffType: 'door',
        pickupEntrance: '3',
        pickupApartment: '28',
        pickupFloor: '4',
        pickupIntercom: '28',
        pickupComment: 'Вход со двора',

        destinationHandoffType: 'outside',
        destinationComment: 'Получатель встретит у машины',
      },
    },
  );

  check(
    deliveryCreate.status === 201,
    'Delivery created through HTTP API',
  );

  check(
    deliveryCreate.data?.serviceType === 'delivery',
    'Delivery API response contains serviceType',
  );

  const deliveryOrderId = deliveryCreate.data.id;

  // 3. Проверяем запись delivery_details
  const deliveryDb = await pool.query(
    `
    SELECT
      item_description,
      recipient_phone,
      pickup_handoff_type,
      pickup_entrance,
      pickup_apartment,
      destination_handoff_type
    FROM delivery_details
    WHERE order_id = $1
    `,
    [deliveryOrderId],
  );

  check(
    deliveryDb.rows.length === 1,
    'delivery_details created',
  );

  check(
    deliveryDb.rows[0].item_description === 'Документы',
    'Delivery item stored through API',
  );

  check(
    deliveryDb.rows[0].pickup_apartment === '28',
    'Delivery apartment stored through API',
  );

  // 4. Водитель получает delivery через /available
  const availableDelivery = await api(
    '/api/orders/available?serviceType=delivery',
    {
      uid: driverUid,
    },
  );

  check(
    availableDelivery.status === 200,
    'Delivery filter returned HTTP 200',
  );

  const deliveryFromAvailable =
    availableDelivery.data.find(
      (order) => order.id === deliveryOrderId,
    );

  check(
    deliveryFromAvailable,
    'Delivery visible to driver',
  );

  check(
    deliveryFromAvailable.serviceType === 'delivery',
    'Available order marked as delivery',
  );

  check(
    deliveryFromAvailable.delivery?.itemDescription === 'Документы',
    'Driver receives delivery details',
  );

  check(
    deliveryFromAvailable.delivery?.pickupApartment === '28',
    'Driver receives delivery apartment',
  );

  check(
    deliveryFromAvailable.intercity === null,
    'Delivery does not contain intercity details',
  );

  // 5. Проверяем фильтр city
  const cityFilter = await api(
    '/api/orders/available?serviceType=city',
    {
      uid: driverUid,
    },
  );

  check(
    cityFilter.status === 200,
    'City filter returned HTTP 200',
  );

  check(
    !cityFilter.data.some(
      (order) => order.id === deliveryOrderId,
    ),
    'Delivery excluded from city filter',
  );

  // 6. Неверный serviceType
  const invalidFilter = await api(
    '/api/orders/available?serviceType=spaceship',
    {
      uid: driverUid,
    },
  );

  check(
    invalidFilter.status === 400,
    'Invalid service filter rejected',
  );

  // 7. Пассажир может получить полные данные своего заказа
  const passengerDetails = await api(
    `/api/orders/${deliveryOrderId}/details`,
    {
      uid: passengerUid,
    },
  );

  check(
    passengerDetails.status === 200,
    'Passenger can open own order details',
  );

  check(
    passengerDetails.data?.delivery?.recipientPhone ===
      '+77001234567',
    'Passenger can see delivery recipient phone',
  );

  check(
    passengerDetails.data?.role === 'passenger',
    'Passenger role returned in order details',
  );

  // 8. Посторонний водитель до принятия заказа
  // не является участником и не получает details.
  const driverDetailsBeforeAccept = await api(
    `/api/orders/${deliveryOrderId}/details`,
    {
      uid: driverUid,
    },
  );

  check(
    driverDetailsBeforeAccept.status === 403,
    'Unassigned driver cannot open private order details',
  );

  // 9. Водитель принимает delivery-заказ
  const acceptDelivery = await api(
    `/api/orders/${deliveryOrderId}/accept`,
    {
      method: 'POST',
      uid: driverUid,
    },
  );

  check(
    acceptDelivery.status === 200,
    'Driver accepted delivery through HTTP API',
  );

  check(
    acceptDelivery.data?.status === 'accepted',
    'Accepted delivery status returned',
  );

  // 10. После принятия назначенный водитель
  // получает приватные данные, необходимые для выполнения заказа.
  const driverDetailsAfterAccept = await api(
    `/api/orders/${deliveryOrderId}/details`,
    {
      uid: driverUid,
    },
  );

  check(
    driverDetailsAfterAccept.status === 200,
    'Assigned driver can open order details',
  );

  check(
    driverDetailsAfterAccept.data?.role === 'driver',
    'Driver role returned in order details',
  );

  check(
    driverDetailsAfterAccept.data?.delivery?.recipientPhone ===
      '+77001234567',
    'Assigned driver can see recipient phone',
  );

  check(
    driverDetailsAfterAccept.data?.delivery?.senderPhone ===
      passengerPhone,
    'Assigned driver can see sender phone',
  );

  check(
    driverDetailsAfterAccept.data?.passenger?.phone ===
      passengerPhone,
    'Assigned driver can see passenger phone',
  );

  check(
    driverDetailsAfterAccept.data?.delivery?.pickupApartment ===
      '28',
    'Assigned driver receives delivery address details',
  );

  // 7. Второй активный заказ этому пассажиру запрещён
  const duplicateActive = await api(
    '/api/orders',
    {
      method: 'POST',
      uid: passengerUid,
      body: {
        serviceType: 'city',
        passengerPrice: 100000,
        pickupAddress: 'A',
        destinationAddress: 'B',
      },
    },
  );

  check(
    duplicateActive.status === 409,
    'Second active passenger order blocked',
  );

  // Завершаем delivery напрямую в тесте,
  // чтобы можно было проверить intercity.
  await pool.query(
    `
    UPDATE orders
    SET
      status = 'completed',
      completed_at = now(),
      updated_at = now()
    WHERE id = $1
    `,
    [deliveryOrderId],
  );

  // 8. Межгород с прошедшим временем запрещён
  const invalidIntercity = await api(
    '/api/orders',
    {
      method: 'POST',
      uid: passengerUid,
      body: {
        serviceType: 'intercity',
        passengerPrice: 12000,
        pickupAddress: 'Есиль',
        destinationAddress: 'Астана',
        departureAt: '2020-01-01T10:00:00+05:00',
        passengerCount: 2,
        hasLuggage: true,
      },
    },
  );

  check(
    invalidIntercity.status === 400,
    'Past intercity departure rejected',
  );

  // 9. Создаём нормальный межгород
  const departureAt =
    new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

  const intercityCreate = await api(
    '/api/orders',
    {
      method: 'POST',
      uid: passengerUid,
      body: {
        serviceType: 'intercity',
        passengerPrice: 12000,
        pickupAddress: 'Есиль',
        destinationAddress: 'Астана',
        departureAt,
        passengerCount: 2,
        hasLuggage: true,
        intercityComment: 'Один большой чемодан',
      },
    },
  );

  check(
    intercityCreate.status === 201,
    'Intercity created through HTTP API',
  );

  check(
    intercityCreate.data?.serviceType === 'intercity',
    'Intercity API response contains serviceType',
  );

  const intercityOrderId = intercityCreate.data.id;

  // 10. Проверяем intercity_details
  const intercityDb = await pool.query(
    `
    SELECT
      departure_at,
      passenger_count,
      has_luggage,
      comment
    FROM intercity_details
    WHERE order_id = $1
    `,
    [intercityOrderId],
  );

  check(
    intercityDb.rows.length === 1,
    'intercity_details created',
  );

  check(
    intercityDb.rows[0].passenger_count === 2,
    'Intercity passenger count stored through API',
  );

  check(
    intercityDb.rows[0].has_luggage === true,
    'Intercity luggage stored through API',
  );

  check(
    intercityDb.rows[0].comment === 'Один большой чемодан',
    'Intercity comment stored through API',
  );

  // 11. Проверяем /available?serviceType=intercity
  const availableIntercity = await api(
    '/api/orders/available?serviceType=intercity',
    {
      uid: driverUid,
    },
  );

  check(
    availableIntercity.status === 200,
    'Intercity filter returned HTTP 200',
  );

  const intercityFromAvailable =
    availableIntercity.data.find(
      (order) => order.id === intercityOrderId,
    );

  check(
    intercityFromAvailable,
    'Intercity visible to driver',
  );

  check(
    intercityFromAvailable.intercity?.passengerCount === 2,
    'Driver receives intercity passenger count',
  );

  check(
    intercityFromAvailable.intercity?.hasLuggage === true,
    'Driver receives intercity luggage flag',
  );

  check(
    intercityFromAvailable.delivery === null,
    'Intercity does not contain delivery details',
  );

  // 12. История пассажира.
  // Delivery уже completed, intercity пока searching.
  const passengerHistoryBeforeIntercityComplete = await api(
    '/api/orders/history',
    {
      uid: passengerUid,
    },
  );

  check(
    passengerHistoryBeforeIntercityComplete.status === 200,
    'Passenger history returned HTTP 200',
  );

  check(
    Array.isArray(
      passengerHistoryBeforeIntercityComplete.data?.orders,
    ),
    'Passenger history contains orders array',
  );

  const deliveryFromHistory =
    passengerHistoryBeforeIntercityComplete.data.orders.find(
      (order) => order.id === deliveryOrderId,
    );

  check(
    deliveryFromHistory,
    'Completed delivery visible in passenger history',
  );

  check(
    deliveryFromHistory.serviceType === 'delivery',
    'History delivery has correct serviceType',
  );

  check(
    deliveryFromHistory.status === 'completed',
    'History delivery has completed status',
  );

  check(
    deliveryFromHistory.role === 'passenger',
    'Passenger history returns passenger role',
  );

  check(
    deliveryFromHistory.delivery?.itemDescription === 'Документы',
    'History returns delivery details',
  );

  check(
    deliveryFromHistory.delivery?.pickupApartment === '28',
    'History returns delivery apartment details',
  );

  // Активный межгород в историю попадать не должен.
  const activeIntercityInHistory =
    passengerHistoryBeforeIntercityComplete.data.orders.find(
      (order) => order.id === intercityOrderId,
    );

  check(
    !activeIntercityInHistory,
    'Active intercity excluded from history',
  );

  // Завершаем межгород.
  await pool.query(
    `
    UPDATE orders
    SET
      status = 'completed',
      completed_at = now(),
      updated_at = now()
    WHERE id = $1
    `,
    [intercityOrderId],
  );

  // Повторно получаем историю.
  const passengerHistoryAfterIntercityComplete = await api(
    '/api/orders/history',
    {
      uid: passengerUid,
    },
  );

  check(
    passengerHistoryAfterIntercityComplete.status === 200,
    'Passenger history reload returned HTTP 200',
  );

  const intercityFromHistory =
    passengerHistoryAfterIntercityComplete.data.orders.find(
      (order) => order.id === intercityOrderId,
    );

  check(
    intercityFromHistory,
    'Completed intercity visible in passenger history',
  );

  check(
    intercityFromHistory.serviceType === 'intercity',
    'History intercity has correct serviceType',
  );

  check(
    intercityFromHistory.status === 'completed',
    'History intercity has completed status',
  );

  check(
    intercityFromHistory.role === 'passenger',
    'History intercity returns passenger role',
  );

  check(
    intercityFromHistory.intercity?.passengerCount === 2,
    'History returns intercity passenger count',
  );

  check(
    intercityFromHistory.intercity?.hasLuggage === true,
    'History returns intercity luggage flag',
  );

  check(
    intercityFromHistory.intercity?.comment ===
      'Один большой чемодан',
    'History returns intercity comment',
  );

  // 13. История водителя.
  // Delivery был принят этим тестовым водителем.
  const driverHistory = await api(
    '/api/orders/history',
    {
      uid: driverUid,
    },
  );

  check(
    driverHistory.status === 200,
    'Driver history returned HTTP 200',
  );

  check(
    Array.isArray(driverHistory.data?.orders),
    'Driver history contains orders array',
  );

  const deliveryFromDriverHistory =
    driverHistory.data.orders.find(
      (order) => order.id === deliveryOrderId,
    );

  check(
    deliveryFromDriverHistory,
    'Completed delivery visible in driver history',
  );

  check(
    deliveryFromDriverHistory.role === 'driver',
    'Driver history returns driver role',
  );

  check(
    deliveryFromDriverHistory.serviceType === 'delivery',
    'Driver history preserves delivery serviceType',
  );

  console.log('');
  console.log('ALL API SERVICE TESTS PASSED');
} catch (error) {
  console.error('');
  console.error(error);
  process.exitCode = 1;
} finally {
  await cleanup();

  await new Promise((resolve) => {
    server.close(resolve);
  });

  await pool.end();
}
