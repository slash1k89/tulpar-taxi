import test from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import request from 'supertest';

import { createOrdersRouter } from '../src/routes/orders.js';

const fakeAuth = (req, _res, next) => {
  req.user = { uid: 'passenger-uid' };
  next();
};

function appWithPool(pool) {
  const app = express();
  app.use(express.json());
  app.use('/api/orders', createOrdersRouter({
    pool,
    requireAuth: fakeAuth,
    sendToUser: () => {},
    sendToAvailableDrivers: () => {},
    sendPushToUser: async () => ({ successCount: 0, failureCount: 0 }),
  }));
  return app;
}

function passengerPool(row) {
  return {
    async query(sql) {
      const query = String(sql).replace(/\s+/g, ' ').trim();
      if (query.startsWith('UPDATE orders o')) return { rows: [] };
      if (query.includes('FROM users u') && query.includes('JOIN orders o')) {
        assert.match(query, /o\.passenger_id = u\.id AND o\.status IN \([^)]*'queued'/);
        assert.match(query, /o\.driver_id = u\.id AND o\.status IN \([^)]*'in_progress'/);
        const driverBranch = query.match(
          /o\.driver_id = u\.id AND o\.status IN \(([^)]*)\)/,
        )?.[1] ?? '';
        assert.doesNotMatch(driverBranch, /'queued'/);
        assert.match(query, /LEFT JOIN users assigned_driver/);
        assert.match(query, /LEFT JOIN driver_profiles dp/);
        assert.doesNotMatch(query, /queued_after_order_id|previous_order/);
        return { rows: row == null ? [] : [row] };
      }
      throw new Error(`Unexpected query: ${query}`);
    },
  };
}

function activeRow(status) {
  return {
    id: 'queued-order',
    passenger_id: 'passenger-1',
    driver_id: 'driver-1',
    current_user_id: 'passenger-1',
    service_type: 'city',
    status,
    passenger_price: 1400,
    agreed_price: 1600,
    pickup_address: 'Passenger pickup',
    destination_address: 'Passenger destination',
    pickup_lat: 51.95,
    pickup_lng: 66.40,
    destination_lat: 51.97,
    destination_lng: 66.42,
    driver_name: 'Alexey',
    car_model: 'Toyota Camry',
    car_color: 'Blue',
    car_number: '123 ABC',
    driver_lat: 51.96,
    driver_lng: 66.41,
  };
}

test('passenger queued order is restored with assigned driver and car', async () => {
  const response = await request(appWithPool(passengerPool(activeRow('queued'))))
    .get('/api/orders/active/me');

  assert.equal(response.status, 200);
  assert.equal(response.body.activeOrder.status, 'queued');
  assert.equal(response.body.activeOrder.role, 'passenger');
  assert.equal(response.body.activeOrder.driverId, 'driver-1');
  assert.equal(response.body.activeOrder.driverName, 'Alexey');
  assert.equal(response.body.activeOrder.carModel, 'Toyota Camry');
  assert.equal(response.body.activeOrder.carColor, 'Blue');
  assert.equal(response.body.activeOrder.carNumber, '123 ABC');
  assert.equal(response.body.activeOrder.pickupAddress, 'Passenger pickup');
  assert.equal(
    response.body.activeOrder.destinationAddress,
    'Passenger destination',
  );
  assert.equal('previousOrder' in response.body.activeOrder, false);
  assert.equal('queuedAfterOrderId' in response.body.activeOrder, false);
});

test('existing passenger active statuses remain supported', async () => {
  for (const status of ['searching', 'accepted', 'driver_arrived', 'in_progress']) {
    const response = await request(appWithPool(passengerPool(activeRow(status))))
      .get('/api/orders/active/me');
    assert.equal(response.status, 200);
    assert.equal(response.body.activeOrder.status, status);
  }
});

test('completed and cancelled orders are not active', async () => {
  for (const status of ['completed', 'cancelled']) {
    const response = await request(appWithPool(passengerPool(null)))
      .get('/api/orders/active/me');
    assert.equal(response.status, 200);
    assert.equal(response.body.activeOrder, null, status);
  }
});

test('driver active lookup still excludes queued and returns in_progress', async () => {
  const pool = {
    async query(sql) {
      const query = String(sql).replace(/\s+/g, ' ').trim();
      assert.match(query, /driver\.firebase_uid = \$1/);
      const statuses = query.match(/o\.status IN \(([^)]*)\)/)?.[1] ?? '';
      assert.match(statuses, /'in_progress'/);
      assert.doesNotMatch(statuses, /'queued'/);
      return {
        rows: [{
          id: 'current-order',
          service_type: 'city',
          status: 'in_progress',
          passenger_price: 1400,
          agreed_price: 1600,
          pickup_address: 'Pickup',
          destination_address: 'Destination',
          pickup_lat: 51.95,
          pickup_lng: 66.40,
          destination_lat: 51.97,
          destination_lng: 66.42,
          passenger_id: 'passenger-1',
          passenger_name: 'Passenger',
          passenger_phone: '+70000000000',
          passenger_rating: 5,
        }],
      };
    },
  };
  const response = await request(appWithPool(pool)).get('/api/orders/active/driver');
  assert.equal(response.status, 200);
  assert.equal(response.body.activeOrder.id, 'current-order');
  assert.equal(response.body.activeOrder.status, 'in_progress');
});
