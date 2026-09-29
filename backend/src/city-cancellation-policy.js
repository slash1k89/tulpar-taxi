const activeStatuses = new Set(['accepted', 'driver_arriving', 'driver_arrived', 'arrived', 'in_progress']);
const passengerReasons = new Set([
  'plans_changed', 'car_problem', 'driver_problem', 'emergency', 'other',
]);
const driverReasons = new Set([
  'car_breakdown', 'road_incident', 'passenger_requested',
  'passenger_problem', 'emergency', 'other',
]);

export function canCancelCityOrder(status, role) {
  if (role === 'passenger') return status === 'searching' || status === 'queued' || activeStatuses.has(status);
  return role === 'driver' && activeStatuses.has(status);
}

export function validateCityCancellationReason({ status, role, reasonCode, reasonText }) {
  const validCodes = role === 'driver' ? driverReasons : passengerReasons;
  if (status === 'in_progress' && !validCodes.has(reasonCode)) {
    return { ok: false, error: 'cancellation_reason_required' };
  }
  if (reasonCode != null && !validCodes.has(reasonCode)) {
    return { ok: false, error: 'invalid_cancellation_reason' };
  }
  if (reasonText != null && (typeof reasonText !== 'string' || reasonText.trim().length > 500)) {
    return { ok: false, error: 'invalid_cancellation_reason_text' };
  }
  return {
    ok: true,
    reasonCode: reasonCode ?? null,
    reasonText: reasonCode === 'other' ? (reasonText?.trim() || null) : null,
  };
}
