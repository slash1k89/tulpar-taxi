import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import { createGeocodingRouter } from '../src/routes/geocoding.js';

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function appFor(fetchImpl, { timeoutMs = 50, auth = true } = {}) {
  const app = express();
  const requireAuth = (req, res, next) =>
    !auth || req.headers.authorization === 'Bearer test'
      ? next()
      : res.status(401).json({ error: 'Missing authorization token' });
  app.use(
    '/api/geocoding',
    createGeocodingRouter({ fetchImpl, timeoutMs, requireAuth }),
  );
  return app;
}

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
