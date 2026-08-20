import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { after, afterEach, before, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const projectId = 'tulpar-driver-profile-rules-test';
let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

function client(uid) {
  return testEnvironment.authenticatedContext(uid).firestore();
}

function draftProfile(uid, overrides = {}) {
  return {
    userId: uid,
    status: 'draft',
    carModel: '',
    carColor: '',
    carNumber: '',
    agreementVersion: '1.0',
    agreementAcceptedAt: serverTimestamp(),
    subscriptionStatus: 'inactive',
    subscriptionValidUntil: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function seededDriverProfile(uid, status, overrides = {}) {
  const now = new Date('2026-08-17T12:00:00Z');
  return {
    userId: uid,
    status,
    carModel: status === 'draft' ? '' : 'Toyota Camry',
    carColor: status === 'draft' ? '' : 'Белый',
    carNumber: status === 'draft' ? '' : '777 ABC 01',
    agreementVersion: '1.0',
    agreementAcceptedAt: now,
    subscriptionStatus: 'inactive',
    subscriptionValidUntil: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function userProfile(uid, role = 'passenger') {
  return {
    uid,
    name: `User ${uid}`,
    phone: '+7 700 000-00-00',
    role,
    rating: 5,
    createdAt: new Date('2026-08-17T12:00:00Z'),
  };
}

function searchingOrder(passengerId, overrides = {}) {
  return {
    passengerId,
    fromAddress: 'Точка А',
    toAddress: 'Точка Б',
    price: 1500,
    passengerPrice: 1500,
    agreedPrice: null,
    fromLat: 51.16,
    fromLng: 71.47,
    toLat: 51.18,
    toLng: 71.45,
    status: 'searching',
    createdAt: new Date(),
    ...overrides,
  };
}

function activeOrderBinding(
  orderId,
  role,
  status = 'searching',
  createdAt = new Date(),
) {
  return { orderId, role, status, createdAt };
}

async function seedDocuments(entries) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    for (const [path, data] of entries) {
      await setDoc(doc(database, path), data);
    }
  });
}

async function createDraft(uid = 'driver') {
  const database = client(uid);
  await assertSucceeds(
    setDoc(doc(database, 'driver_profiles', uid), draftProfile(uid)),
  );
  return database;
}

async function searchingOrders(database) {
  const createdAfter = new Date(Date.now() - 2 * 60 * 60 * 1000);
  return getDocs(
    query(
      collection(database, 'orders'),
      where('status', '==', 'searching'),
      where('createdAt', '>=', createdAfter),
      orderBy('createdAt', 'desc'),
      limit(100),
    ),
  );
}

async function acceptOrderLikeFlutter(database, orderId, driverId) {
  return runTransaction(database, async (transaction) => {
    const orderRef = doc(database, 'orders', orderId);
    const userRef = doc(database, 'users', driverId);
    const driverProfileRef = doc(database, 'driver_profiles', driverId);
    const driverActiveRef = doc(database, 'active_orders', driverId);

    const order = await transaction.get(orderRef);
    const user = await transaction.get(userRef);
    const driverProfile = await transaction.get(driverProfileRef);
    if (
      !order.exists() ||
      !user.exists() ||
      !driverProfile.exists() ||
      driverProfile.data().status !== 'approved'
    ) {
      throw new Error('Driver is not allowed to accept this order.');
    }
    if (order.data().status !== 'searching') {
      throw new Error('Order is no longer searching.');
    }

    const driverActive = await transaction.get(driverActiveRef);
    if (driverActive.exists()) {
      throw new Error('Driver already has an active order.');
    }

    const passengerActiveRef = doc(
      database,
      'active_orders',
      order.data().passengerId,
    );
    transaction.update(orderRef, {
      driverId,
      driverName: user.data().name,
      driverPhone: user.data().phone,
      carModel: driverProfile.data().carModel,
      carColor: driverProfile.data().carColor,
      carNumber: driverProfile.data().carNumber,
      passengerPrice: order.data().passengerPrice ?? order.data().price,
      agreedPrice: order.data().passengerPrice ?? order.data().price,
      price: order.data().passengerPrice ?? order.data().price,
      status: 'accepted',
      acceptedAt: serverTimestamp(),
    });
    transaction.set(driverActiveRef, {
      orderId,
      role: 'driver',
      status: 'accepted',
      createdAt: serverTimestamp(),
    });
    transaction.update(passengerActiveRef, { status: 'accepted' });
  });
}

function offerData(driverId, price, overrides = {}) {
  return {
    driverId,
    price,
    status: 'pending',
    driverName: `User ${driverId}`,
    driverPhone: '+7 700 000-00-00',
    carModel: 'Toyota Camry',
    carColor: 'Белый',
    carNumber: '777 ABC 01',
    driverRating: 5,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

async function submitOfferLikeFlutter(database, orderId, driverId, price) {
  return runTransaction(database, async (transaction) => {
    const orderRef = doc(database, 'orders', orderId);
    const userRef = doc(database, 'users', driverId);
    const profileRef = doc(database, 'driver_profiles', driverId);
    const activeRef = doc(database, 'active_orders', driverId);
    const offerRef = doc(database, `orders/${orderId}/offers`, driverId);
    const order = await transaction.get(orderRef);
    const user = await transaction.get(userRef);
    const profile = await transaction.get(profileRef);
    const active = await transaction.get(activeRef);
    const offer = await transaction.get(offerRef);
    if (!order.exists() || !user.exists() || !profile.exists() || active.exists()) {
      throw new Error('Offer precondition failed.');
    }
    if (offer.exists()) {
      transaction.update(offerRef, { price, updatedAt: serverTimestamp() });
    } else {
      transaction.set(offerRef, {
        driverId,
        price,
        status: 'pending',
        driverName: user.data().name,
        driverPhone: user.data().phone,
        carModel: profile.data().carModel,
        carColor: profile.data().carColor,
        carNumber: profile.data().carNumber,
        driverRating: user.data().rating,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }
  });
}

async function acceptOfferLikeFlutter(database, orderId, driverId) {
  return runTransaction(database, async (transaction) => {
    const orderRef = doc(database, 'orders', orderId);
    const offerRef = doc(database, `orders/${orderId}/offers`, driverId);
    const order = await transaction.get(orderRef);
    const offer = await transaction.get(offerRef);
    if (!order.exists() || !offer.exists()) throw new Error('Missing data.');
    const passengerPrice = order.data().passengerPrice ?? order.data().price;
    transaction.update(orderRef, {
      driverId,
      driverName: offer.data().driverName,
      driverPhone: offer.data().driverPhone,
      carModel: offer.data().carModel,
      carColor: offer.data().carColor,
      carNumber: offer.data().carNumber,
      passengerPrice,
      agreedPrice: offer.data().price,
      price: offer.data().price,
      status: 'accepted',
      acceptedAt: serverTimestamp(),
    });
    transaction.update(offerRef, {
      status: 'accepted',
      updatedAt: serverTimestamp(),
    });
    transaction.set(doc(database, 'active_orders', driverId), {
      orderId,
      role: 'driver',
      status: 'accepted',
      createdAt: serverTimestamp(),
    });
    transaction.update(
      doc(database, 'active_orders', order.data().passengerId),
      { status: 'accepted' },
    );
  });
}

test('ALLOW owner reads own driver profile', async () => {
  await seedDocuments([
    ['driver_profiles/driver', seededDriverProfile('driver', 'pending')],
  ]);
  await assertSucceeds(getDoc(doc(client('driver'), 'driver_profiles', 'driver')));
});

test('ALLOW owner creates own draft profile', async () => {
  await assertSucceeds(
    setDoc(
      doc(client('driver'), 'driver_profiles', 'driver'),
      draftProfile('driver'),
    ),
  );
});

test('ALLOW legacy passenger creates draft with copied vehicle without changing users.role', async () => {
  await seedDocuments([
    [
      'users/legacy',
      {
        ...userProfile('legacy', 'passenger'),
        carModel: 'Lada Vesta',
        carColor: 'Серый',
        carNumber: '123 ABC 01',
      },
    ],
  ]);
  const database = client('legacy');
  await assertSucceeds(
    setDoc(
      doc(database, 'driver_profiles', 'legacy'),
      draftProfile('legacy', {
        carModel: 'Lada Vesta',
        carColor: 'Серый',
        carNumber: '123 ABC 01',
      }),
    ),
  );
  const user = await assertSucceeds(getDoc(doc(database, 'users', 'legacy')));
  if (user.data().role !== 'passenger') {
    throw new Error('Legacy users.role was unexpectedly changed.');
  }
});

test('ALLOW draft transitions to pending with a complete vehicle', async () => {
  const database = await createDraft();
  await assertSucceeds(
    updateDoc(doc(database, 'driver_profiles', 'driver'), {
      status: 'pending',
      carModel: 'Toyota Camry',
      carColor: 'Белый',
      carNumber: '777 ABC 01',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('ALLOW approved driver reads searching orders', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['orders/order-1', searchingOrder('passenger')],
  ]);
  const result = await assertSucceeds(searchingOrders(client('driver')));
  if (result.size !== 1) throw new Error('Expected one searching order.');
});

test('ALLOW approved driver receives an empty searching-order result', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
  ]);
  const result = await assertSucceeds(searchingOrders(client('driver')));
  if (!result.empty) throw new Error('Expected an empty order result.');
});

test('ALLOW available-order query excludes searching orders older than two hours', async () => {
  const now = Date.now();
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    [
      'orders/recent-order',
      searchingOrder('passenger', { createdAt: new Date(now - 30 * 60 * 1000) }),
    ],
    [
      'orders/stale-order',
      searchingOrder('passenger', { createdAt: new Date(now - 3 * 60 * 60 * 1000) }),
    ],
  ]);
  const result = await assertSucceeds(searchingOrders(client('driver')));
  if (result.size !== 1 || result.docs[0].id !== 'recent-order') {
    throw new Error('Expected only the recent searching order.');
  }
});

test('ALLOW approved driver to create a passenger order without losing approval', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
  ]);
  const database = client('driver');
  await assertSucceeds(
    runTransaction(database, async (transaction) => {
      transaction.set(doc(database, 'orders', 'passenger-order'), {
        passengerId: 'driver',
        fromAddress: 'Точка А',
        toAddress: 'Точка Б',
        price: 1500,
        fromLat: 51.16,
        fromLng: 71.47,
        toLat: 51.18,
        toLng: 71.45,
        status: 'searching',
        createdAt: serverTimestamp(),
      });
      transaction.set(doc(database, 'active_orders', 'driver'), {
        orderId: 'passenger-order',
        role: 'passenger',
        status: 'searching',
        createdAt: serverTimestamp(),
      });
    }),
  );
  const profile = await assertSucceeds(
    getDoc(doc(database, 'driver_profiles', 'driver')),
  );
  if (profile.data().status !== 'approved') {
    throw new Error('Passenger order unexpectedly changed driver approval.');
  }
});

test('ALLOW real Flutter acceptance flow and preserve one-active-order invariant', async () => {
  await seedDocuments([
    ['users/passenger', userProfile('passenger', 'passenger')],
    ['users/driver', userProfile('driver', 'passenger')],
    ['users/driver-2', userProfile('driver-2', 'passenger')],
    ['users/passenger-2', userProfile('passenger-2', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['driver_profiles/driver-2', seededDriverProfile('driver-2', 'approved')],
  ]);

  const passengerDatabase = client('passenger');
  await assertSucceeds(
    runTransaction(passengerDatabase, async (transaction) => {
      const orderRef = doc(passengerDatabase, 'orders', 'order-1');
      const activeRef = doc(passengerDatabase, 'active_orders', 'passenger');
      const active = await transaction.get(activeRef);
      if (active.exists()) throw new Error('Passenger already has an order.');
      transaction.set(orderRef, {
        ...searchingOrder('passenger'),
        createdAt: serverTimestamp(),
      });
      transaction.set(activeRef, {
        orderId: 'order-1',
        role: 'passenger',
        status: 'searching',
        createdAt: serverTimestamp(),
      });
    }),
  );

  const database = client('driver');
  const emptyDriverBinding = await assertSucceeds(
    getDoc(doc(database, 'active_orders', 'driver')),
  );
  if (emptyDriverBinding.exists()) {
    throw new Error('Expected the approved driver binding to be absent.');
  }

  await assertSucceeds(acceptOrderLikeFlutter(database, 'order-1', 'driver'));

  const acceptedOrder = await assertSucceeds(
    getDoc(doc(database, 'orders', 'order-1')),
  );
  if (
    acceptedOrder.data().status !== 'accepted' ||
    acceptedOrder.data().driverId !== 'driver'
  ) {
    throw new Error('Order was not assigned to the accepting driver.');
  }
  const driverBinding = await assertSucceeds(
    getDoc(doc(database, 'active_orders', 'driver')),
  );
  const passengerBinding = await assertSucceeds(
    getDoc(doc(passengerDatabase, 'active_orders', 'passenger')),
  );
  if (
    driverBinding.data().orderId !== 'order-1' ||
    driverBinding.data().status !== 'accepted' ||
    passengerBinding.data().orderId !== 'order-1' ||
    passengerBinding.data().status !== 'accepted'
  ) {
    throw new Error('Active-order bindings were not synchronized.');
  }

  const availableAfterAcceptance = await assertSucceeds(
    searchingOrders(client('driver-2')),
  );
  if (!availableAfterAcceptance.empty) {
    throw new Error('Accepted order remained in the available-order query.');
  }
  await assertFails(
    acceptOrderLikeFlutter(client('driver-2'), 'order-1', 'driver-2'),
  );

  const passengerTwoDatabase = client('passenger-2');
  await assertSucceeds(
    runTransaction(passengerTwoDatabase, async (transaction) => {
      const orderRef = doc(passengerTwoDatabase, 'orders', 'order-2');
      const activeRef = doc(
        passengerTwoDatabase,
        'active_orders',
        'passenger-2',
      );
      const active = await transaction.get(activeRef);
      if (active.exists()) throw new Error('Passenger already has an order.');
      transaction.set(orderRef, {
        ...searchingOrder('passenger-2'),
        createdAt: serverTimestamp(),
      });
      transaction.set(activeRef, {
        orderId: 'order-2',
        role: 'passenger',
        status: 'searching',
        createdAt: serverTimestamp(),
      });
    }),
  );
  await assert.rejects(
    acceptOrderLikeFlutter(database, 'order-2', 'driver'),
    /already has an active order/,
  );
  await assertFails(
    runTransaction(database, async (transaction) => {
      const orderRef = doc(database, 'orders', 'order-2');
      const driverActiveRef = doc(database, 'active_orders', 'driver');
      const passengerActiveRef = doc(
        database,
        'active_orders',
        'passenger-2',
      );
      transaction.update(orderRef, {
        driverId: 'driver',
        driverName: 'User driver',
        driverPhone: '+7 700 000-00-00',
        carModel: 'Toyota Camry',
        carColor: 'Белый',
        carNumber: '777 ABC 01',
        status: 'accepted',
        acceptedAt: serverTimestamp(),
      });
      transaction.set(driverActiveRef, {
        orderId: 'order-2',
        role: 'driver',
        status: 'accepted',
        createdAt: serverTimestamp(),
      });
      transaction.update(passengerActiveRef, { status: 'accepted' });
    }),
  );
});

test('DENY approved driver reads another user active-order binding', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    [
      'active_orders/victim',
      activeOrderBinding('victim-order', 'passenger'),
    ],
  ]);
  await assertFails(getDoc(doc(client('driver'), 'active_orders', 'victim')));
});

test('DENY pending driver acceptance transaction', async () => {
  const createdAt = new Date();
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'pending')],
    ['orders/order-1', searchingOrder('passenger', { createdAt })],
    [
      'active_orders/passenger',
      activeOrderBinding('order-1', 'passenger', 'searching', createdAt),
    ],
  ]);
  await assertFails(acceptOrderLikeFlutter(client('driver'), 'order-1', 'driver'));
});

test('DENY creating an active-order binding for another driver', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
  ]);
  await assertFails(
    setDoc(doc(client('driver'), 'active_orders', 'other-driver'), {
      orderId: 'order-1',
      role: 'driver',
      status: 'accepted',
      createdAt: serverTimestamp(),
    }),
  );
});

test('DENY accepting an order already occupied by another driver', async () => {
  await seedDocuments([
    ['users/driver-2', userProfile('driver-2', 'passenger')],
    ['driver_profiles/driver-2', seededDriverProfile('driver-2', 'approved')],
    [
      'orders/order-1',
      {
        ...searchingOrder('passenger'),
        driverId: 'driver-1',
        driverName: 'User driver-1',
        driverPhone: '+7 700 000-00-00',
        carModel: 'Toyota Camry',
        carColor: 'Белый',
        carNumber: '777 ABC 01',
        status: 'accepted',
        acceptedAt: new Date(),
      },
    ],
  ]);
  await assertFails(
    acceptOrderLikeFlutter(client('driver-2'), 'order-1', 'driver-2'),
  );
});

test('ALLOW approved assigned driver writes current tracking point', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    [
      'orders/order-1',
      {
        ...searchingOrder('passenger'),
        driverId: 'driver',
        status: 'accepted',
      },
    ],
  ]);
  await assertSucceeds(
    setDoc(doc(client('driver'), 'orders/order-1/tracking/current'), {
      lat: 51.16,
      lng: 71.47,
      updatedAt: serverTimestamp(),
    }),
  );
});

test('DENY reading another user driver profile', async () => {
  await seedDocuments([
    ['driver_profiles/victim', seededDriverProfile('victim', 'pending')],
  ]);
  await assertFails(getDoc(doc(client('attacker'), 'driver_profiles', 'victim')));
});

test('DENY creating driver profile for another uid', async () => {
  await assertFails(
    setDoc(
      doc(client('attacker'), 'driver_profiles', 'victim'),
      draftProfile('victim'),
    ),
  );
});

test('DENY creating an approved profile', async () => {
  await assertFails(
    setDoc(
      doc(client('driver'), 'driver_profiles', 'driver'),
      draftProfile('driver', {
        status: 'approved',
        carModel: 'Toyota Camry',
        carColor: 'Белый',
        carNumber: '777 ABC 01',
      }),
    ),
  );
});

test('DENY draft transitions directly to approved', async () => {
  const database = await createDraft();
  await assertFails(
    updateDoc(doc(database, 'driver_profiles', 'driver'), {
      status: 'approved',
      carModel: 'Toyota Camry',
      carColor: 'Белый',
      carNumber: '777 ABC 01',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('DENY pending transitions to approved in ordinary client', async () => {
  await seedDocuments([
    ['driver_profiles/driver', seededDriverProfile('driver', 'pending')],
  ]);
  await assertFails(
    updateDoc(doc(client('driver'), 'driver_profiles', 'driver'), {
      status: 'approved',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('DENY pending transitions to suspended in ordinary client', async () => {
  await seedDocuments([
    ['driver_profiles/driver', seededDriverProfile('driver', 'pending')],
  ]);
  await assertFails(
    updateDoc(doc(client('driver'), 'driver_profiles', 'driver'), {
      status: 'suspended',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('DENY changing subscriptionStatus', async () => {
  const database = await createDraft();
  await assertFails(
    updateDoc(doc(database, 'driver_profiles', 'driver'), {
      subscriptionStatus: 'active',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('DENY changing subscriptionValidUntil', async () => {
  const database = await createDraft();
  await assertFails(
    updateDoc(doc(database, 'driver_profiles', 'driver'), {
      subscriptionValidUntil: new Date('2030-01-01T00:00:00Z'),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('DENY changing userId', async () => {
  const database = await createDraft();
  await assertFails(
    updateDoc(doc(database, 'driver_profiles', 'driver'), {
      userId: 'attacker',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('DENY changing createdAt', async () => {
  const database = await createDraft();
  await assertFails(
    updateDoc(doc(database, 'driver_profiles', 'driver'), {
      createdAt: new Date('2030-01-01T00:00:00Z'),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('DENY adding an unknown field', async () => {
  const database = await createDraft();
  await assertFails(
    updateDoc(doc(database, 'driver_profiles', 'driver'), {
      unexpectedPrivilege: true,
      updatedAt: serverTimestamp(),
    }),
  );
});

test('DENY user without approved driver profile reads searching orders', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['orders/order-1', searchingOrder('passenger')],
  ]);
  await assertFails(searchingOrders(client('driver')));
});

test('DENY pending driver reads searching orders', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'pending')],
    ['orders/order-1', searchingOrder('passenger')],
  ]);
  await assertFails(searchingOrders(client('driver')));
});

test('DENY suspended driver reads searching orders', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'suspended')],
    ['orders/order-1', searchingOrder('passenger')],
  ]);
  await assertFails(searchingOrders(client('driver')));
});

test('DENY users.role driver bypass when driver profile is pending', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'driver')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'pending')],
    ['orders/order-1', searchingOrder('passenger')],
  ]);
  await assertFails(searchingOrders(client('driver')));
});

test('ALLOW users.role passenger when driver profile is approved', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver', 'passenger')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['orders/order-1', searchingOrder('passenger')],
  ]);
  await assertSucceeds(searchingOrders(client('driver')));
});

test('ALLOW multiple driver offers and passenger accepts exactly one offer atomically', async () => {
  const createdAt = new Date();
  await seedDocuments([
    ['users/passenger', userProfile('passenger')],
    ['users/driver-a', userProfile('driver-a')],
    ['users/driver-b', userProfile('driver-b')],
    ['users/driver-c', userProfile('driver-c')],
    ['driver_profiles/driver-a', seededDriverProfile('driver-a', 'approved')],
    ['driver_profiles/driver-b', seededDriverProfile('driver-b', 'approved')],
    ['driver_profiles/driver-c', seededDriverProfile('driver-c', 'approved')],
    ['orders/trade-order', searchingOrder('passenger', {
      price: 600,
      passengerPrice: 600,
      createdAt,
    })],
    ['active_orders/passenger', activeOrderBinding('trade-order', 'passenger', 'searching', createdAt)],
  ]);

  await assertSucceeds(
    submitOfferLikeFlutter(client('driver-a'), 'trade-order', 'driver-a', 800),
  );
  await assertSucceeds(
    submitOfferLikeFlutter(client('driver-b'), 'trade-order', 'driver-b', 700),
  );
  const offers = await assertSucceeds(
    getDocs(collection(client('passenger'), 'orders/trade-order/offers')),
  );
  assert.equal(offers.size, 2);

  await assertSucceeds(
    acceptOfferLikeFlutter(client('passenger'), 'trade-order', 'driver-b'),
  );
  const acceptedOrder = await getDoc(
    doc(client('passenger'), 'orders', 'trade-order'),
  );
  assert.equal(acceptedOrder.data().driverId, 'driver-b');
  assert.equal(acceptedOrder.data().passengerPrice, 600);
  assert.equal(acceptedOrder.data().agreedPrice, 700);
  assert.equal(acceptedOrder.data().price, 700);
  assert.equal(acceptedOrder.data().status, 'accepted');

  const selectedOffer = await getDoc(
    doc(client('passenger'), 'orders/trade-order/offers', 'driver-b'),
  );
  assert.equal(selectedOffer.data().status, 'accepted');
  const unselectedOffer = await getDoc(
    doc(client('passenger'), 'orders/trade-order/offers', 'driver-a'),
  );
  assert.equal(unselectedOffer.data().status, 'pending');
  const selectedBinding = await getDoc(
    doc(client('driver-b'), 'active_orders', 'driver-b'),
  );
  assert.equal(selectedBinding.data().orderId, 'trade-order');
  const unselectedBinding = await getDoc(
    doc(client('driver-a'), 'active_orders', 'driver-a'),
  );
  assert.equal(unselectedBinding.exists(), false);
  await assertFails(
    updateDoc(
      doc(client('driver-a'), 'orders/trade-order/offers', 'driver-a'),
      { price: 900, updatedAt: serverTimestamp() },
    ),
  );
  await assertFails(
    acceptOfferLikeFlutter(client('passenger'), 'trade-order', 'driver-a'),
  );
  const available = await assertSucceeds(searchingOrders(client('driver-c')));
  assert.equal(available.empty, true);
});

test('ALLOW ordinary acceptance while pending offers exist and keep passenger price', async () => {
  const createdAt = new Date();
  await seedDocuments([
    ['users/passenger', userProfile('passenger')],
    ['users/driver-a', userProfile('driver-a')],
    ['users/driver-b', userProfile('driver-b')],
    ['users/driver-c', userProfile('driver-c')],
    ['driver_profiles/driver-a', seededDriverProfile('driver-a', 'approved')],
    ['driver_profiles/driver-b', seededDriverProfile('driver-b', 'approved')],
    ['driver_profiles/driver-c', seededDriverProfile('driver-c', 'approved')],
    ['orders/ordinary-order', searchingOrder('passenger', {
      price: 600,
      passengerPrice: 600,
      createdAt,
    })],
    ['active_orders/passenger', activeOrderBinding('ordinary-order', 'passenger', 'searching', createdAt)],
  ]);
  await assertSucceeds(
    submitOfferLikeFlutter(client('driver-a'), 'ordinary-order', 'driver-a', 800),
  );
  await assertSucceeds(
    submitOfferLikeFlutter(client('driver-b'), 'ordinary-order', 'driver-b', 700),
  );
  await assertSucceeds(
    acceptOrderLikeFlutter(client('driver-c'), 'ordinary-order', 'driver-c'),
  );
  const order = await getDoc(doc(client('driver-c'), 'orders', 'ordinary-order'));
  assert.equal(order.data().driverId, 'driver-c');
  assert.equal(order.data().passengerPrice, 600);
  assert.equal(order.data().agreedPrice, 600);
  assert.equal(order.data().price, 600);
});

test('ALLOW driver updates only own pending offer price', async () => {
  const createdAt = new Date();
  await seedDocuments([
    ['users/passenger', userProfile('passenger')],
    ['users/driver', userProfile('driver')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['orders/order-offer', searchingOrder('passenger', { createdAt })],
    ['active_orders/passenger', activeOrderBinding('order-offer', 'passenger', 'searching', createdAt)],
  ]);
  const database = client('driver');
  await assertSucceeds(
    submitOfferLikeFlutter(database, 'order-offer', 'driver', 1700),
  );
  await assertSucceeds(
    submitOfferLikeFlutter(database, 'order-offer', 'driver', 1800),
  );
  const offer = await getDoc(
    doc(database, 'orders/order-offer/offers', 'driver'),
  );
  assert.equal(offer.data().price, 1800);
});

test('DENY pending or suspended driver creates an offer', async () => {
  const createdAt = new Date();
  await seedDocuments([
    ['users/pending', userProfile('pending')],
    ['users/suspended', userProfile('suspended')],
    ['driver_profiles/pending', seededDriverProfile('pending', 'pending')],
    ['driver_profiles/suspended', seededDriverProfile('suspended', 'suspended')],
    ['orders/order-offer', searchingOrder('passenger', { createdAt })],
    ['active_orders/passenger', activeOrderBinding('order-offer', 'passenger', 'searching', createdAt)],
  ]);
  await assertFails(
    setDoc(
      doc(client('pending'), 'orders/order-offer/offers', 'pending'),
      offerData('pending', 1700),
    ),
  );
  await assertFails(
    setDoc(
      doc(client('suspended'), 'orders/order-offer/offers', 'suspended'),
      offerData('suspended', 1700),
    ),
  );
});

test('DENY driver with active order creates an offer', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['orders/order-offer', searchingOrder('passenger')],
    ['active_orders/driver', activeOrderBinding('other-order', 'driver', 'accepted')],
  ]);
  await assertFails(
    setDoc(
      doc(client('driver'), 'orders/order-offer/offers', 'driver'),
      offerData('driver', 1700),
    ),
  );
});

test('DENY accepting an old offer after driver gets another active order', async () => {
  const createdAt = new Date();
  await seedDocuments([
    ['users/passenger', userProfile('passenger')],
    ['users/driver', userProfile('driver')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['orders/order-offer', searchingOrder('passenger', { createdAt })],
    ['active_orders/passenger', activeOrderBinding('order-offer', 'passenger', 'searching', createdAt)],
    ['active_orders/driver', activeOrderBinding('other-order', 'driver', 'accepted')],
    ['orders/order-offer/offers/driver', {
      ...offerData('driver', 1700),
      createdAt,
      updatedAt: createdAt,
    }],
  ]);
  await assertFails(
    acceptOfferLikeFlutter(client('passenger'), 'order-offer', 'driver'),
  );
});

test('DENY spoofed driver id and a second offer document', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['orders/order-offer', searchingOrder('passenger')],
  ]);
  const database = client('driver');
  await assertFails(
    setDoc(
      doc(database, 'orders/order-offer/offers', 'victim'),
      offerData('driver', 1700),
    ),
  );
  await assertFails(
    setDoc(
      doc(database, 'orders/order-offer/offers', 'driver-copy'),
      offerData('driver-copy', 1800),
    ),
  );
});

test('DENY driver changes another driver offer or forces accepted status', async () => {
  await seedDocuments([
    ['users/driver-a', userProfile('driver-a')],
    ['users/driver-b', userProfile('driver-b')],
    ['driver_profiles/driver-a', seededDriverProfile('driver-a', 'approved')],
    ['driver_profiles/driver-b', seededDriverProfile('driver-b', 'approved')],
    ['orders/order-offer', searchingOrder('passenger')],
    ['orders/order-offer/offers/driver-a', {
      ...offerData('driver-a', 1700),
      createdAt: new Date(),
      updatedAt: new Date(),
    }],
  ]);
  await assertFails(
    updateDoc(
      doc(client('driver-b'), 'orders/order-offer/offers', 'driver-a'),
      { price: 1800, updatedAt: serverTimestamp() },
    ),
  );
  await assertFails(
    updateDoc(
      doc(client('driver-a'), 'orders/order-offer/offers', 'driver-a'),
      { status: 'accepted', updatedAt: serverTimestamp() },
    ),
  );
});

test('DENY non-owner passenger reads or accepts another passenger offer', async () => {
  const createdAt = new Date();
  await seedDocuments([
    ['users/passenger', userProfile('passenger')],
    ['users/stranger', userProfile('stranger')],
    ['users/driver', userProfile('driver')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['orders/order-offer', searchingOrder('passenger', { createdAt })],
    ['active_orders/passenger', activeOrderBinding('order-offer', 'passenger', 'searching', createdAt)],
    ['orders/order-offer/offers/driver', {
      ...offerData('driver', 1700),
      createdAt,
      updatedAt: createdAt,
    }],
  ]);
  await assertFails(
    getDoc(doc(client('stranger'), 'orders/order-offer/offers', 'driver')),
  );
  await assertFails(
    acceptOfferLikeFlutter(client('stranger'), 'order-offer', 'driver'),
  );
});

test('DENY passenger changes offer price while accepting it', async () => {
  await seedDocuments([
    ['users/passenger', userProfile('passenger')],
    ['users/driver', userProfile('driver')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['orders/order-offer', searchingOrder('passenger')],
    ['orders/order-offer/offers/driver', {
      ...offerData('driver', 1700),
      createdAt: new Date(),
      updatedAt: new Date(),
    }],
  ]);
  await assertFails(
    updateDoc(
      doc(client('passenger'), 'orders/order-offer/offers', 'driver'),
      { price: 1501, status: 'accepted', updatedAt: serverTimestamp() },
    ),
  );
});

test('DENY offer at or below passenger price', async () => {
  await seedDocuments([
    ['users/driver', userProfile('driver')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['orders/order-offer', searchingOrder('passenger')],
  ]);
  await assertFails(
    setDoc(
      doc(client('driver'), 'orders/order-offer/offers', 'driver'),
      offerData('driver', 1500),
    ),
  );
});

test('DENY submitting or accepting offers after order leaves searching', async () => {
  const acceptedAt = new Date();
  await seedDocuments([
    ['users/passenger', userProfile('passenger')],
    ['users/driver', userProfile('driver')],
    ['driver_profiles/driver', seededDriverProfile('driver', 'approved')],
    ['orders/accepted-order', {
      ...searchingOrder('passenger'),
      driverId: 'other-driver',
      driverName: 'Other',
      driverPhone: '+7 700 111-11-11',
      carModel: 'Kia Rio',
      carColor: 'Черный',
      carNumber: '111 AAA 01',
      agreedPrice: 1500,
      status: 'accepted',
      acceptedAt,
    }],
    ['orders/accepted-order/offers/driver', {
      ...offerData('driver', 1700),
      createdAt: acceptedAt,
      updatedAt: acceptedAt,
    }],
  ]);
  await assertFails(
    setDoc(
      doc(client('driver'), 'orders/accepted-order/offers', 'driver'),
      offerData('driver', 1800),
    ),
  );
  await assertFails(
    acceptOfferLikeFlutter(client('passenger'), 'accepted-order', 'driver'),
  );
});
