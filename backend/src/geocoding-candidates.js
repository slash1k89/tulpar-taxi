import { readFileSync } from 'node:fs';

// Verified OSM objects extracted from the existing self-hosted Kazakhstan PBF.
// Source: OpenStreetMap contributors (ODbL). No approximate houses are added.
const esilCandidates = readFileSync(
  new URL('./data/esil-osm-20260914.jsonl', import.meta.url),
  'utf8',
).trim().split('\n').map((line) => JSON.parse(line));

export function normalizeSearchText(value) {
  return String(value ?? '').normalize('NFC').trim().toLocaleLowerCase('ru');
}

function words(value) {
  return normalizeSearchText(value).split(/[\s\-]+/u).filter(Boolean);
}

export function wordPrefixMatches(value, query) {
  const wanted = words(query);
  if (wanted.length === 0) return false;
  const available = words(value);
  return wanted.every((part) => available.some((word) => word.startsWith(part)));
}

function esilSelected(settlement, lat, lng) {
  if (settlement) return normalizeSearchText(settlement) === 'есиль';
  return Number.isFinite(lat) && Number.isFinite(lng) &&
    lat >= 51.90 && lat <= 52.02 && lng >= 66.31 && lng <= 66.50;
}

function asResult(item) {
  const isAddress = item.kind === 'address';
  const displayName = `${item.name}${isAddress ? `, ${item.house}` : ''}, Есиль, Казахстан`;
  return {
    id: `osm-${item.osm_type}-${item.osm_id}`,
    kind: item.kind,
    name: item.name,
    region: 'Акмолинская область',
    displayName,
    lat: item.lat,
    lng: item.lng,
    address: {
      road: item.name,
      ...(isAddress ? { house_number: item.house } : {}),
      town: 'Есиль',
      country_code: 'kz',
    },
  };
}

export function localAddressCandidates({ query, settlement, lat, lng }) {
  if (!esilSelected(settlement, lat, lng)) return [];
  const clean = normalizeSearchText(query);
  if ([...clean].length < 2) return [];
  const houseMatch = /^(.+?)[,\s]+(\d[\p{L}\d/-]*)$/u.exec(clean);
  const matched = esilCandidates.filter((item) => {
    const names = [item.name, ...(item.aliases ?? [])];
    if (houseMatch) {
      return item.kind === 'address' &&
        names.some((name) => wordPrefixMatches(name, houseMatch[1])) &&
        normalizeSearchText(item.house).startsWith(houseMatch[2]);
    }
    return item.kind === 'street' &&
      names.some((name) => wordPrefixMatches(name, clean));
  });
  const seen = new Set();
  return matched.filter((item) => {
    const key = `${normalizeSearchText(item.name)}:${normalizeSearchText(item.house)}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).slice(0, 12).map(asResult);
}

function searchParts(value) {
  return normalizeSearchText(value).split(/[\s\-]+/u).filter(Boolean);
}

function prefixPattern(value) {
  return `${value.replace(/[\\%_]/g, '\\$&')}%`;
}

// Uses the city+term prefix index. Unlike the Esil JSONL compatibility path,
// this remains bounded when the other twelve cities are imported.
export async function searchCityCandidates(pool, { city, query, limit = 12 }) {
  const clean = normalizeSearchText(query);
  if ([...clean].length < 2) return [];
  const houseMatch = /^(.+?)[,\s]+(\d[\p{L}\d/-]*)$/u.exec(clean);
  const namePart = houseMatch ? houseMatch[1] : clean;
  const parts = searchParts(namePart);
  if (!parts.length) return [];
  const values = [city.id];
  const union = parts.map((part, index) => {
    values.push(prefixPattern(part));
    return `SELECT candidate_id, ${index} AS part, source
            FROM autocomplete_candidate_terms
            WHERE city_id = $1 AND term LIKE $${values.length}`;
  }).join(' UNION ALL ');
  let houseClause = "c.kind IN ('street', 'poi')";
  if (houseMatch) {
    values.push(prefixPattern(houseMatch[2]));
    houseClause = `c.kind = 'address' AND c.house_search LIKE $${values.length}`;
  }
  values.push(clean, prefixPattern(namePart), Math.max(1, Math.min(15, limit)));
  const fullQueryParam = values.length - 2;
  const prefixParam = values.length - 1;
  const limitParam = values.length;
  const result = await pool.query(
    `WITH term_hits AS (${union}), matches AS (
       SELECT candidate_id, bool_or(source = 'name') AS has_name
       FROM term_hits GROUP BY candidate_id
       HAVING count(DISTINCT part) = ${parts.length}
     )
     SELECT c.id, c.kind, c.name, c.house_number, c.category,
            c.latitude, c.longitude, c.osm_type, c.osm_id,
            m.has_name, c.name_search, c.aliases
     FROM matches m JOIN autocomplete_candidates c ON c.id = m.candidate_id
     WHERE c.city_id = $1 AND ${houseClause}
     ORDER BY CASE
       WHEN c.name_search = $${fullQueryParam} THEN 0
       WHEN c.name_search LIKE $${prefixParam} THEN 1
       WHEN m.has_name THEN 2 ELSE 3 END,
       CASE c.kind WHEN 'street' THEN 0 WHEN 'poi' THEN 1 ELSE 2 END,
       c.name, c.house_number
     LIMIT $${limitParam}`,
    values,
  );
  return result.rows.map((row) => ({
    id: `osm-${row.osm_type}-${row.osm_id}`,
    kind: row.kind,
    name: row.name,
    category: row.category,
    cityId: city.slug,
    cityName: city.name_ru,
    houseNumber: row.house_number,
    region: '',
    displayName: `${row.name}${row.house_number ? `, ${row.house_number}` : ''}, ${city.name_ru}, Казахстан`,
    lat: Number(row.latitude),
    lng: Number(row.longitude),
    address: {
      road: row.name,
      ...(row.house_number ? { house_number: row.house_number } : {}),
      town: city.name_ru,
      country_code: 'kz',
    },
  }));
}
