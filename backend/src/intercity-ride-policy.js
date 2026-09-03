export const intercityRideLimits = Object.freeze({
  city: 120,
  comment: 1000,
  pickupAddress: 500,
  passengerComment: 1000,
  seats: 7,
  pricePerSeat: 1_000_000,
});

function optionalPickup(source) {
  const pickupFields = ['pickupAddress', 'pickupLat', 'pickupLng'];
  const present = pickupFields.map((field) => Object.hasOwn(source, field));
  let pickupAddress = null;
  let pickupLat = null;
  let pickupLng = null;

  if (present.some(Boolean)) {
    if (!present.every(Boolean)) {
      return invalid('pickup fields must be provided together');
    }
    if (typeof source.pickupAddress !== 'string') {
      return invalid('pickupAddress must be a string');
    }
    pickupAddress = source.pickupAddress.trim();
    if (!pickupAddress || pickupAddress.length > intercityRideLimits.pickupAddress) {
      return invalid('pickupAddress is invalid');
    }
    if (
      typeof source.pickupLat !== 'number'
      || !Number.isFinite(source.pickupLat)
      || source.pickupLat < -90
      || source.pickupLat > 90
    ) {
      return invalid('pickupLat is invalid');
    }
    if (
      typeof source.pickupLng !== 'number'
      || !Number.isFinite(source.pickupLng)
      || source.pickupLng < -180
      || source.pickupLng > 180
    ) {
      return invalid('pickupLng is invalid');
    }
    pickupLat = source.pickupLat;
    pickupLng = source.pickupLng;
  }

  if (
    Object.hasOwn(source, 'passengerComment')
    && typeof source.passengerComment !== 'string'
  ) {
    return invalid('passengerComment must be a string');
  }
  const passengerComment = source.passengerComment?.trim() || null;
  if (
    passengerComment
    && passengerComment.length > intercityRideLimits.passengerComment
  ) {
    return invalid('passengerComment is too long');
  }
  return {
    ok: true,
    value: { pickupAddress, pickupLat, pickupLng, passengerComment },
  };
}

const forbiddenFields = new Set([
  'driverId', 'driver_id', 'status', 'availableSeats', 'available_seats',
  'originCityKey', 'origin_city_key', 'destinationCityKey',
  'destination_city_key', 'createdAt', 'created_at', 'updatedAt', 'updated_at',
  'cancelledAt', 'departedAt', 'completedAt',
]);

function invalid(error) {
  return { ok: false, error };
}

export function normalizeIntercityCity(value) {
  if (typeof value !== 'string') return null;
  const display = value.normalize('NFC').trim().replace(/\s+/gu, ' ');
  if (!display || display.length > intercityRideLimits.city) return null;
  const key = display.toLocaleLowerCase('ru-RU').replace(/ё/gu, 'е');
  return { display, key };
}

function coordinates(source, prefix, { optional = true } = {}) {
  const lat = source[`${prefix}Lat`];
  const lng = source[`${prefix}Lng`];
  const missingLat = lat === undefined || lat === null;
  const missingLng = lng === undefined || lng === null;
  if (missingLat && missingLng && optional) return { ok: true, lat: null, lng: null };
  if (missingLat !== missingLng || missingLat) return invalid(`${prefix} coordinates must be provided together`);
  if (typeof lat !== 'number' || !Number.isFinite(lat) || lat < -90 || lat > 90) {
    return invalid(`${prefix} latitude is invalid`);
  }
  if (typeof lng !== 'number' || !Number.isFinite(lng) || lng < -180 || lng > 180) {
    return invalid(`${prefix} longitude is invalid`);
  }
  return { ok: true, lat, lng };
}

function common(body, { now, partial }) {
  const source = body && typeof body === 'object' && !Array.isArray(body) ? body : {};
  for (const field of forbiddenFields) {
    if (Object.hasOwn(source, field)) return invalid(`${field} cannot be set by client`);
  }
  const value = {};
  for (const prefix of ['origin', 'destination']) {
    const cityField = `${prefix}City`;
    if (!partial || Object.hasOwn(source, cityField)) {
      const city = normalizeIntercityCity(source[cityField]);
      if (!city) return invalid(`${cityField} is invalid`);
      value[cityField] = city.display;
      value[`${prefix}CityKey`] = city.key;
    }
    const hasCoordinate = Object.hasOwn(source, `${prefix}Lat`) || Object.hasOwn(source, `${prefix}Lng`);
    if (!partial || hasCoordinate) {
      const pair = coordinates(source, prefix);
      if (!pair.ok) return pair;
      value[`${prefix}Lat`] = pair.lat;
      value[`${prefix}Lng`] = pair.lng;
    }
  }
  if (!partial || Object.hasOwn(source, 'departureAt')) {
    if (typeof source.departureAt !== 'string') return invalid('departureAt must be a future date');
    const departureAt = new Date(source.departureAt);
    if (Number.isNaN(departureAt.getTime()) || departureAt <= now) return invalid('departureAt must be a future date');
    value.departureAt = departureAt;
  }
  if (!partial || Object.hasOwn(source, 'totalSeats')) {
    if (!Number.isInteger(source.totalSeats) || source.totalSeats < 1 || source.totalSeats > intercityRideLimits.seats) {
      return invalid('totalSeats must be from 1 to 7');
    }
    value.totalSeats = source.totalSeats;
  }
  if (!partial || Object.hasOwn(source, 'pricePerSeat')) {
    if (!Number.isInteger(source.pricePerSeat) || source.pricePerSeat < 1 || source.pricePerSeat > intercityRideLimits.pricePerSeat) {
      return invalid('pricePerSeat is invalid');
    }
    value.pricePerSeat = source.pricePerSeat;
  }
  if (!partial || Object.hasOwn(source, 'allowsLuggage')) {
    if (typeof (source.allowsLuggage ?? false) !== 'boolean') return invalid('allowsLuggage must be boolean');
    value.allowsLuggage = source.allowsLuggage ?? false;
  }
  if (!partial || Object.hasOwn(source, 'comment')) {
    if (source.comment !== null && source.comment !== undefined && typeof source.comment !== 'string') return invalid('comment must be a string');
    const comment = source.comment?.trim() || null;
    if (comment && comment.length > intercityRideLimits.comment) return invalid('comment is too long');
    value.comment = comment;
  }
  if (value.originCityKey && value.destinationCityKey && value.originCityKey === value.destinationCityKey) {
    return invalid('Origin and destination cities must be different');
  }
  return { ok: true, value };
}

export function validateIntercityRideCreate(body, options = {}) {
  return common(body, { now: options.now ?? new Date(), partial: false });
}

export function validateIntercityRidePatch(body, options = {}) {
  const source = body && typeof body === 'object' && !Array.isArray(body) ? body : {};
  const allowed = new Set(['originCity', 'originLat', 'originLng', 'destinationCity', 'destinationLat', 'destinationLng', 'departureAt', 'totalSeats', 'pricePerSeat', 'allowsLuggage', 'comment']);
  for (const key of Object.keys(source)) {
    if (!allowed.has(key) && !forbiddenFields.has(key)) return invalid(`Unknown field: ${key}`);
  }
  if (Object.keys(source).length === 0) return invalid('No fields to update');
  return common(source, { now: options.now ?? new Date(), partial: true });
}

export function validateIntercityRideSearch(query) {
  const origin = normalizeIntercityCity(query.originCity);
  const destination = normalizeIntercityCity(query.destinationCity);
  if (!origin || !destination || origin.key === destination.key) return invalid('Invalid route cities');
  if (typeof query.travelDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(query.travelDate)) return invalid('Invalid travelDate');
  const [year, month, day] = query.travelDate.split('-').map(Number);
  const calendarCheck = new Date(Date.UTC(year, month - 1, day));
  if (calendarCheck.getUTCFullYear() !== year || calendarCheck.getUTCMonth() !== month - 1 || calendarCheck.getUTCDate() !== day) return invalid('Invalid travelDate');
  const start = new Date(`${query.travelDate}T00:00:00+05:00`);
  if (Number.isNaN(start.getTime())) return invalid('Invalid travelDate');
  const seats = Number(query.seats ?? 1);
  if (!Number.isInteger(seats) || seats < 1 || seats > intercityRideLimits.seats) return invalid('Invalid seats');
  return { ok: true, value: { originCityKey: origin.key, destinationCityKey: destination.key, start, end: new Date(start.getTime() + 86_400_000), seats } };
}

export function validateIntercityRideBooking(body) {
  const source = body && typeof body === 'object' && !Array.isArray(body)
    ? body
    : {};
  const allowed = new Set([
    'seats',
    'clientRequestId',
    'pickupAddress',
    'pickupLat',
    'pickupLng',
    'passengerComment',
  ]);
  for (const key of Object.keys(source)) {
    if (!allowed.has(key)) return invalid(`${key} cannot be set by client`);
  }
  if (
    !Number.isInteger(source.seats)
    || source.seats < 1
    || source.seats > intercityRideLimits.seats
  ) {
    return invalid('seats must be an integer from 1 to 7');
  }
  if (!isUuid(source.clientRequestId)) {
    return invalid('clientRequestId must be a UUID');
  }
  const pickup = optionalPickup(source);
  if (!pickup.ok) return pickup;
  return {
    ok: true,
    value: {
      seats: source.seats,
      clientRequestId: source.clientRequestId,
      ...pickup.value,
    },
  };
}

function validCalendarDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return (
    date.getUTCFullYear() === year
    && date.getUTCMonth() === month - 1
    && date.getUTCDate() === day
  );
}

function kazakhstanCalendarDate(now) {
  return new Date(now.getTime() + 5 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}

export function validateIntercityRideRequestCreate(body, options = {}) {
  const source = body && typeof body === 'object' && !Array.isArray(body)
    ? body
    : {};
  const allowed = new Set([
    'originCity',
    'destinationCity',
    'travelDate',
    'seats',
    'pickupAddress',
    'pickupLat',
    'pickupLng',
    'passengerComment',
  ]);
  for (const key of Object.keys(source)) {
    if (!allowed.has(key)) return invalid(`${key} cannot be set by client`);
  }

  const origin = normalizeIntercityCity(source.originCity);
  const destination = normalizeIntercityCity(source.destinationCity);
  if (!origin) return invalid('originCity is invalid');
  if (!destination) return invalid('destinationCity is invalid');
  if (origin.key === destination.key) {
    return invalid('Origin and destination cities must be different');
  }
  if (!validCalendarDate(source.travelDate)) {
    return invalid('travelDate must be a valid future date');
  }
  const now = options.now ?? new Date();
  if (source.travelDate <= kazakhstanCalendarDate(now)) {
    return invalid('travelDate must be a valid future date');
  }
  if (
    !Number.isInteger(source.seats)
    || source.seats < 1
    || source.seats > intercityRideLimits.seats
  ) {
    return invalid('seats must be an integer from 1 to 7');
  }
  const pickup = optionalPickup(source);
  if (!pickup.ok) return pickup;

  return {
    ok: true,
    value: {
      originCity: origin.display,
      originCityKey: origin.key,
      destinationCity: destination.display,
      destinationCityKey: destination.key,
      travelDate: source.travelDate,
      seats: source.seats,
      ...pickup.value,
    },
  };
}

export function isUuid(value) {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
