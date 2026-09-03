import {
  AutoCallFlashCallProvider,
} from './verification-providers/autocall-flash-call.js';

export class UnavailableVerificationProvider {
  configured = false;
  method = null;

  async requestVerification() {
    throw new Error('verification_provider_unavailable');
  }
}

export function createVerificationProviderFromEnv({
  env = process.env,
  fetchImpl,
} = {}) {
  if ((env.TULPAR_VERIFICATION_PROVIDER ?? 'autocall') !== 'autocall') {
    return new UnavailableVerificationProvider();
  }
  try {
    return new AutoCallFlashCallProvider({
      apiToken: env.AUTOCALL_API_TOKEN,
      apiBaseUrl: env.AUTOCALL_API_BASE,
      digits: env.AUTOCALL_FLASHCALL_DIGITS,
      requestTimeoutMs: env.AUTOCALL_TIMEOUT_MS,
      fetchImpl,
    });
  } catch (_) {
    return new UnavailableVerificationProvider();
  }
}
