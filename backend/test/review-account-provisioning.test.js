import assert from 'node:assert/strict';
import test from 'node:test';

import {
  parseReviewAccountArgs,
  provisionReviewAccounts,
} from '../scripts/provision-review-accounts.js';

test('review credentials come from runtime environment', () => {
  const parsed = parseReviewAccountArgs(
    ['--city', 'esil', '--car-model', 'Test Car', '--car-color', 'White', '--car-number', 'TEST01'],
    {
      REVIEW_PASSENGER_PHONE: '+77001234567',
      REVIEW_PASSENGER_PASSWORD: 'passenger-secret',
      REVIEW_DRIVER_PHONE: '+77007654321',
      REVIEW_DRIVER_PASSWORD: 'driver-secret',
    },
  );
  assert.equal(parsed.passengerPassword, 'passenger-secret');
  assert.equal(parsed.driverPassword, 'driver-secret');
  assert.equal(parsed.city, 'esil');
});

test('review provisioning creates ordinary users and approved driver transactionally', async () => {
  const calls = [];
  let userNumber = 0;
  const client = {
    async query(sql, values) {
      calls.push({ sql, values });
      if (sql.includes('SELECT phone_normalized')) return { rowCount: 0, rows: [] };
      if (sql.includes('SELECT id FROM cities')) return { rowCount: 1, rows: [{ id: 1 }] };
      if (sql.includes('INSERT INTO users')) {
        userNumber += 1;
        return { rowCount: 1, rows: [{ id: `user-${userNumber}` }] };
      }
      return { rowCount: 1, rows: [] };
    },
    release() {},
  };
  const result = await provisionReviewAccounts(
    { connect: async () => client },
    {
      passengerPhone: '+77001234567', passengerPassword: 'passenger-secret',
      driverPhone: '+77007654321', driverPassword: 'driver-secret', city: 'esil',
      carModel: 'Test Car', carColor: 'White', carNumber: 'TEST01',
    },
  );
  assert.deepEqual(result, { passengerUserId: 'user-1', driverUserId: 'user-2', city: 'esil' });
  assert.equal(calls.at(-1).sql, 'COMMIT');
  const driverInsert = calls.find((call) => call.sql.includes('INSERT INTO driver_profiles'));
  assert.match(driverInsert.sql, /'active'/);
  assert.doesNotMatch(driverInsert.sql, /access_exempt/);
  assert.equal(calls.some((call) => call.sql.includes('user_terms_acceptances')), false);
});

test('review provisioning refuses to overwrite an existing phone identity', async () => {
  const calls = [];
  const client = {
    async query(sql) {
      calls.push(sql);
      if (sql.includes('SELECT phone_normalized')) return { rowCount: 1, rows: [{}] };
      return { rowCount: 1, rows: [] };
    },
    release() {},
  };
  await assert.rejects(
    provisionReviewAccounts(
      { connect: async () => client },
      {
        passengerPhone: '+77001234567', passengerPassword: 'passenger-secret',
        driverPhone: '+77007654321', driverPassword: 'driver-secret', city: 'esil',
        carModel: 'Test Car', carColor: 'White', carNumber: 'TEST01',
      },
    ),
    /review_phone_already_exists/,
  );
  assert.equal(calls.at(-1), 'ROLLBACK');
});
