const allowedServiceTypes = new Set(['city', 'delivery', 'intercity']);
const invalidFloatingPointText = new Set(['NaN', 'Infinity', '-Infinity']);

export const orderValidationLimits = Object.freeze({
  address: 500,
  passengerPrice: 1_000_000,
  distanceMeters: 5_000_000,
  itemDescription: 1_000,
  personName: 120,
  phone: 32,
  entrance: 30,
  apartment: 30,
  floor: 20,
  intercom: 50,
  comment: 1_000,
});

export const cityOrderLifetimeMs = 2 * 60 * 60 * 1_000;

function invalid(error) {
  return { ok: false, error };
}

function requiredString(value, field, maxLength) {
  if (typeof value !== 'string') {
    return invalid(`${field} must be a string`);
  }

  const normalized = value.trim();
  if (normalized.length === 0) {
    return invalid(`${field} is required`);
  }
  if (normalized.length > maxLength) {
    return invalid(`${field} is too long`);
  }

  return { ok: true, value: normalized };
}

function optionalString(value, field, maxLength) {
  if (value === null || value === undefined) {
    return { ok: true, value: null };
  }
  if (typeof value !== 'string') {
    return invalid(`${field} must be a string`);
  }

  const normalized = value.trim();
  if (normalized.length > maxLength) {
    return invalid(`${field} is too long`);
  }

  return { ok: true, value: normalized || null };
}

function coordinatePair(lat, lng, prefix) {
  const latMissing = lat === null || lat === undefined;
  const lngMissing = lng === null || lng === undefined;

  if (latMissing !== lngMissing) {
    return invalid(`${prefix} coordinates must be provided together`);
  }
  if (latMissing) {
    return { ok: true, lat: null, lng: null };
  }
  if (
    typeof lat !== 'number' ||
    !Number.isFinite(lat) ||
    invalidFloatingPointText.has(String(lat)) ||
    lat < -90 ||
    lat > 90
  ) {
    return invalid(`${prefix} latitude is invalid`);
  }
  if (
    typeof lng !== 'number' ||
    !Number.isFinite(lng) ||
    invalidFloatingPointText.has(String(lng)) ||
    lng < -180 ||
    lng > 180
  ) {
    return invalid(`${prefix} longitude is invalid`);
  }

  return { ok: true, lat, lng };
}

function validateOptionalFields(source, definitions) {
  const values = {};
  for (const [field, maxLength] of Object.entries(definitions)) {
    const result = optionalString(source[field], field, maxLength);
    if (!result.ok) return result;
    values[field] = result.value;
  }
  return { ok: true, values };
}

export function validateOrderCreatePayload(body, { now = new Date() } = {}) {
  const source = body && typeof body === 'object' && !Array.isArray(body) ? body : {};
  const serviceType = source.serviceType ?? 'city';

  if (!allowedServiceTypes.has(serviceType)) {
    return invalid('Invalid service type');
  }
  if (Object.prototype.hasOwnProperty.call(source, 'agreedPrice')) {
    return invalid('agreedPrice cannot be set when creating an order');
  }

  const pickupAddress = requiredString(
    source.pickupAddress,
    'pickupAddress',
    orderValidationLimits.address,
  );
  if (!pickupAddress.ok) return pickupAddress;

  const destinationAddress = requiredString(
    source.destinationAddress,
    'destinationAddress',
    orderValidationLimits.address,
  );
  if (!destinationAddress.ok) return destinationAddress;

  if (
    !Number.isInteger(source.passengerPrice) ||
    source.passengerPrice <= 0 ||
    source.passengerPrice > orderValidationLimits.passengerPrice
  ) {
    return invalid('Invalid passenger price');
  }

  const pickup = coordinatePair(source.pickupLat, source.pickupLng, 'pickup');
  if (!pickup.ok) return pickup;
  const destination = coordinatePair(
    source.destinationLat,
    source.destinationLng,
    'destination',
  );
  if (!destination.ok) return destination;

  let stops = null;
  if (source.stops !== undefined) {
    if (serviceType !== 'city' || !Array.isArray(source.stops) || source.stops.length < 1 || source.stops.length > 4) {
      return invalid('Invalid order stops');
    }
    stops = [];
    for (let index = 0; index < source.stops.length; index++) {
      const raw = source.stops[index];
      if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return invalid('Invalid order stop');
      const address = requiredString(raw.address, 'stop address', orderValidationLimits.address);
      if (!address.ok) return address;
      const point = coordinatePair(raw.latitude, raw.longitude, 'stop');
      if (!point.ok || point.lat === null) return invalid('Invalid order stop coordinates');
      stops.push({ sequence: index, type: 'destination', address: address.value, latitude: point.lat, longitude: point.lng });
    }
    const finalStop = stops.at(-1);
    if (finalStop.address !== destinationAddress.value || finalStop.latitude !== destination.lat || finalStop.longitude !== destination.lng) {
      return invalid('Final stop must match destination');
    }
  }

  let distanceMeters = source.distanceMeters;
  if (distanceMeters === null || distanceMeters === undefined) {
    distanceMeters = null;
  } else if (
    !Number.isInteger(distanceMeters) ||
    distanceMeters < 0 ||
    distanceMeters > orderValidationLimits.distanceMeters
  ) {
    return invalid('Invalid distance');
  }

  const value = {
    serviceType,
    passengerPrice: source.passengerPrice,
    pickupAddress: pickupAddress.value,
    destinationAddress: destinationAddress.value,
    pickupLat: pickup.lat,
    pickupLng: pickup.lng,
    destinationLat: destination.lat,
    destinationLng: destination.lng,
    distanceMeters,
    stops,
  };

  if (serviceType === 'delivery') {
    const itemDescription = requiredString(
      source.itemDescription,
      'itemDescription',
      orderValidationLimits.itemDescription,
    );
    if (!itemDescription.ok) return itemDescription;

    const recipientPhone = requiredString(
      source.recipientPhone,
      'recipientPhone',
      orderValidationLimits.phone,
    );
    if (!recipientPhone.ok) return recipientPhone;

    const pickupHandoffType = source.pickupHandoffType ?? 'outside';
    const destinationHandoffType = source.destinationHandoffType ?? 'outside';
    if (
      !['door', 'outside'].includes(pickupHandoffType) ||
      !['door', 'outside'].includes(destinationHandoffType)
    ) {
      return invalid('Invalid delivery handoff type');
    }

    const optional = validateOptionalFields(source, {
      senderName: orderValidationLimits.personName,
      senderPhone: orderValidationLimits.phone,
      recipientName: orderValidationLimits.personName,
      pickupEntrance: orderValidationLimits.entrance,
      pickupApartment: orderValidationLimits.apartment,
      pickupFloor: orderValidationLimits.floor,
      pickupIntercom: orderValidationLimits.intercom,
      pickupComment: orderValidationLimits.comment,
      destinationEntrance: orderValidationLimits.entrance,
      destinationApartment: orderValidationLimits.apartment,
      destinationFloor: orderValidationLimits.floor,
      destinationIntercom: orderValidationLimits.intercom,
      destinationComment: orderValidationLimits.comment,
    });
    if (!optional.ok) return optional;

    Object.assign(value, optional.values, {
      itemDescription: itemDescription.value,
      recipientPhone: recipientPhone.value,
      pickupHandoffType,
      destinationHandoffType,
    });
  }

  if (serviceType === 'intercity') {
    if (typeof source.departureAt !== 'string') {
      return invalid('Valid future departure time is required');
    }
    const departureAt = new Date(source.departureAt);
    if (Number.isNaN(departureAt.getTime()) || departureAt <= now) {
      return invalid('Valid future departure time is required');
    }
    if (
      !Number.isInteger(source.passengerCount ?? 1) ||
      (source.passengerCount ?? 1) < 1 ||
      (source.passengerCount ?? 1) > 20
    ) {
      return invalid('Passenger count must be from 1 to 20');
    }
    if (typeof (source.hasLuggage ?? false) !== 'boolean') {
      return invalid('hasLuggage must be boolean');
    }

    const comment = optionalString(
      source.intercityComment ?? source.comment,
      'intercityComment',
      orderValidationLimits.comment,
    );
    if (!comment.ok) return comment;

    Object.assign(value, {
      departureAt,
      passengerCount: source.passengerCount ?? 1,
      hasLuggage: source.hasLuggage ?? false,
      intercityComment: comment.value,
    });
  }

  return { ok: true, value };
}

export function isSearchingOrderExpired(order, { now = new Date() } = {}) {
  if (order?.status !== 'searching') return false;

  if (order.serviceType === 'city' || order.serviceType === 'delivery') {
    const createdAt = new Date(order.createdAt);
    return (
      !Number.isNaN(createdAt.getTime()) &&
      createdAt.getTime() <= now.getTime() - cityOrderLifetimeMs
    );
  }

  if (order.serviceType === 'intercity') {
    const departureAt = new Date(order.departureAt);
    return !Number.isNaN(departureAt.getTime()) && departureAt <= now;
  }

  return false;
}

export async function expireStaleSearchingOrders(pool, { now = new Date() } = {}) {
  const cityCutoff = new Date(now.getTime() - cityOrderLifetimeMs);
  return pool.query(
    `
    UPDATE orders o
    SET
      status = 'expired',
      updated_at = $2
    WHERE
      o.status = 'searching'
      AND (
        (
          o.service_type IN ('city', 'delivery')
          AND o.created_at <= $1
        )
        OR (
          o.service_type = 'intercity'
          AND EXISTS (
            SELECT 1
            FROM intercity_details ic
            WHERE
              ic.order_id = o.id
              AND ic.departure_at <= $2
          )
        )
      )
    RETURNING o.id, o.passenger_id, o.service_type
    `,
    [cityCutoff, now],
  );
}
