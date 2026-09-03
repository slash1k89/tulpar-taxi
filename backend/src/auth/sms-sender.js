export class SmsProviderUnavailableError extends Error {
  constructor() {
    super('sms_provider_unavailable');
    this.code = 'sms_provider_unavailable';
  }
}

export class UnavailableSmsSender {
  configured = false;

  async sendOtp() {
    throw new SmsProviderUnavailableError();
  }
}

export function createSmsSenderFromEnv({ env = process.env, fetchImpl } = {}) {
  if (env.TULPAR_SMS_PROVIDER !== 'mobizon') {
    return new UnavailableSmsSender();
  }
  try {
    return new MobizonSmsSender({
      apiKey: env.MOBIZON_API_KEY,
      sender: env.MOBIZON_SENDER,
      apiBaseUrl: env.MOBIZON_API_BASE,
      template: env.MOBIZON_SMS_TEMPLATE,
      requestTimeoutMs: env.MOBIZON_TIMEOUT_MS,
      fetchImpl,
    });
  } catch (_) {
    return new UnavailableSmsSender();
  }
}
import { MobizonSmsSender } from './sms-providers/mobizon.js';
