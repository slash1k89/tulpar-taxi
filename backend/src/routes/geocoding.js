import express from 'express';
import {
  localAddressCandidates,
  searchCityCandidates,
  wordPrefixMatches,
} from '../geocoding-candidates.js';

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
  pool,
  fetchImpl = globalThis.fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
} = {}) {
  const router = express.Router();

  router.get('/search', requireAuth, async (req, res) => {
    const query = cleanOptional(req.query.query, MAX_QUERY_LENGTH);
    const kind = req.query.kind === 'settlement' ? 'settlement' : 'address';
    const settlement = cleanOptional(req.query.settlement, 120);
    const cityId = cleanOptional(req.query.cityId, 40);
    if (query === null || query.length < 2 || settlement === null || cityId === null) {
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

    if (cityId !== null && cityId) {
      if (kind !== 'address' || !pool) return stableError(res, 400, 'Invalid city');
      const cityResult = await pool.query(
        `SELECT id, slug, name_ru FROM cities WHERE slug = $1 AND is_enabled = TRUE`,
        [cityId],
      );
      const city = cityResult.rows[0];
      if (!city) return stableError(res, 400, 'Invalid city');
      try {
        const local = await searchCityCandidates(pool, { city, query });
        const placesResult = await pool.query(
          `SELECT id, name, category, address, latitude, longitude, aliases
           FROM tulpar_places WHERE city_id = $1 AND active = TRUE`,
          [city.id],
        );
        const places = placesResult.rows.filter((row) =>
          [row.name, row.category, ...(row.aliases ?? [])]
            .some((value) => wordPrefixMatches(value, query)))
          .map((row) => ({
            id: `tulpar-${row.id}`, kind: 'poi', name: row.name,
            cityId: city.slug, cityName: city.name_ru, region: '',
            displayName: `${row.name}${row.address ? `, ${row.address}` : ''}`,
            lat: Number(row.latitude), lng: Number(row.longitude),
            address: { town: city.name_ru, country_code: 'kz' },
          }));
        const compatibility = city.slug === 'esil' && local.length === 0
          ? localAddressCandidates({ query, settlement: 'Есиль' }) : [];
        return res.json({ results: [...places, ...local, ...compatibility].slice(0, 12) });
      } catch (error) {
        console.error('[GeocodingLocal]', error);
        return stableError(res, 503, 'Local geocoding is unavailable');
      }
    }

    if (kind === 'address') {
      const local = localAddressCandidates({ query, settlement, lat, lng });
      let places = [];
      if (pool) {
        try {
          const result = await pool.query(
            `SELECT id, name, category, address, latitude, longitude, aliases
             FROM tulpar_places WHERE active = TRUE`,
          );
          places = result.rows.filter((row) =>
            [row.name, row.category, ...(row.aliases ?? [])]
              .some((value) => wordPrefixMatches(value, query)))
            .map((row) => ({
              id: `tulpar-${row.id}`,
              kind: 'poi',
              name: row.name,
              region: '',
              displayName: `${row.name}${row.address ? `, ${row.address}` : ''}`,
              lat: Number(row.latitude),
              lng: Number(row.longitude),
              address: { town: settlement ?? 'Есиль', country_code: 'kz' },
            }));
        } catch (error) {
          console.error('[GeocodingPlaces]', error);
        }
      }
      if (places.length || local.length) {
        return res.json({ results: [...places, ...local].slice(0, 12) });
      }
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
        kind: raw.class === 'highway' && !address.house_number
          ? 'street' : address.house_number ? 'address' : 'poi',
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
