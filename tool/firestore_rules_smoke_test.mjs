const projectId = 'taxi-esil';
const databaseId = '(default)';
const authBase = 'http://127.0.0.1:9099';
const firestoreBase =
  `http://127.0.0.1:8080/v1/projects/${projectId}/databases/${databaseId}`;

function stringValue(value) {
  return { stringValue: value };
}

function doubleValue(value) {
  return { doubleValue: value };
}

function integerValue(value) {
  return { integerValue: String(value) };
}

function documentName(path) {
  return `projects/${projectId}/databases/${databaseId}/documents/${path}`;
}

function createWrite(path, fields) {
  return {
    update: { name: documentName(path), fields },
    currentDocument: { exists: false },
  };
}

function serverTimestampWrite(path, fields) {
  return {
    ...createWrite(path, fields),
    updateTransforms: [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
    ],
  };
}

async function signUp() {
  const suffix = Date.now();
  const response = await fetch(
    `${authBase}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: `rules-${suffix}@tulpar.local`,
        password: 'test-password-123',
        returnSecureToken: true,
      }),
    },
  );
  const body = await response.json();
  if (!response.ok) throw new Error(`Auth emulator failed: ${JSON.stringify(body)}`);
  return { uid: body.localId, token: body.idToken };
}

async function commit(writes, token) {
  const headers = { 'content-type': 'application/json' };
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetch(`${firestoreBase}/documents:commit`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ writes }),
  });
  const text = await response.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { ok: response.ok, status: response.status, body };
}

function orderWrites(uid, orderId, { price = integerValue(750) } = {}) {
  return [
    serverTimestampWrite(`orders/${orderId}`, {
      passengerId: stringValue(uid),
      fromAddress: stringValue('Улица А, 1'),
      toAddress: stringValue('Улица Б, 2'),
      price,
      fromLat: doubleValue(51.957),
      fromLng: doubleValue(66.404),
      toLat: doubleValue(51.969),
      toLng: doubleValue(66.421),
      status: stringValue('searching'),
    }),
    serverTimestampWrite(`active_orders/${uid}`, {
      orderId: stringValue(orderId),
      role: stringValue('passenger'),
      status: stringValue('searching'),
    }),
  ];
}

function expectAllowed(result, label) {
  if (!result.ok) {
    throw new Error(`${label}: expected ALLOW, got ${result.status} ${JSON.stringify(result.body)}`);
  }
  console.log(`PASS ${label}`);
}

function expectDenied(result, label) {
  if (result.ok || result.status !== 403) {
    throw new Error(`${label}: expected DENY 403, got ${result.status} ${JSON.stringify(result.body)}`);
  }
  console.log(`PASS ${label}`);
}

const { uid, token } = await signUp();

expectAllowed(
  await commit([
    serverTimestampWrite(`users/${uid}`, {
      uid: stringValue(uid),
      name: stringValue('Rules Test'),
      phone: stringValue('+77000000000'),
      role: stringValue('passenger'),
      rating: doubleValue(5),
    }),
  ], token),
  'authenticated user profile creation',
);

expectDenied(
  await commit(orderWrites(uid, 'unauthenticated-order')),
  'unauthenticated order creation',
);

expectDenied(
  await commit(
    orderWrites(uid, 'invalid-price-order', { price: stringValue('750') }),
    token,
  ),
  'invalid order payload',
);

expectAllowed(
  await commit(orderWrites(uid, 'valid-order'), token),
  'atomic order and active binding creation',
);

expectDenied(
  await commit(orderWrites(uid, 'duplicate-order'), token),
  'second active order creation',
);

console.log('Firestore rules smoke tests passed.');
