import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AutoCallFlashCallError,
  AutoCallFlashCallProvider,
} from '../src/auth/verification-providers/autocall-flash-call.js';
import {
  createVerificationProviderFromEnv,
} from '../src/auth/verification-provider.js';

const token = 'test-autocall-token-never-production';

test('AutoCall success uses the documented contract and returns code internally', async () => {
  let captured;
  const provider = new AutoCallFlashCallProvider({
    apiToken: token,
    fetchImpl: async (url, options) => {
      captured = { url, options };
      return {
        status: 201,
        async json() {
          return { id: 987, code: '0421', number: '+77771234567' };
        },
      };
    },
  });
  const result = await provider.requestVerification('+77771234567');
  assert.equal(captured.url, 'https://autocall.kz/api/v1/flash-calls');
  assert.equal(captured.options.headers.authorization, `Bearer ${token}`);
  assert.deepEqual(JSON.parse(captured.options.body), {
    number: '+77771234567',
    digits: 4,
  });
  assert.deepEqual(result, {
    provider: 'autocall',
    providerRequestId: '987',
    code: '0421',
  });
});

test('AutoCall provider rejection exposes only a safe category', async () => {
  const provider = new AutoCallFlashCallProvider({
    apiToken: token,
    fetchImpl: async () => ({ status: 401 }),
  });
  await assert.rejects(
    provider.requestVerification('+77771234567'),
    (error) => error instanceof AutoCallFlashCallError &&
      error.category === 'provider_rejected' &&
      !error.message.includes(token),
  );
});

test('AutoCall timeout is not retried and remains generic', async () => {
  let calls = 0;
  const provider = new AutoCallFlashCallProvider({
    apiToken: token,
    requestTimeoutMs: 1000,
    fetchImpl: async (_url, { signal }) => {
      calls += 1;
      await new Promise((resolve, reject) => {
        signal.addEventListener('abort', () => {
          const error = new Error('aborted');
          error.name = 'AbortError';
          reject(error);
        });
      });
    },
  });
  await assert.rejects(
    provider.requestVerification('+77771234567'),
    (error) => error.category === 'timeout',
  );
  assert.equal(calls, 1);
});

for (const payload of [
  { id: 'request-1', code: '12345', number: '+77771234567' },
  { id: '', code: '1234', number: '+77771234567' },
  { id: 'request-1', number: '+77771234567' },
]) {
  test(`AutoCall malformed response is rejected: ${JSON.stringify(payload)}`, async () => {
    const provider = new AutoCallFlashCallProvider({
      apiToken: token,
      fetchImpl: async () => ({ status: 201, async json() { return payload; } }),
    });
    await assert.rejects(
      provider.requestVerification('+77771234567'),
      (error) => error.category === 'malformed_response',
    );
  });
}

test('AutoCall factory fails closed without a token or for an unknown provider', () => {
  assert.equal(createVerificationProviderFromEnv({ env: {} }).configured, false);
  assert.equal(createVerificationProviderFromEnv({
    env: { TULPAR_VERIFICATION_PROVIDER: 'unknown' },
  }).configured, false);
});
