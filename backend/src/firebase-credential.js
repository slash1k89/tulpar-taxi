import { existsSync, readFileSync } from 'node:fs';
import { applicationDefault, cert } from 'firebase-admin/app';

const defaultServiceAccountPath =
  '/run/secrets/firebase-service-account.json';

export function resolveFirebaseCredential({
  credentialPath = process.env.GOOGLE_APPLICATION_CREDENTIALS,
  fileExists = existsSync,
  readFile = readFileSync,
  certificate = cert,
  fallback = applicationDefault,
} = {}) {
  const configuredPath = credentialPath?.trim();
  const path = configuredPath || defaultServiceAccountPath;

  if (fileExists(path)) {
    const serviceAccount = JSON.parse(readFile(path, 'utf8'));
    return certificate(serviceAccount);
  }

  // Local tests and developer environments may intentionally use ADC.
  return fallback();
}

export { defaultServiceAccountPath };
