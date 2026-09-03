import express from 'express';

const NOMINATIM_ORIGIN = 'https://nominatim.openstreetmap.org';
const DEFAULT_TIMEOUT_MS = 5_000;
const MAX_QUERY_LENGTH = 160;

function coordinate(value, min, max) {
  if (typeof value !== 'string' || value.trim() === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= min && parsed <= max
    ? parsed
    : null;
}

function cleanOptional(value, maxLength) {
  if (value === undefined) return '';
  if (typeof value !== 'string') return null;
  const clean = value.trim();
  return clean.length <= maxLength ? clean : null;
}

function settlementName(address, fallback = '') {
  return String(
    address?.city ?? address?.town ?? address?.village ??
      address?.municipality ?? address?.county ?? fallback,
  ).trim();
}

function stableError(res, status, error) {
  return res.status(status).json({ error });
}

async function fetchJson({ fetchImpl, url, timeoutMs }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(url, {
      headers: {
        Accept: 'application/json',
        'User-Agent': 'TulparTaxiBackend/1.0 (kz.tulpar.app@gmail.com)',
      },
      signal: controller.signal,
    });
    if (!response.ok) return { error: 'unavailable' };
    const contentType = response.headers.get('content-type') ?? '';
    if (!contentType.toLowerCase().includes('application/json')) {
      return { error: 'invalid' };
    }
    try {
      return { body: await response.json() };
    } catch {
      return { error: 'invalid' };
    }
  } catch (error) {
    if (error?.name === 'AbortError' || controller.signal.aborted) {
      return { error: 'timeout' };
    }
    return { error: 'unavailable' };
  } finally {
    clearTimeout(timeout);
  }
}

function sendUpstreamError(res, error) {
  if (error === 'timeout') {
    return stableError(res, 503, 'Geocoding service timed out');
  }
  if (error === 'invalid') {
    return stableError(res, 502, 'Geocoding service returned an invalid response');
  }
  return stableError(res, 502, 'Geocoding service is unavailable');
}

export function createGeocodingRouter({
  requireAuth,
  fetchImpl = globalThis.fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
} = {}) {
  const router = express.Router();

  router.get('/search', requireAuth, async (req, res) => {
    const query = cleanOptional(req.query.query, MAX_QUERY_LENGTH);
    const kind = req.query.kind === 'settlement' ? 'settlement' : 'address';
    const settlement = cleanOptional(req.query.settlement, 120);
    if (query === null || query.length < 2 || settlement === null) {
      return stableError(res, 400, 'Invalid geocoding query');
    }

    const hasLat = req.query.lat !== undefined;
    const hasLng = req.query.lng !== undefined;
    const lat = !hasLat
      ? null
      : coordinate(req.query.lat, -90, 90);
    const lng = !hasLng
      ? null
      : coordinate(req.query.lng, -180, 180);
    if (hasLat !== hasLng || (hasLat && (lat === null || lng === null))) {
      return stableError(res, 400, 'Invalid geocoding coordinates');
    }

    const url = new URL('/search', NOMINATIM_ORIGIN);
    url.searchParams.set('q', settlement ? `${query}, ${settlement}` : query);
    url.searchParams.set('format', 'json');
    url.searchParams.set('addressdetails', '1');
    url.searchParams.set('limit', kind === 'settlement' ? '10' : '8');
    url.searchParams.set('accept-language', 'ru');
    url.searchParams.set('countrycodes', 'kz');
    if (kind === 'settlement') url.searchParams.set('featuretype', 'settlement');
    if (lat !== null && lng !== null) {
      const span = 0.7;
      url.searchParams.set(
        'viewbox',
        `${lng - span},${lat + span},${lng + span},${lat - span}`,
      );
      url.searchParams.set('bounded', '1');
    }

    const upstream = await fetchJson({ fetchImpl, url, timeoutMs });
    if (upstream.error) return sendUpstreamError(res, upstream.error);
    if (!Array.isArray(upstream.body)) {
      return sendUpstreamError(res, 'invalid');
    }

    const results = upstream.body.flatMap((raw) => {
      if (!raw || typeof raw !== 'object') return [];
      const itemLat = Number(raw.lat);
      const itemLng = Number(raw.lon);
      const address = raw.address;
      if (!Number.isFinite(itemLat) || !Number.isFinite(itemLng) ||
          !address || typeof address !== 'object' ||
          String(address.country_code).toLowerCase() !== 'kz') return [];
      const name = settlementName(address, raw.name);
      if (kind === 'settlement' && !name) return [];
      return [{
        id: String(raw.place_id ?? `${itemLat},${itemLng}`),
        name,
        region: String(address.state ?? address.region ?? address.county ?? ''),
        displayName: String(raw.display_name ?? name),
        lat: itemLat,
        lng: itemLng,
        address,
      }];
    });
    return res.json({ results });
  });

  router.get('/reverse', requireAuth, async (req, res) => {
    const lat = coordinate(req.query.lat, -90, 90);
    const lng = coordinate(req.query.lng, -180, 180);
    if (lat === null || lng === null) {
      return stableError(res, 400, 'Invalid geocoding coordinates');
    }

    const url = new URL('/reverse', NOMINATIM_ORIGIN);
    url.searchParams.set('lat', String(lat));
    url.searchParams.set('lon', String(lng));
    url.searchParams.set('format', 'json');
    url.searchParams.set('addressdetails', '1');
    url.searchParams.set('accept-language', 'ru');

    const upstream = await fetchJson({ fetchImpl, url, timeoutMs });
    if (upstream.error) return sendUpstreamError(res, upstream.error);
    const raw = upstream.body;
    if (!raw || typeof raw !== 'object' || Array.isArray(raw) ||
        !raw.address || typeof raw.address !== 'object') {
      return sendUpstreamError(res, 'invalid');
    }
    const name = settlementName(raw.address);
    return res.json({
      address: String(raw.display_name ?? name),
      countryCode: String(raw.address.country_code ?? '').toLowerCase(),
      settlement: name ? {
        id: String(raw.place_id ?? `${lat},${lng}`),
        name,
        region: String(
          raw.address.state ?? raw.address.region ?? raw.address.county ?? '',
        ),
        lat,
        lng,
      } : null,
    });
  });

  return router;
}
