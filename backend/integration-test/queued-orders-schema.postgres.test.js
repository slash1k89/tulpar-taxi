import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test, { after, before, beforeEach } from 'node:test';

import {
  assertConnectedToSafeTestDatabase,
  createIntegrationPool,
  splitSqlStatements,
} from './test-db.js';

const databaseName = 'tulpar_queued_order_test';
const pool = createIntegrationPool('tulpar-queued-order-schema');
const users = {
  driver1: '10000000-0000-0000-0000-000000000001',
  driver2: '10000000-0000-0000-0000-000000000002',
  passenger1: '20000000-0000-0000-0000-000000000001',
  passenger2: '20000000-0000-0000-0000-000000000002',
  passenger3: '20000000-0000-0000-0000-000000000003',
};

async function insertOrder({
  id,
  passengerId,
  driverId = null,
  status = 'searching',
  serviceType = 'city',
  agreedPrice = null,
  queuedAfterOrderId = null,
}) {
  const result = await pool.query(
    `INSERT INTO public.orders (
       id, passenger_id, driver_id, status, passenger_price, agreed_price,
       service_type, queued_after_order_id
     ) VALUES (COALESCE($1, gen_random_uuid()), $2, $3, $4, 1000, $5, $6, $7)
     RETURNING id`,
    [
      id ?? null,
      passengerId,
      driverId,
      status,
      agreedPrice,
      serviceType,
      queuedAfterOrderId,
    ],
  );
  return result.rows[0].id;
}

before(async () => {
  await assertConnectedToSafeTestDatabase(pool, databaseName);
  await pool.query(`
    DROP TABLE IF EXISTS public.orders;
    DROP TABLE IF EXISTS public.service_types;
    DROP TABLE IF EXISTS public.users;
    CREATE TABLE public.users (id uuid PRIMARY KEY);
    CREATE TABLE public.service_types (code varchar(30) PRIMARY KEY);
    INSERT INTO public.service_types (code) VALUES ('city'), ('delivery'), ('intercity');
    CREATE TABLE public.orders (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      passenger_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
      driver_id uuid REFERENCES public.users(id) ON DELETE RESTRICT,
      status varchar(30) NOT NULL DEFAULT 'searching',
      passenger_price integer NOT NULL,
      agreed_price integer,
      service_type varchar(30) NOT NULL DEFAULT 'city',
      CONSTRAINT orders_status_check CHECK (
        status IN ('searching','accepted','driver_arrived','in_progress','completed','cancelled','expired')
      )
    );
    CREATE UNIQUE INDEX idx_one_active_order_per_driver
      ON public.orders (driver_id)
      WHERE driver_id IS NOT NULL AND status IN ('accepted','driver_arrived','in_progress');
    CREATE UNIQUE INDEX idx_one_active_order_per_passenger
      ON public.orders (passenger_id)
      WHERE status IN ('searching','accepted','driver_arrived','in_progress');
  `);
  await pool.query(
    'INSERT INTO public.users (id) SELECT unnest($1::uuid[])',
    [Object.values(users)],
  );

  const preflight = await readFile(
    new URL('../migrations/preflight/20260830_006_queued_city_orders_preflight.sql', import.meta.url),
    'utf8',
  );
  for (const statement of splitSqlStatements(preflight)) {
    const result = await pool.query(statement);
    assert.equal(result.rowCount, 0, JSON.stringify(result.rows));
  }

  const migration = await readFile(
    new URL('../migrations/20260830_006_queued_city_orders.sql', import.meta.url),
    'utf8',
  );
  await pool.query(migration);
});

beforeEach(async () => {
  await pool.query('TRUNCATE public.orders');
});

after(async () => {
  await pool.end();
});

test('one current plus one queued order is allowed', async () => {
  const current = await insertOrder({
    passengerId: users.passenger1,
    driverId: users.driver1,
    status: 'in_progress',
    agreedPrice: 1000,
  });
  await insertOrder({
    passengerId: users.passenger2,
    driverId: users.driver1,
    status: 'queued',
    agreedPrice: 1200,
    queuedAfterOrderId: current,
  });
});

test('a second current order for one driver is rejected', async () => {
  await insertOrder({ passengerId: users.passenger1, driverId: users.driver1, status: 'in_progress' });
  await assert.rejects(
    insertOrder({ passengerId: users.passenger2, driverId: users.driver1, status: 'accepted' }),
    (error) => error.code === '23505',
  );
});

test('a second queued order for one driver is rejected', async () => {
  const current = await insertOrder({ passengerId: users.passenger1, driverId: users.driver1, status: 'in_progress' });
  await insertOrder({ passengerId: users.passenger2, driverId: users.driver1, status: 'queued', agreedPrice: 1200, queuedAfterOrderId: current });
  await assert.rejects(
    insertOrder({ passengerId: users.passenger3, driverId: users.driver1, status: 'queued', agreedPrice: 1300, queuedAfterOrderId: current }),
    (error) => error.code === '23505',
  );
});

for (const scenario of [
  ['without driver', { driverId: null, agreedPrice: 1200 }],
  ['without agreed price', { driverId: users.driver1, agreedPrice: null }],
  ['without queued-after order', { driverId: users.driver1, agreedPrice: 1200, queuedAfterOrderId: null }],
  ['for non-CITY service', { driverId: users.driver1, agreedPrice: 1200, serviceType: 'delivery' }],
]) {
  test(`queued order ${scenario[0]} is rejected`, async () => {
    const current = await insertOrder({ passengerId: users.passenger1, driverId: users.driver1, status: 'in_progress' });
    const values = { queuedAfterOrderId: current, ...scenario[1] };
    await assert.rejects(
      insertOrder({ passengerId: users.passenger2, status: 'queued', ...values }),
      (error) => error.code === '23514',
    );
  });
}

test('queued order cannot reference itself', async () => {
  const id = '30000000-0000-0000-0000-000000000001';
  await assert.rejects(
    insertOrder({ id, passengerId: users.passenger1, driverId: users.driver1, status: 'queued', agreedPrice: 1200, queuedAfterOrderId: id }),
    (error) => error.code === '23514',
  );
});

test('passenger with queued order cannot have another active order', async () => {
  const current = await insertOrder({ passengerId: users.passenger1, driverId: users.driver1, status: 'in_progress' });
  await insertOrder({ passengerId: users.passenger2, driverId: users.driver1, status: 'queued', agreedPrice: 1200, queuedAfterOrderId: current });
  await assert.rejects(
    insertOrder({ passengerId: users.passenger2, status: 'searching' }),
    (error) => error.code === '23505',
  );
});

test('existing CITY, DELIVERY and INTERCITY status shapes remain allowed', async () => {
  await insertOrder({ passengerId: users.passenger1, driverId: users.driver1, status: 'accepted', serviceType: 'city', agreedPrice: 1000 });
  await insertOrder({ passengerId: users.passenger2, status: 'searching', serviceType: 'delivery' });
  await insertOrder({ passengerId: users.passenger3, driverId: users.driver2, status: 'completed', serviceType: 'intercity', agreedPrice: 2000 });
});
