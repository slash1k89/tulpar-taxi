import express from 'express';

const DEFAULT_TIMEOUT_MS = 5_000;

export function resolveOsrmBaseUrl(env = process.env) {
  const rawValue = env.OSRM_BASE_URL;
  if (typeof rawValue !== 'string' || rawValue.trim() === '') {
    throw new Error('OSRM_BASE_URL is required');
  }

  const normalized = rawValue.trim().replace(/\/+$/, '');
  let parsed;
  try {
    parsed = new URL(normalized);
  } catch {
    throw new Error('OSRM_BASE_URL must be a valid HTTP(S) URL');
  }

  if (
    (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') ||
    parsed.username ||
    parsed.password ||
    parsed.search ||
    parsed.hash
  ) {
    throw new Error('OSRM_BASE_URL must be a valid HTTP(S) URL');
  }

  return normalized;
}

function coordinate(value, min, max) {
  if (typeof value !== 'string' || value.trim() === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= min && parsed <= max
    ? parsed
    : null;
}

function intermediateWaypoints(value) {
  if (value === undefined || value === '') return [];
  if (typeof value !== 'string') return null;
  const rawPoints = value.split(';');
  if (rawPoints.length > 3) return null;
  const points = [];
  for (const raw of rawPoints) {
    const parts = raw.split(',');
    if (parts.length !== 2) return null;
    const lng = coordinate(parts[0], -180, 180);
    const lat = coordinate(parts[1], -90, 90);
    if (lat === null || lng === null) return null;
    points.push({ lat, lng });
  }
  return points;
}

function upstreamError(res, status, message) {
  return res.status(status).json({ error: message });
}

function nonNegativeNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
}

function maneuverLocation(value) {
  if (!Array.isArray(value) || value.length < 2) return null;
  const lng = Number(value[0]);
  const lat = Number(value[1]);
  if (
    !Number.isFinite(lat) ||
    !Number.isFinite(lng) ||
    lat < -90 ||
    lat > 90 ||
    lng < -180 ||
    lng > 180
  ) {
    return null;
  }
  return [lng, lat];
}

function normalizeStep(step) {
  if (!step || typeof step !== 'object') return null;
  const location = maneuverLocation(step.maneuver?.location);
  if (location === null) return null;

  const rawExit = Number(step.maneuver?.exit);
  const exit = Number.isSafeInteger(rawExit) && rawExit > 0 ? rawExit : null;

  return {
    name: typeof step.name === 'string' ? step.name : '',
    distanceMeters: nonNegativeNumber(step.distance),
    durationSeconds: nonNegativeNumber(step.duration),
    maneuver: {
      type: typeof step.maneuver?.type === 'string' ? step.maneuver.type : 'turn',
      modifier: typeof step.maneuver?.modifier === 'string'
        ? step.maneuver.modifier
        : 'straight',
      location,
      ...(exit === null ? {} : { exit }),
    },
  };
}

export function createRoutingRouter({
  requireAuth,
  fetchImpl = globalThis.fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  osrmBaseUrl = resolveOsrmBaseUrl(),
} = {}) {
  const router = express.Router();
  const normalizedOsrmBaseUrl = resolveOsrmBaseUrl({
    OSRM_BASE_URL: osrmBaseUrl,
  });

  router.get('/route', requireAuth, async (req, res) => {
    const startLat = coordinate(req.query.startLat, -90, 90);
    const startLng = coordinate(req.query.startLng, -180, 180);
    const destLat = coordinate(req.query.destLat, -90, 90);
    const destLng = coordinate(req.query.destLng, -180, 180);
    const waypoints = intermediateWaypoints(req.query.waypoints);

    if (waypoints === null || [startLat, startLng, destLat, destLng].some((value) => value === null)) {
      return res.status(400).json({ error: 'Invalid route coordinates' });
    }

    const coordinates = [
      `${startLng},${startLat}`,
      ...waypoints.map((point) => `${point.lng},${point.lat}`),
      `${destLng},${destLat}`,
    ].join(';');
    const path = `/route/v1/driving/${coordinates}`;
    const url = new URL(`${normalizedOsrmBaseUrl}${path}`);
    url.searchParams.set('steps', 'true');
    url.searchParams.set('geometries', 'geojson');
    url.searchParams.set('overview', 'full');

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const upstream = await fetchImpl(url, {
        headers: { Accept: 'application/json' },
        signal: controller.signal,
      });

      if (!upstream.ok) {
        return upstreamError(
          res,
          502,
          upstream.status === 429
            ? 'Routing service is temporarily busy'
            : 'Routing service is unavailable',
        );
      }

      const contentType = upstream.headers.get('content-type') ?? '';
      if (!contentType.toLowerCase().includes('application/json')) {
        return upstreamError(res, 502, 'Routing service returned an invalid response');
      }

      let body;
      try {
        body = await upstream.json();
      } catch {
        return upstreamError(res, 502, 'Routing service returned an invalid response');
      }

      const route = Array.isArray(body?.routes) ? body.routes[0] : null;
      const coordinates = route?.geometry?.coordinates;
      if (!route || !Array.isArray(coordinates) || coordinates.length < 2) {
        return upstreamError(res, 502, 'Routing service returned no valid route');
      }

      const geometry = [];
      for (const point of coordinates) {
        if (!Array.isArray(point) || point.length < 2) {
          return upstreamError(res, 502, 'Routing service returned invalid geometry');
        }
        const lng = Number(point[0]);
        const lat = Number(point[1]);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
          return upstreamError(res, 502, 'Routing service returned invalid geometry');
        }
        geometry.push({ lat, lng });
      }

      const rawSteps = Array.isArray(route.legs)
        ? route.legs.flatMap((leg) => Array.isArray(leg?.steps) ? leg.steps : [])
        : [];
      const steps = rawSteps.map(normalizeStep).filter(Boolean);

      return res.json({
        geometry,
        steps,
        distanceMeters: Number(route.distance) || 0,
        durationSeconds: Number(route.duration) || 0,
      });
    } catch (error) {
      if (error?.name === 'AbortError' || controller.signal.aborted) {
        return upstreamError(res, 503, 'Routing service timed out');
      }
      return upstreamError(res, 502, 'Routing service is unavailable');
    } finally {
      clearTimeout(timeout);
    }
  });

  return router;
}
