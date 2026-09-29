import assert from 'node:assert/strict';
import test from 'node:test';
import { isPermanentlyInvalidPushTokenError } from '../src/push-token-policy.js';

test('recognizes only permanent invalid-token responses', () => {
  assert.equal(
    isPermanentlyInvalidPushTokenError(
      'messaging/registration-token-not-registered',
    ),
    true,
  );
  assert.equal(
    isPermanentlyInvalidPushTokenError('messaging/invalid-registration-token'),
    true,
  );
});

test('does not delete tokens for configuration or payload errors', () => {
  assert.equal(
    isPermanentlyInvalidPushTokenError('messaging/mismatched-credential'),
    false,
  );
  assert.equal(
    isPermanentlyInvalidPushTokenError('messaging/invalid-argument'),
    false,
  );
  assert.equal(isPermanentlyInvalidPushTokenError('unknown'), false);
});
