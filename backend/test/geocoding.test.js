import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import { createGeocodingRouter } from '../src/routes/geocoding.js';
import { wordPrefixMatches } from '../src/geocoding-candidates.js';

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function appFor(fetchImpl, { timeoutMs = 50, auth = true, pool } = {}) {
  const app = express();
  const requireAuth = (req, res, next) =>
    !auth || req.headers.authorization === 'Bearer test'
      ? next()
      : res.status(401).json({ error: 'Missing authorization token' });
  app.use(
    '/api/geocoding',
    createGeocodingRouter({ fetchImpl, timeoutMs, requireAuth, pool }),
  );
  return app;
}

test('real Esil streets match from two letters and every word prefix', async () => {
  let upstreamCalls = 0;
  const app = appFor(async () => { upstreamCalls++; return jsonResponse([]); });
  for (const [query, street] of [
    ['Мы', 'Мырзашева'], ['Мыр', 'Мырзашева'],
    ['Иге', 'Тын Игерушилер'], ['Игер', 'Тын Игерушилер'],
    ['Тын', 'Тын Игерушилер'],
  ]) {
    const response = await request(app).get('/api/geocoding/search')
      .query({ query, settlement: 'Есиль' })
      .set('Authorization', 'Bearer test');
    assert.equal(response.status, 200);
    assert.ok(response.body.results.some((item) =>
      item.kind === 'street' && item.displayName.includes(street)), query);
  }
  assert.equal(upstreamCalls, 0);
});

test('street house prefix returns only real OSM addresses', async () => {
  const app = appFor(async () => jsonResponse([]));
  const response = await request(app).get('/api/geocoding/search')
    .query({ query: 'Игерушилер 66', settlement: 'Есиль' })
    .set('Authorization', 'Bearer test');
  assert.equal(response.status, 200);
  assert.deepEqual(response.body.results.map((item) => item.address.house_number).sort(),
    ['66', '66А']);
});

test('verified POI aliases outrank generic OSM street candidates', async () => {
  const aliases = ['вок', 'жд вокзал', 'боль', 'шко', 'акимат'];
  const pool = { query: async () => ({ rows: [{
    id: 'poi-1', name: 'Вокзал', category: 'transport',
    address: 'Есиль', latitude: 51.95, longitude: 66.4,
    aliases,
  }] }) };
  const app = appFor(async () => jsonResponse([]), { pool });
  for (const query of aliases) {
    const response = await request(app).get('/api/geocoding/search')
      .query({ query, settlement: 'Есиль' })
      .set('Authorization', 'Bearer test');
    assert.equal(response.status, 200);
    assert.equal(response.body.results[0].id, 'tulpar-poi-1');
  }
});

test('city-scoped autocomplete never calls public upstream and rejects disabled city', async () => {
  let upstreamCalls = 0;
  const queries = [];
  const pool = { async query(sql, values = []) {
    queries.push({ sql, values });
    if (sql.includes('FROM cities')) {
      return { rows: values[0] === 'rudny'
        ? [{ id: 5, slug: 'rudny', name_ru: 'Рудный' }] : [] };
    }
    if (sql.includes('FROM tulpar_places')) return { rows: [] };
    if (sql.includes('autocomplete_candidate_terms')) {
      return { rows: [{ kind: 'street', name: 'Абая', house_number: null,
        category: null, latitude: 52.96, longitude: 63.13,
        osm_type: 'way', osm_id: 42 }] };
    }
    throw new Error('Unexpected SQL');
  } };
  const app = appFor(async () => { upstreamCalls++; return jsonResponse([]); }, { pool });
  const found = await request(app).get('/api/geocoding/search')
    .query({ cityId: 'rudny', query: 'Аба', kind: 'address' })
    .set('Authorization', 'Bearer test');
  assert.equal(found.status, 200);
  assert.equal(found.body.results[0].cityId, 'rudny');
  assert.equal(found.body.results[0].lat, 52.96);
  assert.ok(queries.some(({ sql, values }) =>
    sql.includes('autocomplete_candidate_terms') && values[0] === 5));
  assert.equal(upstreamCalls, 0);
  const invalid = await request(app).get('/api/geocoding/search')
    .query({ cityId: 'disabled', query: 'Аба' })
    .set('Authorization', 'Bearer test');
  assert.equal(invalid.status, 400);
  assert.equal(upstreamCalls, 0);
});

const reverseBody = {
  place_id: 7,
  display_name: 'ул. Абая, 15, Есиль, Казахстан',
  address: {
    road: 'ул. Абая',
    house_number: '15',
    town: 'Есиль',
    state: 'Акмолинская область',
    country_code: 'kz',
  },
};

test('prefix matching is case-insensitive, NFC-safe and hyphen-aware', () => {
  assert.equal(wordPrefixMatches('Тын Игерушилер', '  иГе '), true);
  assert.equal(wordPrefixMatches('Ауэзов-Жолы', 'жол'), true);
  assert.equal(wordPrefixMatches('Әлім', 'Әл'), true);
  assert.equal(wordPrefixMatches('Йол', 'И\u0306о'), true);
});

test('reverse validates auth, normalizes response and fixes upstream host', async () => {
  let calledUrl;
  const app = appFor(async (url) => {
    calledUrl = url;
    return jsonResponse(reverseBody);
  });
  assert.equal((await request(app).get('/api/geocoding/reverse?lat=51&lng=66')).status, 401);
  const response = await request(app)
    .get('/api/geocoding/reverse?lat=51.95&lng=66.4&url=http://127.0.0.1')
    .set('Authorization', 'Bearer test');
  assert.equal(response.status, 200);
  assert.equal(response.body.settlement.name, 'Есиль');
  assert.equal(response.body.countryCode, 'kz');
  assert.equal(calledUrl.origin, 'https://nominatim.openstreetmap.org');
});

for (const query of ['lat=NaN&lng=66', 'lat=Infinity&lng=66', 'lat=91&lng=66', 'lat=51&lng=181']) {
  test(`invalid reverse coordinates ${query} do not call upstream`, async () => {
    let calls = 0;
    const app = appFor(async () => { calls++; return jsonResponse(reverseBody); });
    const response = await request(app)
      .get(`/api/geocoding/reverse?${query}`)
      .set('Authorization', 'Bearer test');
    assert.equal(response.status, 400);
    assert.equal(calls, 0);
  });
}

test('oversized search query is rejected without upstream call', async () => {
  let calls = 0;
  const app = appFor(async () => { calls++; return jsonResponse([]); });
  const response = await request(app)
    .get('/api/geocoding/search')
    .query({ query: 'x'.repeat(161) })
    .set('Authorization', 'Bearer test');
  assert.equal(response.status, 400);
  assert.equal(calls, 0);
});

test('search returns normalized Kazakhstan results', async () => {
  const app = appFor(async () => jsonResponse([{
    place_id: 9,
    lat: '51.95',
    lon: '66.4',
    display_name: 'Есиль, Акмолинская область, Казахстан',
    address: { town: 'Есиль', state: 'Акмолинская область', country_code: 'kz' },
  }]));
  const response = await request(app)
    .get('/api/geocoding/search?query=Есиль&kind=settlement')
    .set('Authorization', 'Bearer test');
  assert.equal(response.status, 200);
  assert.equal(response.body.results[0].name, 'Есиль');
});

test('upstream timeout returns stable JSON', async () => {
  const app = appFor((_url, { signal }) => new Promise((_resolve, reject) => {
    signal.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')));
  }), { timeoutMs: 5 });
  const response = await request(app)
    .get('/api/geocoding/reverse?lat=51&lng=66')
    .set('Authorization', 'Bearer test');
  assert.equal(response.status, 503);
  assert.deepEqual(response.body, { error: 'Geocoding service timed out' });
});

test('socket error and non-200 return stable JSON without upstream detail', async () => {
  const socketApp = appFor(async () => { throw new Error('private upstream detail'); });
  const socketResponse = await request(socketApp)
    .get('/api/geocoding/reverse?lat=51&lng=66')
    .set('Authorization', 'Bearer test');
  assert.equal(socketResponse.status, 502);
  assert.doesNotMatch(JSON.stringify(socketResponse.body), /private/);

  const non200App = appFor(async () => jsonResponse({ secret: 'detail' }, 429));
  const non200Response = await request(non200App)
    .get('/api/geocoding/reverse?lat=51&lng=66')
    .set('Authorization', 'Bearer test');
  assert.equal(non200Response.status, 502);
  assert.doesNotMatch(JSON.stringify(non200Response.body), /secret/);
});

test('HTML and malformed JSON are rejected without content leakage', async () => {
  const htmlApp = appFor(async () => new Response('<html>secret</html>', {
    status: 200,
    headers: { 'content-type': 'text/html' },
  }));
  const html = await request(htmlApp)
    .get('/api/geocoding/reverse?lat=51&lng=66')
    .set('Authorization', 'Bearer test');
  assert.equal(html.status, 502);
  assert.doesNotMatch(JSON.stringify(html.body), /html|secret/);

  const malformedApp = appFor(async () => new Response('{bad', {
    status: 200,
    headers: { 'content-type': 'application/json' },
  }));
  const malformed = await request(malformedApp)
    .get('/api/geocoding/reverse?lat=51&lng=66')
    .set('Authorization', 'Bearer test');
  assert.equal(malformed.status, 502);
});
