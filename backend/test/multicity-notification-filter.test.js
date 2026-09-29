import assert from 'node:assert/strict';
import test from 'node:test';

import { canReceiveLocalOrderNotification } from '../src/city-scope.js';

test('CITY and DELIVERY notifications stay inside the driver work city', () => {
  for (const serviceType of ['city', 'delivery']) {
    const order = { serviceType, cityId: 'rudny' };
    assert.equal(canReceiveLocalOrderNotification(order, 'rudny'), true);
    assert.equal(canReceiveLocalOrderNotification(order, 'esil'), false);
    assert.equal(canReceiveLocalOrderNotification({ serviceType }, 'esil'), false);
  }
});

test('intercity notification flow is not restricted by local work city', () => {
  assert.equal(canReceiveLocalOrderNotification({ serviceType: 'intercity' }, 'esil'), true);
});
