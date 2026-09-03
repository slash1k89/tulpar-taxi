function normalizedPhone(value) {
  return typeof value === 'string' ? value.trim() : '';
}

export function selectUserSyncPhone({
  verifiedPhone,
  legacyBodyPhone,
} = {}) {
  const verified = normalizedPhone(verifiedPhone);
  if (verified.length > 0) {
    return verified;
  }

  // Temporary compatibility path until Tulpar moves to its own SMS auth.
  const legacy = normalizedPhone(legacyBodyPhone);
  return legacy.length > 0 ? legacy : null;
}

export function isSelfOrder({ passengerId, driverId } = {}) {
  if (passengerId === null || passengerId === undefined) return false;
  if (driverId === null || driverId === undefined) return false;
  return String(passengerId) === String(driverId);
}
