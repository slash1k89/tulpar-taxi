// Idempotent LOCAL PostgreSQL import of extract_multicity_osm.py JSONL output.
// Usage: node tools/import_multicity_candidates.js path/to/candidates.jsonl postgresql://...
// Refuses non-loopback DB hosts. Never use against production.
import { createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import pg from 'pg';
import { normalizeSearchText } from '../src/geocoding-candidates.js';

function terms(value) {
  return [...new Set(normalizeSearchText(value).split(/[\s\-]+/u).filter(Boolean))];
}

function validRow(row) {
  return typeof row.citySlug === 'string' &&
    ['street', 'address', 'poi'].includes(row.kind) &&
    typeof row.name === 'string' && row.name.trim() !== '' &&
    ['node', 'way', 'relation'].includes(row.osmType) &&
    Number.isSafeInteger(row.osmId) &&
    Number.isFinite(row.lat) && row.lat >= -90 && row.lat <= 90 &&
    Number.isFinite(row.lng) && row.lng >= -180 && row.lng <= 180;
}

export async function importCandidate(client, row, cityId) {
    if (!validRow(row)) throw new Error('Invalid OSM candidate');
    const saved = await client.query(
      `INSERT INTO autocomplete_candidates
         (city_id, kind, name, name_search, house_number, house_search, category, aliases,
          latitude, longitude, osm_type, osm_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       ON CONFLICT (city_id, kind, osm_type, osm_id) DO UPDATE SET
         name = EXCLUDED.name, name_search = EXCLUDED.name_search,
         house_number = EXCLUDED.house_number,
         house_search = EXCLUDED.house_search, category = EXCLUDED.category,
         aliases = EXCLUDED.aliases, latitude = EXCLUDED.latitude,
         longitude = EXCLUDED.longitude, updated_at = now()
       RETURNING id`,
      [cityId, row.kind, row.name, normalizeSearchText(row.name), row.house,
        row.house ? normalizeSearchText(row.house) : null,
        row.category, row.aliases ?? [], row.lat, row.lng, row.osmType, row.osmId],
    );
    const candidateId = saved.rows[0].id;
    await client.query('DELETE FROM autocomplete_candidate_terms WHERE candidate_id = $1', [candidateId]);
    const entries = [
      ...terms(row.name).map((term) => [term, 'name']),
      ...(row.aliases ?? []).flatMap((alias) => terms(alias).map((term) => [term, 'alias'])),
    ];
    for (const [term, origin] of entries) {
      await client.query(
        `INSERT INTO autocomplete_candidate_terms (candidate_id, city_id, term, source)
         VALUES ($1,$2,$3,$4) ON CONFLICT DO NOTHING`,
        [candidateId, cityId, term, origin],
      );
    }
}

export async function importCandidates(client, lines, cityIds) {
  let imported = 0;
  await client.query('BEGIN');
  try {
    for await (const line of lines) {
      if (!line.trim()) continue;
      const row = JSON.parse(line);
      const cityId = cityIds.get(row.citySlug);
      if (!cityId) throw new Error(`Unknown or disabled city slug: ${row.citySlug}`);
      await importCandidate(client, row, cityId);
      imported += 1;
    }
    await client.query('COMMIT');
    return imported;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
}

async function main() {
  const [source, databaseUrlArgument, modeArgument] = process.argv.slice(2);
  const mode = databaseUrlArgument === '--allow-production'
    ? databaseUrlArgument
    : modeArgument;
  const databaseUrl = databaseUrlArgument === '--allow-production'
    ? process.env.DATABASE_URL
    : databaseUrlArgument;
  const productionConfirmed = mode === '--allow-production' &&
    process.env.TULPAR_MULTICITY_IMPORT_CONFIRM === '13-cities-20260923';
  if (!source || (!databaseUrl && !productionConfirmed)) {
    throw new Error('Provide JSONL path and local PostgreSQL URL');
  }
  const parsedUrl = databaseUrl ? new URL(databaseUrl) : null;
  const loopback = parsedUrl !== null &&
    ['localhost', '127.0.0.1', '::1'].includes(parsedUrl.hostname);
  if (!loopback && !productionConfirmed) {
    throw new Error('Importer only accepts a loopback PostgreSQL host');
  }
  const pool = new pg.Pool(databaseUrl
    ? { connectionString: databaseUrl, max: 1 }
    : {
        host: process.env.DB_HOST,
        port: Number(process.env.DB_PORT || 5432),
        database: process.env.POSTGRES_DB,
        user: process.env.POSTGRES_USER,
        password: process.env.POSTGRES_PASSWORD,
        max: 1,
      });
  const client = await pool.connect();
  try {
    const cities = await client.query('SELECT id, slug FROM cities WHERE is_enabled = TRUE');
    const cityIds = new Map(cities.rows.map((row) => [row.slug, row.id]));
    const lines = createInterface({ input: createReadStream(source, { encoding: 'utf8' }), crlfDelay: Infinity });
    const imported = await importCandidates(client, lines, cityIds);
    console.log(JSON.stringify({
      imported,
      database: loopback ? 'loopback' : 'explicitly-confirmed-production',
    }));
  } finally {
    client.release();
    await pool.end();
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
