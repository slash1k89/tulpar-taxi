import assert from 'node:assert/strict';
import test from 'node:test';

import {
  MobizonSmsError,
  MobizonSmsSender,
} from '../src/auth/sms-providers/mobizon.js';
import {
  UnavailableSmsSender,
  createSmsSenderFromEnv,
} from '../src/auth/sms-sender.js';

const apiKey = 'test-api-key-never-log-this';

function successResponse(payload = {
  code: 0,
  data: { campaignId: 10, messageId: 20, status: 2 },
}) {
  return { ok: true, json: async () => payload };
}

test('Mobizon success sends normalized recipient and internal OTP payload', async () => {
  let captured;
  const sender = new MobizonSmsSender({
    apiKey,
    sender: 'TULPAR',
    fetchImpl: async (url, options) => {
      captured = { url, options };
      return successResponse();
    },
  });
  const result = await sender.sendOtp({ phone: '+77771234567', code: '123456' });
  assert.deepEqual(result, { provider: 'mobizon', messageId: '20', status: 2 });
  assert.equal(captured.options.body.get('recipient'), '77771234567');
  assert.equal(captured.options.body.get('text').includes('123456'), true);
  assert.equal(captured.options.body.get('from'), 'TULPAR');
});

test('provider rejection returns a safe error without credentials or OTP', async () => {
  const sender = new MobizonSmsSender({
    apiKey,
    fetchImpl: async () => successResponse({ code: 1, message: apiKey }),
  });
  await assert.rejects(
    sender.sendOtp({ phone: '+77771234567', code: '123456' }),
    (error) => error instanceof MobizonSmsError &&
      error.category === 'provider_rejected' &&
      !error.message.includes(apiKey) && !error.message.includes('123456'),
  );
});

test('Mobizon timeout is classified safely', async () => {
  const sender = new MobizonSmsSender({
    apiKey,
    requestTimeoutMs: 1000,
    fetchImpl: (_url, { signal }) => new Promise((_, reject) => {
      signal.addEventListener('abort', () => {
        const error = new Error('aborted');
        error.name = 'AbortError';
        reject(error);
      });
    }),
  });
  await assert.rejects(
    sender.sendOtp({ phone: '+77771234567', code: '123456' }),
    (error) => error.category === 'timeout',
  );
});

test('malformed Mobizon response is rejected', async () => {
  const sender = new MobizonSmsSender({
    apiKey,
    fetchImpl: async () => ({ ok: true, json: async () => { throw new Error('html'); } }),
  });
  await assert.rejects(
    sender.sendOtp({ phone: '+77771234567', code: '123456' }),
    (error) => error.category === 'malformed_response',
  );
});

test('network failure is classified without leaking provider details', async () => {
  const sender = new MobizonSmsSender({
    apiKey,
    fetchImpl: async () => { throw new Error(`network ${apiKey}`); },
  });
  await assert.rejects(
    sender.sendOtp({ phone: '+77771234567', code: '123456' }),
    (error) => error.category === 'network' && !error.message.includes(apiKey),
  );
});

test('missing or invalid environment configuration stays unavailable', () => {
  assert.equal(createSmsSenderFromEnv({ env: {} }) instanceof UnavailableSmsSender, true);
  assert.equal(createSmsSenderFromEnv({ env: {
    TULPAR_SMS_PROVIDER: 'mobizon', MOBIZON_API_KEY: '',
  } }) instanceof UnavailableSmsSender, true);
  assert.equal(createSmsSenderFromEnv({ env: {
    TULPAR_SMS_PROVIDER: 'mobizon',
    MOBIZON_API_KEY: apiKey,
    MOBIZON_API_BASE: 'http://api.mobizon.kz/service',
  } }) instanceof UnavailableSmsSender, true);
});
