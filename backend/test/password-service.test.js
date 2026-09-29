import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PasswordAuthError,
  hashPassword,
  verifyPassword,
} from '../src/auth/password-service.js';

test('password is stored as a salted scrypt hash and verifies timing-safely', async () => {
  const password = 'correct horse battery staple';
  const first = await hashPassword(password);
  const second = await hashPassword(password);
  assert.doesNotMatch(first, new RegExp(password));
  assert.notEqual(first, second);
  assert.equal(await verifyPassword(password, first), true);
  assert.equal(await verifyPassword('wrong password', first), false);
});

test('password length is limited to 8 through 128 characters', async () => {
  for (const password of ['short', 'x'.repeat(129)]) {
    await assert.rejects(
      hashPassword(password),
      (error) => error instanceof PasswordAuthError && error.code === 'invalid_password',
    );
  }
});
