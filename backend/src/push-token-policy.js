const permanentlyInvalidPushTokenCodes = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export function isPermanentlyInvalidPushTokenError(code) {
  return permanentlyInvalidPushTokenCodes.has(code);
}
