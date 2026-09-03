const DEFAULT_API_BASE = 'https://autocall.kz/api/v1';
const DEFAULT_TIMEOUT_MS = 8000;
const DEFAULT_DIGITS = 4;

export class AutoCallFlashCallError extends Error {
  constructor(category) {
    super(`autocall_${category}`);
    this.code = 'verification_send_failed';
    this.category = category;
  }
}

function requiredToken(value) {
  if (typeof value !== 'string' || value.trim().length < 8) {
    throw new AutoCallFlashCallError('configuration');
  }
  return value.trim();
}

function apiBase(value = DEFAULT_API_BASE) {
  let url;
  try {
    url = new URL(value);
  } catch (_) {
    throw new AutoCallFlashCallError('configuration');
  }
  if (url.protocol !== 'https:') {
    throw new AutoCallFlashCallError('configuration');
  }
  return url.toString().replace(/\/$/, '');
}

function integerSetting(value, fallback, min, max) {
  if (value === undefined || value === '') return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < min || parsed > max) {
    throw new AutoCallFlashCallError('configuration');
  }
  return parsed;
}

export class AutoCallFlashCallProvider {
  configured = true;
  method = 'flash_call';
  provider = 'autocall';

  constructor({
    apiToken,
    apiBaseUrl,
    digits,
    requestTimeoutMs,
    fetchImpl = globalThis.fetch,
  } = {}) {
    this.apiToken = requiredToken(apiToken);
    this.apiBaseUrl = apiBase(apiBaseUrl);
    this.digits = integerSetting(digits, DEFAULT_DIGITS, 4, 4);
    this.requestTimeoutMs = integerSetting(
      requestTimeoutMs,
      DEFAULT_TIMEOUT_MS,
      1000,
      30000,
    );
    if (typeof fetchImpl !== 'function') {
      throw new AutoCallFlashCallError('configuration');
    }
    this.fetchImpl = fetchImpl;
  }

  async requestVerification(phone) {
    if (typeof phone !== 'string' || !/^\+7\d{10}$/.test(phone)) {
      throw new AutoCallFlashCallError('invalid_request');
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.requestTimeoutMs);
    let response;
    try {
      response = await this.fetchImpl(`${this.apiBaseUrl}/flash-calls`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${this.apiToken}`,
          'content-type': 'application/json',
          accept: 'application/json',
        },
        body: JSON.stringify({ number: phone, digits: this.digits }),
        signal: controller.signal,
      });
    } catch (error) {
      throw new AutoCallFlashCallError(
        error?.name === 'AbortError' ? 'timeout' : 'network',
      );
    } finally {
      clearTimeout(timer);
    }
    if (response?.status !== 201) {
      throw new AutoCallFlashCallError('provider_rejected');
    }
    let payload;
    try {
      payload = await response.json();
    } catch (_) {
      throw new AutoCallFlashCallError('malformed_response');
    }
    const providerRequestId = payload?.id;
    const code = payload?.code;
    if (
      !['string', 'number'].includes(typeof providerRequestId) ||
      String(providerRequestId).trim().length === 0 ||
      typeof code !== 'string' ||
      !/^\d{4}$/.test(code)
    ) {
      throw new AutoCallFlashCallError('malformed_response');
    }
    return {
      provider: this.provider,
      providerRequestId: String(providerRequestId),
      code,
    };
  }
}

export const autoCallDefaults = {
  apiBaseUrl: DEFAULT_API_BASE,
  timeoutMs: DEFAULT_TIMEOUT_MS,
  digits: DEFAULT_DIGITS,
};
