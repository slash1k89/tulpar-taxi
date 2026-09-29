const DEFAULT_API_BASE = 'https://api.mobizon.kz/service';
const DEFAULT_TIMEOUT_MS = 8000;
const DEFAULT_TEMPLATE = 'Код MEKEN: {code}. Никому не сообщайте этот код.';

export class MobizonSmsError extends Error {
  constructor(category) {
    super(`mobizon_${category}`);
    this.code = 'sms_send_failed';
    this.category = category;
  }
}

function requiredApiKey(value) {
  if (typeof value !== 'string' || value.trim().length < 8) {
    throw new MobizonSmsError('configuration');
  }
  return value.trim();
}

function apiBase(value = DEFAULT_API_BASE) {
  let url;
  try {
    url = new URL(value);
  } catch (_) {
    throw new MobizonSmsError('configuration');
  }
  if (url.protocol !== 'https:') throw new MobizonSmsError('configuration');
  return url.toString().replace(/\/$/, '');
}

function timeoutMs(value = DEFAULT_TIMEOUT_MS) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1000 || parsed > 30000) {
    throw new MobizonSmsError('configuration');
  }
  return parsed;
}

function messageText(template, code) {
  const selected = typeof template === 'string' && template.length > 0
    ? template
    : DEFAULT_TEMPLATE;
  if (!selected.includes('{code}')) {
    throw new MobizonSmsError('configuration');
  }
  return selected.replaceAll('{code}', code);
}

export class MobizonSmsSender {
  configured = true;

  constructor({
    apiKey,
    sender,
    apiBaseUrl,
    template,
    requestTimeoutMs,
    fetchImpl = globalThis.fetch,
  } = {}) {
    this.apiKey = requiredApiKey(apiKey);
    this.sender = typeof sender === 'string' && sender.trim().length > 0
      ? sender.trim()
      : null;
    this.apiBaseUrl = apiBase(apiBaseUrl);
    this.template = template;
    this.requestTimeoutMs = timeoutMs(requestTimeoutMs);
    if (typeof fetchImpl !== 'function') {
      throw new MobizonSmsError('configuration');
    }
    this.fetchImpl = fetchImpl;
  }

  async sendOtp({ phone, code }) {
    if (typeof phone !== 'string' || !/^\+7\d{10}$/.test(phone)) {
      throw new MobizonSmsError('invalid_request');
    }
    if (typeof code !== 'string' || !/^\d{6}$/.test(code)) {
      throw new MobizonSmsError('invalid_request');
    }
    const url = new URL(`${this.apiBaseUrl}/message/sendSmsMessage`);
    url.searchParams.set('output', 'json');
    url.searchParams.set('api', 'v1');
    url.searchParams.set('apiKey', this.apiKey);
    const body = new URLSearchParams({
      recipient: phone.slice(1),
      text: messageText(this.template, code),
    });
    if (this.sender) body.set('from', this.sender);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.requestTimeoutMs);
    let response;
    try {
      response = await this.fetchImpl(url, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body,
        signal: controller.signal,
      });
    } catch (error) {
      throw new MobizonSmsError(
        error?.name === 'AbortError' ? 'timeout' : 'network',
      );
    } finally {
      clearTimeout(timer);
    }
    if (!response?.ok) throw new MobizonSmsError('provider_rejected');
    let payload;
    try {
      payload = await response.json();
    } catch (_) {
      throw new MobizonSmsError('malformed_response');
    }
    const messageId = payload?.data?.messageId;
    const status = Number(payload?.data?.status);
    if (Number(payload?.code) !== 0 || messageId == null || ![1, 2].includes(status)) {
      throw new MobizonSmsError(
        payload && typeof payload === 'object'
          ? 'provider_rejected'
          : 'malformed_response',
      );
    }
    return { provider: 'mobizon', messageId: String(messageId), status };
  }
}

export const mobizonDefaults = {
  apiBaseUrl: DEFAULT_API_BASE,
  timeoutMs: DEFAULT_TIMEOUT_MS,
  template: DEFAULT_TEMPLATE,
};
