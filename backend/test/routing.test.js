import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import {
  createRoutingRouter,
  resolveOsrmBaseUrl,
} from '../src/routes/routing.js';

const validQuery = {
  startLat: '51.9555',
  startLng: '66.4042',
  destLat: '51.96',
  destLng: '66.41',
};

const osrmBody = {
  routes: [{
    geometry: { coordinates: [[66.4042, 51.9555], [66.41, 51.96]] },
    legs: [{
      steps: [{
        name: 'Абая',
        distance: 345.6,
        duration: 42.5,
        maneuver: {
          type: 'roundabout',
          modifier: 'right',
          location: [66.41, 51.96],
          exit: 2,
        },
      }],
    }],
    distance: 1234.5,
    duration: 180.2,
  }],
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function createApp(fetchImpl, {
  timeoutMs = 50,
  strictAuth = false,
  osrmBaseUrl = 'http://osrm.test:5000',
} = {}) {
  const app = express();
  const requireAuth = strictAuth
    ? (req, res, next) => req.headers.authorization === 'Bearer test'
      ? next()
      : res.status(401).json({ error: 'Missing authorization token' })
    : (_req, _res, next) => next();
  app.use('/api/routing', createRoutingRouter({
    requireAuth,
    fetchImpl,
    timeoutMs,
    osrmBaseUrl,
  }));
  return app;
}

test('OSRM base URL is read from OSRM_BASE_URL', () => {
  assert.equal(
    resolveOsrmBaseUrl({ OSRM_BASE_URL: 'http://tulpar-osrm:5000' }),
    'http://tulpar-osrm:5000',
  );
  assert.throws(
    () => resolveOsrmBaseUrl({}),
    /OSRM_BASE_URL is required/,
  );
});

test('valid coordinates return stable Tulpar route response and lng,lat upstream order', async () => {
  let calledUrl;
  const app = createApp(async (url) => {
    calledUrl = url;
    return jsonResponse(osrmBody);
  });
  const response = await request(app).get('/api/routing/route').query(validQuery);
  assert.equal(response.status, 200);
  assert.deepEqual(response.body.geometry[0], { lat: 51.9555, lng: 66.4042 });
  assert.equal(response.body.steps[0].maneuver.modifier, 'right');
  assert.equal(response.body.steps[0].maneuver.exit, 2);
  assert.equal(response.body.steps[0].distanceMeters, 345.6);
  assert.equal(response.body.steps[0].durationSeconds, 42.5);
  assert.equal(response.body.distanceMeters, 1234.5);
  assert.equal(response.body.durationSeconds, 180.2);
  assert.equal(calledUrl.origin, 'http://osrm.test:5000');
  assert.match(calledUrl.pathname, /66\.4042,51\.9555;66\.41,51\.96$/);
  assert.equal(calledUrl.searchParams.get('steps'), 'true');
  assert.equal(calledUrl.searchParams.get('geometries'), 'geojson');
  assert.equal(calledUrl.searchParams.get('overview'), 'full');
});

test('intermediate waypoints are sent to OSRM in the supplied order', async () => {
  let calledUrl;
  const app = createApp(async (url) => {
    calledUrl = url;
    return jsonResponse(osrmBody);
  });
  const response = await request(app).get('/api/routing/route').query({
    ...validQuery,
    waypoints: '66.405,51.956;66.407,51.958',
  });
  assert.equal(response.status, 200);
  assert.match(calledUrl.pathname, /66\.4042,51\.9555;66\.405,51\.956;66\.407,51\.958;66\.41,51\.96$/);
});

test('more than three intermediate waypoints are rejected', async () => {
  const app = createApp(async () => jsonResponse(osrmBody));
  const response = await request(app).get('/api/routing/route').query({
    ...validQuery,
    waypoints: '1,1;2,2;3,3;4,4',
  });
  assert.equal(response.status, 400);
});

test('trailing slashes are removed before building the OSRM route URL', async () => {
  let calledUrl;
  const app = createApp(async (url) => {
    calledUrl = url;
    return jsonResponse(osrmBody);
  }, { osrmBaseUrl: 'http://tulpar-osrm:5000///' });

  const response = await request(app).get('/api/routing/route').query(validQuery);

  assert.equal(response.status, 200);
  assert.equal(calledUrl.origin, 'http://tulpar-osrm:5000');
  assert.equal(
    calledUrl.pathname,
    '/route/v1/driving/66.4042,51.9555;66.41,51.96',
  );
});

test('missing maneuver exit is omitted and invalid step metrics are safe', async () => {
  const body = structuredClone(osrmBody);
  delete body.routes[0].legs[0].steps[0].maneuver.exit;
  body.routes[0].legs[0].steps[0].distance = 'invalid';
  body.routes[0].legs[0].steps[0].duration = -10;
  const app = createApp(async () => jsonResponse(body));
  const response = await request(app).get('/api/routing/route').query(validQuery);

  assert.equal(response.status, 200);
  assert.equal(response.body.steps[0].distanceMeters, 0);
  assert.equal(response.body.steps[0].durationSeconds, 0);
  assert.equal('exit' in response.body.steps[0].maneuver, false);
});

test('malformed steps are skipped without exposing upstream data', async () => {
  const body = structuredClone(osrmBody);
  body.routes[0].legs[0].steps = [
    null,
    { internalSecret: 'must-not-leak', maneuver: { location: ['bad', 51.96] } },
    body.routes[0].legs[0].steps[0],
  ];
  const app = createApp(async () => jsonResponse(body));
  const response = await request(app).get('/api/routing/route').query(validQuery);

  assert.equal(response.status, 200);
  assert.equal(response.body.steps.length, 1);
  assert.doesNotMatch(JSON.stringify(response.body), /must-not-leak/);
});

test('steps from multiple legs are flattened in route order', async () => {
  const body = structuredClone(osrmBody);
  const secondStep = {
    name: 'Достык',
    distance: 120,
    duration: 18,
    maneuver: {
      type: 'arrive',
      modifier: 'straight',
      location: [66.42, 51.97],
    },
  };
  body.routes[0].legs.push({ steps: [secondStep] });
  const app = createApp(async () => jsonResponse(body));
  const response = await request(app).get('/api/routing/route').query(validQuery);

  assert.equal(response.status, 200);
  assert.deepEqual(response.body.steps.map((step) => step.name), ['Абая', 'Достык']);
  assert.equal(response.body.steps[1].maneuver.type, 'arrive');
});

for (const [name, query] of [
  ['invalid latitude', { ...validQuery, startLat: '91' }],
  ['invalid longitude', { ...validQuery, destLng: '-181' }],
  ['missing coordinates', { ...validQuery, destLat: undefined }],
  ['NaN coordinate', { ...validQuery, startLat: 'NaN' }],
  ['Infinity coordinate', { ...validQuery, startLng: 'Infinity' }],
]) {
  test(`${name} returns 400 without upstream call`, async () => {
    let calls = 0;
    const app = createApp(async () => {
      calls++;
      return jsonResponse(osrmBody);
    });
    const response = await request(app).get('/api/routing/route').query(query);
    assert.equal(response.status, 400);
    assert.deepEqual(response.body, { error: 'Invalid route coordinates' });
    assert.equal(calls, 0);
  });
}

test('routing endpoint requires authorization', async () => {
  const app = createApp(async () => jsonResponse(osrmBody), { strictAuth: true });
  assert.equal((await request(app).get('/api/routing/route').query(validQuery)).status, 401);
  assert.equal((await request(app).get('/api/routing/route').set('Authorization', 'Bearer test').query(validQuery)).status, 200);
});

test('OSRM 502 returns stable JSON error', async () => {
  const app = createApp(async () => jsonResponse({ error: 'upstream detail' }, 502));
  const response = await request(app).get('/api/routing/route').query(validQuery);
  assert.equal(response.status, 502);
  assert.deepEqual(response.body, { error: 'Routing service is unavailable' });
});

test('configured OSRM failure does not fall back to a public server', async () => {
  const calledUrls = [];
  const app = createApp(async (url) => {
    calledUrls.push(url);
    throw new Error('OSRM unavailable');
  }, { osrmBaseUrl: 'http://tulpar-osrm:5000' });

  const response = await request(app).get('/api/routing/route').query(validQuery);

  assert.equal(response.status, 502);
  assert.deepEqual(response.body, { error: 'Routing service is unavailable' });
  assert.equal(calledUrls.length, 1);
  assert.equal(calledUrls[0].origin, 'http://tulpar-osrm:5000');
});

test('OSRM timeout returns stable 503 JSON error', async () => {
  const app = createApp((_url, { signal }) => new Promise((_resolve, reject) => {
    signal.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')));
  }), { timeoutMs: 5 });
  const response = await request(app).get('/api/routing/route').query(validQuery);
  assert.equal(response.status, 503);
  assert.deepEqual(response.body, { error: 'Routing service timed out' });
});

test('OSRM HTML response returns stable JSON error', async () => {
  const app = createApp(async () => new Response('<html>bad gateway</html>', {
    status: 200,
    headers: { 'content-type': 'text/html' },
  }));
  const response = await request(app).get('/api/routing/route').query(validQuery);
  assert.equal(response.status, 502);
  assert.match(response.body.error, /invalid response/);
  assert.doesNotMatch(JSON.stringify(response.body), /html/);
});

test('empty routes returns stable JSON error', async () => {
  const app = createApp(async () => jsonResponse({ routes: [] }));
  const response = await request(app).get('/api/routing/route').query(validQuery);
  assert.equal(response.status, 502);
  assert.match(response.body.error, /no valid route/);
});

test('malformed geometry returns stable JSON error', async () => {
  const body = structuredClone(osrmBody);
  body.routes[0].geometry.coordinates = [[66.4, 51.9], ['bad', 51.96]];
  const app = createApp(async () => jsonResponse(body));
  const response = await request(app).get('/api/routing/route').query(validQuery);
  assert.equal(response.status, 502);
  assert.match(response.body.error, /invalid geometry/);
});

test('client cannot override the configured OSRM upstream', async () => {
  let calledUrl;
  const app = createApp(async (url) => {
    calledUrl = url;
    return jsonResponse(osrmBody);
  });
  const response = await request(app).get('/api/routing/route').query({
    ...validQuery,
    upstream: 'http://127.0.0.1:5432',
    hostname: 'evil.example',
  });
  assert.equal(response.status, 200);
  assert.equal(calledUrl.origin, 'http://osrm.test:5000');
});
