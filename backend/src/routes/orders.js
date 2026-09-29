import express from 'express';
import { randomUUID } from 'node:crypto';
import {
  acquireAccountLifecycleLock,
  loadAccountLifecycleState,
} from '../account-lifecycle.js';
import { isSelfOrder } from '../security-policy.js';
import { canCancelCityOrder, validateCityCancellationReason } from '../city-cancellation-policy.js';
import { areUsersBlocked } from '../block-policy.js';
import {
  expireStaleSearchingOrders,
  validateOrderCreatePayload,
} from '../order-policy.js';

export const nextOrderMaximumDistanceMeters = 300;

export function nextOrderDistanceMeters({
  currentDestinationLat,
  currentDestinationLng,
  newPickupLat,
  newPickupLng,
}) {
  const values = [
    currentDestinationLat,
    currentDestinationLng,
    newPickupLat,
    newPickupLng,
  ];
  if (!values.every(Number.isFinite)) return null;
  const radians = (value) => value * Math.PI / 180;
  const latDelta = radians(newPickupLat - currentDestinationLat);
  const lngDelta = radians(newPickupLng - currentDestinationLng);
  const a = Math.sin(latDelta / 2) ** 2
    + Math.cos(radians(currentDestinationLat))
    * Math.cos(radians(newPickupLat))
    * Math.sin(lngDelta / 2) ** 2;
  return 6371000 * 2 * Math.asin(Math.sqrt(a));
}

export function createOrdersRouter({
  pool,
  requireAuth,
  sendToUser,
  sendToAvailableDrivers,
  sendPushToUser,
  requireCurrentTerms = (_req, _res, next) => next(),
}) {

  const router = express.Router();

  async function pushOrderEvent(orderId, recipient, type, extraData = {}) {
    try {
      const result = await pool.query(
        `SELECT o.service_type,
                COALESCE(u.firebase_uid, u.id::text) AS identity_key
         FROM orders o
         JOIN users u ON u.id = o.${recipient === 'driver' ? 'driver_id' : 'passenger_id'}
         WHERE o.id = $1`,
        [orderId],
      );
      const row = result.rows[0];
      if (row?.identity_key) {
        await sendPushToUser(row.identity_key, {
          data: { type, orderId, serviceType: row.service_type, ...extraData },
        });
      }
    } catch (pushError) {
      console.error('[OrderLifecyclePush]', pushError);
    }
  }

  // Создание заказа пассажиром
  router.post('/', requireAuth, async (req, res) => {
    const validation = validateOrderCreatePayload(req.body);
    if (!validation.ok) {
      return res.status(400).json({ error: validation.error });
    }

    const {
      serviceType,
      passengerPrice,
      pickupAddress,
      destinationAddress,
      pickupLat,
      pickupLng,
      destinationLat,
      destinationLng,
      distanceMeters,
      itemDescription,
      senderName,
      senderPhone,
      recipientName,
      recipientPhone,
      pickupHandoffType,
      pickupEntrance,
      pickupApartment,
      pickupFloor,
      pickupIntercom,
      pickupComment,
      destinationHandoffType,
      destinationEntrance,
      destinationApartment,
      destinationFloor,
      destinationIntercom,
      destinationComment,
      departureAt,
      passengerCount,
      hasLuggage,
      intercityComment,
    } = validation.value;

    await expireStaleSearchingOrders(pool);
    const client = await pool.connect();

    try {

      await client.query('BEGIN');
      await acquireAccountLifecycleLock(client, req.user.uid);
      const lifecycle = await loadAccountLifecycleState(client, req.user.uid);
      if (lifecycle.kind !== 'active') {
        await client.query('ROLLBACK');
        return res.status(lifecycle.kind === 'deleted' ? 410 : 409).json({
          code: lifecycle.kind === 'deleted' ? 'account_deleted' : 'account_unavailable',
          error: lifecycle.kind === 'deleted'
            ? 'Account has been deleted'
            : 'User profile must be synchronized first',
        });
      }

      const userResult = await client.query(
        `
        SELECT id
        FROM users
        WHERE (firebase_uid = $1 OR id::text = $1)
        FOR UPDATE
        `,
        [req.user.uid],
      );

      if (userResult.rows.length === 0) {
        await client.query('ROLLBACK');

        return res.status(409).json({
          error: 'User profile must be synchronized first',
        });
      }

      const passengerId = userResult.rows[0].id;

      const localOrder = serviceType === 'city' || serviceType === 'delivery';
      // Temporary compatibility path for pre-multi-city Flutter releases.
      // Missing cityId can only mean the historical Esil market; remove this
      // fallback after those client versions are no longer supported.
      const requestedCity = req.body?.cityId ?? 'esil';
      if (localOrder && (typeof requestedCity !== 'string' || !/^[a-z][a-z0-9-]{1,39}$/.test(requestedCity))) {
        await client.query('ROLLBACK');
        return res.status(400).json({ code: 'invalid_city', error: 'Invalid city' });
      }
      let cityId = null;
      let citySlug = null;
      if (localOrder) {
        const cityResult = await client.query(
          'SELECT id, slug FROM cities WHERE slug = $1 AND is_enabled = TRUE',
          [requestedCity],
        );
        if (cityResult.rows.length === 0) {
          await client.query('ROLLBACK');
          return res.status(400).json({ code: 'invalid_city', error: 'Invalid city' });
        }
        cityId = cityResult.rows[0].id;
        citySlug = cityResult.rows[0].slug;
      }

      const result = await client.query(
        `
        INSERT INTO orders (
          passenger_id,
          service_type,
	  status,
          passenger_price,
          pickup_address,
          destination_address,
          pickup_lat,
          pickup_lng,
          destination_lat,
          destination_lng,
          distance_meters
          ,city_id
        )
        VALUES (
          $1,
          $2,
	  'searching',
          $3,
          $4,
          $5,
          $6,
          $7,
          $8,
          $9,
	  $10,
          $11
        )
        RETURNING
          id,
          service_type,
	  status,
          passenger_price,
          agreed_price,
          pickup_address,
          destination_address,
          pickup_lat,
          pickup_lng,
          destination_lat,
          destination_lng,
          distance_meters,
          city_id,
          created_at
        `,
        [
  passengerId,
  serviceType,
  passengerPrice,
  pickupAddress ?? null,
  destinationAddress ?? null,
  pickupLat ?? null,
  pickupLng ?? null,
  destinationLat ?? null,
  destinationLng ?? null,
  distanceMeters ?? null,
  cityId,
],
      );

      if (serviceType === 'city' && Array.isArray(validation.value.stops)) {
        for (const stop of validation.value.stops) {
          await client.query(
            `INSERT INTO order_stops (order_id, sequence, type, address, latitude, longitude)
             VALUES ($1, $2, 'destination', $3, $4, $5)`,
            [result.rows[0].id, stop.sequence, stop.address, stop.latitude, stop.longitude],
          );
        }
      }

      const order = result.rows[0];

      if (serviceType === 'delivery') {
        await client.query(
          `
          INSERT INTO delivery_details (
            order_id,
            item_description,
            sender_name,
            sender_phone,
            recipient_name,
            recipient_phone,
            pickup_handoff_type,
            pickup_entrance,
            pickup_apartment,
            pickup_floor,
            pickup_intercom,
            pickup_comment,
            destination_handoff_type,
            destination_entrance,
            destination_apartment,
            destination_floor,
            destination_intercom,
            destination_comment
          )
          VALUES (
            $1, $2, $3, $4, $5, $6,
            $7, $8, $9, $10, $11, $12,
            $13, $14, $15, $16, $17, $18
          )
          `,
          [
            order.id,
            itemDescription.trim(),
            senderName?.trim() || null,
            senderPhone?.trim() || req.user.phone || null,
            recipientName?.trim() || null,
            recipientPhone.trim(),
            pickupHandoffType,
            pickupEntrance?.trim() || null,
            pickupApartment?.trim() || null,
            pickupFloor?.trim() || null,
            pickupIntercom?.trim() || null,
            pickupComment?.trim() || null,
            destinationHandoffType,
            destinationEntrance?.trim() || null,
            destinationApartment?.trim() || null,
            destinationFloor?.trim() || null,
            destinationIntercom?.trim() || null,
            destinationComment?.trim() || null,
          ],
        );
      }

      if (serviceType === 'intercity') {
        await client.query(
          `
          INSERT INTO intercity_details (
            order_id,
            departure_at,
            passenger_count,
            has_luggage,
            comment
          )
          VALUES ($1, $2, $3, $4, $5)
          `,
          [
            order.id,
            departureAt,
            passengerCount,
            hasLuggage,
            intercityComment,
          ],
        );
      }

      await client.query('COMMIT');

      try {
        await sendToAvailableDrivers({
          type: 'order_created',
          order: {
            id: order.id,
            serviceType: order.service_type,
            cityId: citySlug,
            passengerPrice: order.passenger_price,
            pickupAddress: order.pickup_address,
            destinationAddress: order.destination_address,
            pickupLat: order.pickup_lat,
            pickupLng: order.pickup_lng,
            destinationLat: order.destination_lat,
            destinationLng: order.destination_lng,
            distanceMeters: order.distance_meters,
            stops: validation.value.stops ?? [{ sequence: 0, type: 'destination', address: order.destination_address, latitude: order.destination_lat, longitude: order.destination_lng }],
            createdAt: order.created_at,
          },
        });
      } catch (error) {
        console.error('[OrderCreateNotify]', error);
      }

        res.status(201).json({
        id: order.id,
        serviceType: order.service_type,
        cityId: citySlug,
	status: order.status,
        passengerPrice: order.passenger_price,
        agreedPrice: order.agreed_price,
        pickupAddress: order.pickup_address,
        destinationAddress: order.destination_address,
        pickupLat: order.pickup_lat,
        pickupLng: order.pickup_lng,
        destinationLat: order.destination_lat,
        destinationLng: order.destination_lng,
        distanceMeters: order.distance_meters,
        stops: validation.value.stops ?? [{ sequence: 0, type: 'destination', address: order.destination_address, latitude: order.destination_lat, longitude: order.destination_lng }],
        createdAt: order.created_at,
      });
    } catch (error) {
      await client.query('ROLLBACK');

      if (error.code === '23505') {
        return res.status(409).json({
          error: 'Passenger already has an active order',
        });
      }

      console.error('[OrderCreate]', error);

      res.status(500).json({
        error: 'Failed to create order',
      });
    } finally {
      client.release();
    }
  });

  // Список доступных заказов для водителя
  // Можно фильтровать: ?serviceType=city|delivery|intercity
  router.get('/available', requireAuth, async (req, res) => {
    try {
      await expireStaleSearchingOrders(pool);

      const serviceType = req.query.serviceType ?? null;

      if (
        serviceType !== null &&
        !['city', 'delivery', 'intercity'].includes(serviceType)
      ) {
        return res.status(400).json({
          error: 'Invalid service type',
        });
      }

      const driverResult = await pool.query(
        `
        SELECT
          u.id,
          dp.status,
          dp.access_exempt,
          dp.work_city_id,
          EXISTS (
            SELECT 1
            FROM driver_subscriptions ds
            WHERE
              ds.driver_id = u.id
              AND ds.status = 'active'
              AND ds.payment_status = 'paid'
              AND ds.valid_until > now()
          ) AS subscription_active
        FROM users u
        LEFT JOIN driver_profiles dp
          ON dp.user_id = u.id
        WHERE (u.firebase_uid = $1 OR u.id::text = $1)
        `,
        [req.user.uid],
      );

      if (driverResult.rows.length === 0) {
        return res.status(404).json({
          error: 'User profile not found',
        });
      }

      const driver = driverResult.rows[0];

      const accessGranted = driver.status === 'active';

      if (!accessGranted) {
        return res.status(403).json({
          error: 'Driver access is not active',
        });
      }

      const result = await pool.query(
        `
        SELECT
          o.id,
          o.service_type,
          o.city_id,
          o.passenger_price,
          o.pickup_address,
          o.destination_address,
          o.pickup_lat,
          o.pickup_lng,
          o.destination_lat,
          o.destination_lng,
          o.distance_meters,
          o.created_at,
          COALESCE(
            (SELECT jsonb_agg(jsonb_build_object('sequence', s.sequence, 'type', s.type, 'address', s.address, 'latitude', s.latitude, 'longitude', s.longitude, 'reachedAt', s.reached_at) ORDER BY s.sequence)
             FROM order_stops s WHERE s.order_id = o.id),
            jsonb_build_array(jsonb_build_object('sequence', 0, 'type', 'destination', 'address', o.destination_address, 'latitude', o.destination_lat, 'longitude', o.destination_lng))
          ) AS stops,

          dd.item_description,
          dd.pickup_handoff_type,
          dd.pickup_entrance,
          dd.pickup_apartment,
          dd.pickup_floor,
          dd.pickup_intercom,
          dd.pickup_comment,
          dd.destination_handoff_type,
          dd.destination_entrance,
          dd.destination_apartment,
          dd.destination_floor,
          dd.destination_intercom,
          dd.destination_comment,

          ic.departure_at,
          ic.passenger_count,
          ic.has_luggage,
          ic.comment AS intercity_comment

        FROM orders o

        JOIN service_types st
          ON st.code = o.service_type

        LEFT JOIN delivery_details dd
          ON dd.order_id = o.id

        LEFT JOIN intercity_details ic
          ON ic.order_id = o.id

        WHERE
          o.status = 'searching'
          AND st.enabled = TRUE
          AND ($1::text IS NULL OR o.service_type = $1)
          AND (o.service_type NOT IN ('city', 'delivery') OR o.city_id = $2)
          AND NOT EXISTS (
            SELECT 1 FROM user_blocks ub
            WHERE (ub.blocker_user_id = o.passenger_id AND ub.blocked_user_id = $3)
               OR (ub.blocker_user_id = $3 AND ub.blocked_user_id = o.passenger_id)
          )

        ORDER BY o.created_at DESC
        LIMIT 100
        `,
        [serviceType, driver.work_city_id, driver.id],
      );

      res.json(
        result.rows.map((order) => {
          let delivery = null;
          let intercity = null;

          if (order.service_type === 'delivery') {
            delivery = {
              itemDescription: order.item_description,
              pickupHandoffType: order.pickup_handoff_type,
              pickupEntrance: order.pickup_entrance,
              pickupApartment: order.pickup_apartment,
              pickupFloor: order.pickup_floor,
              pickupIntercom: order.pickup_intercom,
              pickupComment: order.pickup_comment,
              destinationHandoffType:
                order.destination_handoff_type,
              destinationEntrance:
                order.destination_entrance,
              destinationApartment:
                order.destination_apartment,
              destinationFloor:
                order.destination_floor,
              destinationIntercom:
                order.destination_intercom,
              destinationComment:
                order.destination_comment,
            };
          }

          if (order.service_type === 'intercity') {
            intercity = {
              departureAt: order.departure_at,
              passengerCount: order.passenger_count,
              hasLuggage: order.has_luggage,
              comment: order.intercity_comment,
            };
          }

          return {
            id: order.id,
            serviceType: order.service_type,
            cityId: order.city_id,
            passengerPrice: order.passenger_price,
            pickupAddress: order.pickup_address,
            destinationAddress: order.destination_address,
            pickupLat: order.pickup_lat,
            pickupLng: order.pickup_lng,
            destinationLat: order.destination_lat,
            destinationLng: order.destination_lng,
            distanceMeters: order.distance_meters,
            createdAt: order.created_at,
            stops: order.stops,
            delivery,
            intercity,
          };
        }),
      );
    } catch (error) {
      console.error('[OrdersAvailable]', error);

      res.status(500).json({
        error: 'Failed to load available orders',
      });
    }
  });

  router.get('/next-candidates', requireAuth, async (req, res) => {
    try {
      await expireStaleSearchingOrders(pool);
      const driverResult = await pool.query(
        `
        SELECT
          u.id AS driver_id,
          dp.status AS driver_profile_status,
          dp.access_exempt,
          dp.work_city_id,
          EXISTS (
            SELECT 1
            FROM driver_subscriptions ds
            WHERE ds.driver_id = u.id
              AND ds.status = 'active'
              AND ds.payment_status = 'paid'
              AND ds.valid_until > now()
          ) AS subscription_active,
          current_order.id AS current_order_id,
          current_order.destination_lat,
          current_order.destination_lng,
          EXISTS (
            SELECT 1
            FROM orders queued_order
            WHERE queued_order.driver_id = u.id
              AND queued_order.status = 'queued'
          ) AS has_queued_order
        FROM users u
        JOIN driver_profiles dp ON dp.user_id = u.id
        LEFT JOIN orders current_order
          ON current_order.driver_id = u.id
          AND current_order.service_type = 'city'
          AND current_order.city_id = dp.work_city_id
          AND current_order.status = 'in_progress'
        WHERE (u.firebase_uid = $1 OR u.id::text = $1)
        `,
        [req.user.uid],
      );

      if (driverResult.rows.length === 0) {
        return res.status(403).json({ error: 'Driver profile not found' });
      }
      const driver = driverResult.rows[0];
      const accessGranted = driver.driver_profile_status === 'active';
      if (!accessGranted) {
        return res.status(403).json({ error: 'Driver access is not active' });
      }
      if (
        !driver.current_order_id
        || driver.has_queued_order === true
        || driver.destination_lat == null
        || driver.destination_lng == null
      ) {
        return res.json([]);
      }

      const candidates = await pool.query(
        `
        SELECT
          candidate.id,
          candidate.pickup_address,
          candidate.destination_address,
          candidate.passenger_price,
          candidate.pickup_lat,
          candidate.pickup_lng,
          round((
            6371000 * 2 * asin(
              sqrt(
                power(sin(radians(candidate.pickup_lat - $1::double precision) / 2), 2)
                + cos(radians($1::double precision))
                * cos(radians(candidate.pickup_lat))
                * power(sin(radians(candidate.pickup_lng - $2::double precision) / 2), 2)
              )
            )
          )::numeric)::integer AS distance_to_current_destination_meters
        FROM orders candidate
        JOIN service_types st ON st.code = candidate.service_type
        WHERE candidate.service_type = 'city'
          AND candidate.status = 'searching'
          AND candidate.driver_id IS NULL
          AND candidate.passenger_id <> $3
          AND NOT EXISTS (
            SELECT 1 FROM user_blocks ub
            WHERE (ub.blocker_user_id = candidate.passenger_id AND ub.blocked_user_id = $3)
               OR (ub.blocker_user_id = $3 AND ub.blocked_user_id = candidate.passenger_id)
          )
          AND candidate.city_id = $5
          AND candidate.pickup_lat IS NOT NULL
          AND candidate.pickup_lng IS NOT NULL
          AND st.enabled = TRUE
          AND 6371000 * 2 * asin(
            sqrt(
              power(sin(radians(candidate.pickup_lat - $1::double precision) / 2), 2)
              + cos(radians($1::double precision))
              * cos(radians(candidate.pickup_lat))
              * power(sin(radians(candidate.pickup_lng - $2::double precision) / 2), 2)
            )
          ) <= $4
        ORDER BY distance_to_current_destination_meters, candidate.created_at
        LIMIT 20
        `,
        [
          driver.destination_lat,
          driver.destination_lng,
          driver.driver_id,
          nextOrderMaximumDistanceMeters,
          driver.work_city_id,
        ],
      );

      return res.json(candidates.rows.map((order) => ({
        id: order.id,
        pickupAddress: order.pickup_address,
        destinationAddress: order.destination_address,
        passengerPrice: order.passenger_price,
        distanceToCurrentDestinationMeters:
          order.distance_to_current_destination_meters,
      })));
    } catch (error) {
      console.error('[NextOrderCandidates]', error);
      return res.status(500).json({ error: 'Failed to load next orders' });
    }
  });

  router.post('/:orderId/accept-next', requireAuth, async (req, res) => {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await acquireAccountLifecycleLock(client, req.user.uid);
      const lifecycle = await loadAccountLifecycleState(client, req.user.uid);
      if (lifecycle.kind !== 'active') {
        await client.query('ROLLBACK');
        return res.status(lifecycle.kind === 'deleted' ? 410 : 403).json({
          code: lifecycle.kind === 'deleted'
            ? 'account_deleted'
            : 'account_unavailable',
          error: lifecycle.kind === 'deleted'
            ? 'Account has been deleted'
            : 'Driver profile not found',
        });
      }

      const driverResult = await client.query(
        `
        SELECT
          u.id,
          dp.status,
          dp.access_exempt,
          dp.work_city_id,
          EXISTS (
            SELECT 1
            FROM driver_subscriptions ds
            WHERE ds.driver_id = u.id
              AND ds.status = 'active'
              AND ds.payment_status = 'paid'
              AND ds.valid_until > now()
          ) AS subscription_active
        FROM users u
        JOIN driver_profiles dp ON dp.user_id = u.id
        WHERE (u.firebase_uid = $1 OR u.id::text = $1)
        FOR UPDATE OF u, dp
        `,
        [req.user.uid],
      );
      if (driverResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(403).json({ error: 'Driver profile not found' });
      }
      const driver = driverResult.rows[0];
      const accessGranted = driver.status === 'active';
      if (!accessGranted) {
        await client.query('ROLLBACK');
        return res.status(403).json({ error: 'Driver access is not active' });
      }

      const currentResult = await client.query(
        `SELECT id, city_id, destination_lat, destination_lng
         FROM orders
         WHERE driver_id = $1
           AND service_type = 'city'
           AND status = 'in_progress'
         FOR UPDATE`,
        [driver.id],
      );
      if (currentResult.rows.length !== 1) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Current CITY order is not in progress' });
      }
      const currentOrder = currentResult.rows[0];

      const queuedResult = await client.query(
        `SELECT id FROM orders
         WHERE driver_id = $1 AND status = 'queued'
         LIMIT 1
         FOR UPDATE`,
        [driver.id],
      );
      if (queuedResult.rows.length > 0) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Driver already has a queued order' });
      }

      const nextResult = await client.query(
        `SELECT id, passenger_id, driver_id, status, service_type, city_id,
                passenger_price, pickup_lat, pickup_lng
         FROM orders
         WHERE id = $1
         FOR UPDATE`,
        [req.params.orderId],
      );
      if (nextResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Order not found' });
      }
      const nextOrder = nextResult.rows[0];
      const distanceMeters = nextOrderDistanceMeters({
        currentDestinationLat: currentOrder.destination_lat,
        currentDestinationLng: currentOrder.destination_lng,
        newPickupLat: nextOrder.pickup_lat,
        newPickupLng: nextOrder.pickup_lng,
      });
      if (
        nextOrder.service_type !== 'city'
        || Number(nextOrder.city_id) !== Number(driver.work_city_id)
        || Number(nextOrder.city_id) !== Number(currentOrder.city_id)
        || nextOrder.status !== 'searching'
        || nextOrder.driver_id !== null
        || isSelfOrder({ passengerId: nextOrder.passenger_id, driverId: driver.id })
        || distanceMeters === null
        || distanceMeters > nextOrderMaximumDistanceMeters
      ) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Order is not an available next order' });
      }

      const acceptedResult = await client.query(
        `UPDATE orders
         SET driver_id = $1,
             status = 'queued',
             agreed_price = passenger_price,
             queued_after_order_id = $2,
             updated_at = now()
         WHERE id = $3
           AND service_type = 'city'
           AND status = 'searching'
           AND driver_id IS NULL
         RETURNING id, status, driver_id, queued_after_order_id,
                   passenger_price, agreed_price`,
        [driver.id, currentOrder.id, nextOrder.id],
      );
      if (acceptedResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Order was accepted by another driver' });
      }

      await client.query('COMMIT');
      const acceptedOrder = acceptedResult.rows[0];
      return res.json({
        id: acceptedOrder.id,
        status: acceptedOrder.status,
        driverId: acceptedOrder.driver_id,
        queuedAfterOrderId: acceptedOrder.queued_after_order_id,
        passengerPrice: acceptedOrder.passenger_price,
        agreedPrice: acceptedOrder.agreed_price,
        distanceToCurrentDestinationMeters: Math.round(distanceMeters),
      });
    } catch (error) {
      await client.query('ROLLBACK');
      if (error.code === '23505') {
        return res.status(409).json({ error: 'Driver already has a queued order' });
      }
      console.error('[NextOrderAccept]', error);
      return res.status(500).json({ error: 'Failed to accept next order' });
    } finally {
      client.release();
    }
  });

  router.post('/:orderId/accept', requireAuth, async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    await acquireAccountLifecycleLock(client, req.user.uid);
    const lifecycle = await loadAccountLifecycleState(client, req.user.uid);
    if (lifecycle.kind !== 'active') {
      await client.query('ROLLBACK');
      return res.status(lifecycle.kind === 'deleted' ? 410 : 403).json({
        code: lifecycle.kind === 'deleted' ? 'account_deleted' : 'account_unavailable',
        error: lifecycle.kind === 'deleted'
          ? 'Account has been deleted'
          : 'Driver profile not found',
      });
    }

    const driverResult = await client.query(
      `
      SELECT
        u.id,
        u.name,
        u.phone,
        u.rating,
        dp.status,
        dp.access_exempt,
        dp.car_model,
        dp.car_color,
        dp.car_number,
        dp.work_city_id,
        EXISTS (
          SELECT 1
          FROM driver_subscriptions ds
          WHERE
            ds.driver_id = u.id
            AND ds.status = 'active'
            AND ds.payment_status = 'paid'
            AND ds.valid_until > now()
        ) AS subscription_active
      FROM users u
      JOIN driver_profiles dp
        ON dp.user_id = u.id
      WHERE (u.firebase_uid = $1 OR u.id::text = $1)
      FOR UPDATE
      `,
      [req.user.uid],
    );

    if (driverResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(403).json({
        error: 'Driver profile not found',
      });
    }

    const driver = driverResult.rows[0];

    const accessGranted = driver.status === 'active';

    if (!accessGranted) {
      await client.query('ROLLBACK');

      return res.status(403).json({
        error: 'Driver access is not active',
      });
    }

    const orderResult = await client.query(
      `
      SELECT
        id,
        passenger_id,
        driver_id,
        status,
        passenger_price,
        service_type,
        city_id
      FROM orders
      WHERE id = $1
      FOR UPDATE
      `,
      [req.params.orderId],
    );

    if (orderResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        error: 'Order not found',
      });
    }

    const order = orderResult.rows[0];

    if (['city', 'delivery'].includes(order.service_type) &&
        Number(order.city_id) !== Number(driver.work_city_id)) {
      await client.query('ROLLBACK');
      return res.status(403).json({ code: 'wrong_city', error: 'Order is in another city' });
    }

    if (isSelfOrder({ passengerId: order.passenger_id, driverId: driver.id })) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Driver cannot accept their own passenger order',
      });
    }

    if (await areUsersBlocked(client, order.passenger_id, driver.id)) {
      await client.query('ROLLBACK');
      return res.status(403).json({ code: 'user_blocked', error: 'Future matching is blocked' });
    }

    if (order.status !== 'searching' || order.driver_id !== null) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Order is no longer available',
      });
    }

    const activeOrderResult = await client.query(
      `
      SELECT id
      FROM orders
      WHERE
        driver_id = $1
        AND status IN (
          'accepted',
          'driver_arrived',
          'in_progress'
        )
      LIMIT 1
      `,
      [driver.id],
    );

    if (activeOrderResult.rows.length > 0) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Driver already has an active order',
      });
    }

    const acceptedResult = await client.query(
      `
      UPDATE orders
      SET
        driver_id = $1,
        status = 'accepted',
        agreed_price = passenger_price,
        accepted_at = now(),
        updated_at = now()
      WHERE
        id = $2
        AND status = 'searching'
        AND driver_id IS NULL
      RETURNING
        id,
        passenger_id,
        driver_id,
        status,
        service_type,
        passenger_price,
        agreed_price,
        accepted_at,
        created_at
      `,
      [driver.id, order.id],
    );

    if (acceptedResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Order was accepted by another driver',
      });
    }

    await client.query(
      `
      UPDATE order_offers
      SET
        status = 'rejected',
        updated_at = now()
      WHERE
        order_id = $1
        AND status = 'pending'
      `,
      [order.id],
    );

    await client.query('COMMIT');

    const acceptedOrder = acceptedResult.rows[0];

    try {
      const passengerUidResult = await pool.query(
        `
        SELECT COALESCE(firebase_uid, id::text) AS identity_key
        FROM users
        WHERE id = $1
        `,
        [acceptedOrder.passenger_id],
      );

      const acceptedPayload = {
        type: 'order_accepted',
        orderId: acceptedOrder.id,
        status: acceptedOrder.status,
        agreedPrice: acceptedOrder.agreed_price,
        acceptedAt: acceptedOrder.accepted_at,
      };
      const passengerFirebaseUid =
        passengerUidResult.rows[0]?.identity_key ?? null;

      if (passengerFirebaseUid) {
        sendToUser(passengerFirebaseUid, acceptedPayload);
      }
      sendToUser(req.user.uid, acceptedPayload);
      if (passengerFirebaseUid) {
        await sendPushToUser(passengerFirebaseUid, {
          data: {
            type: 'accepted',
            orderId: acceptedOrder.id,
            serviceType: acceptedOrder.service_type,
          },
        });
      }
    } catch (error) {
      console.error('[OrderAcceptNotify]', error);
    }

    res.json({
      id: acceptedOrder.id,
      status: acceptedOrder.status,
      passengerPrice: acceptedOrder.passenger_price,
      agreedPrice: acceptedOrder.agreed_price,
      acceptedAt: acceptedOrder.accepted_at,
      driver: {
        id: driver.id,
        name: driver.name,
        phone: driver.phone,
        rating: Number(driver.rating),
        carModel: driver.car_model,
        carColor: driver.car_color,
        carNumber: driver.car_number,
      },
    });
  } catch (error) {
    await client.query('ROLLBACK');

    if (error.code === '23505') {
      return res.status(409).json({
        error: 'Driver already has an active order',
      });
    }

    console.error('[OrderAccept]', error);

    res.status(500).json({
      error: 'Failed to accept order',
    });
  } finally {
    client.release();
  }
});

  router.post('/:orderId/offers', requireAuth, async (req, res) => {
  const client = await pool.connect();

  try {
    const price = req.body?.price;

    if (!Number.isInteger(price) || price <= 0 || price > 1000000) {
      return res.status(400).json({
        error: 'Invalid offer price',
      });
    }

    await client.query('BEGIN');
    await acquireAccountLifecycleLock(client, req.user.uid);
    const lifecycle = await loadAccountLifecycleState(client, req.user.uid);
    if (lifecycle.kind !== 'active') {
      await client.query('ROLLBACK');
      return res.status(lifecycle.kind === 'deleted' ? 410 : 403).json({
        code: lifecycle.kind === 'deleted' ? 'account_deleted' : 'account_unavailable',
        error: lifecycle.kind === 'deleted'
          ? 'Account has been deleted'
          : 'Driver profile not found',
      });
    }

    const driverResult = await client.query(
      `
      SELECT
        u.id,
        dp.status,
        dp.access_exempt,
        dp.work_city_id,
        EXISTS (
          SELECT 1
          FROM driver_subscriptions ds
          WHERE
            ds.driver_id = u.id
            AND ds.status = 'active'
            AND ds.payment_status = 'paid'
            AND ds.valid_until > now()
        ) AS subscription_active
      FROM users u
      JOIN driver_profiles dp
        ON dp.user_id = u.id
      WHERE (u.firebase_uid = $1 OR u.id::text = $1)
      FOR UPDATE
      `,
      [req.user.uid],
    );

    if (driverResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(403).json({
        error: 'Driver profile not found',
      });
    }

    const driver = driverResult.rows[0];

    const accessGranted = driver.status === 'active';

    if (!accessGranted) {
      await client.query('ROLLBACK');

      return res.status(403).json({
        error: 'Driver access is not active',
      });
    }

    const orderResult = await client.query(
      `
SELECT
  o.id,
  o.passenger_id,
  o.passenger_price,
  o.status,
  o.driver_id,
  o.service_type,
  o.city_id,
  o.pickup_lat,
  o.pickup_lng,
  COALESCE(passenger.firebase_uid, passenger.id::text) AS passenger_firebase_uid
FROM orders o
JOIN users passenger
  ON passenger.id = o.passenger_id
WHERE o.id = $1
FOR UPDATE
      `,
      [req.params.orderId],
    );

    if (orderResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        error: 'Order not found',
      });
    }

    const order = orderResult.rows[0];

    if (['city', 'delivery'].includes(order.service_type) &&
        Number(order.city_id) !== Number(driver.work_city_id)) {
      await client.query('ROLLBACK');
      return res.status(403).json({ code: 'wrong_city', error: 'Order is in another city' });
    }

    if (isSelfOrder({ passengerId: order.passenger_id, driverId: driver.id })) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Driver cannot offer on their own passenger order',
      });
    }

    if (await areUsersBlocked(client, order.passenger_id, driver.id)) {
      await client.query('ROLLBACK');
      return res.status(403).json({ code: 'user_blocked', error: 'Future matching is blocked' });
    }

    if (order.status !== 'searching' || order.driver_id !== null) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Order is no longer available',
      });
    }

    if (price <= order.passenger_price) {
      await client.query('ROLLBACK');

      return res.status(400).json({
        error: 'Offer price must be higher than passenger price',
      });
    }

    const activeOrderResult = await client.query(
      `
      SELECT id, service_type, status, destination_lat, destination_lng
      FROM orders
      WHERE
        driver_id = $1
        AND status IN (
          'accepted',
          'driver_arrived',
          'in_progress'
        )
      LIMIT 1
      FOR UPDATE
      `,
      [driver.id],
    );

    if (activeOrderResult.rows.length > 0) {
      const currentOrder = activeOrderResult.rows[0];
      const queuedOrderResult = await client.query(
        `SELECT id FROM orders
         WHERE driver_id = $1 AND status = 'queued'
         LIMIT 1
         FOR UPDATE`,
        [driver.id],
      );
      const distanceMeters = nextOrderDistanceMeters({
        currentDestinationLat: currentOrder.destination_lat,
        currentDestinationLng: currentOrder.destination_lng,
        newPickupLat: order.pickup_lat,
        newPickupLng: order.pickup_lng,
      });
      if (
        currentOrder.status !== 'in_progress'
        || currentOrder.service_type !== 'city'
        || queuedOrderResult.rows.length > 0
        || order.service_type !== 'city'
        || distanceMeters === null
        || distanceMeters > nextOrderMaximumDistanceMeters
      ) {
        await client.query('ROLLBACK');
        return res.status(409).json({
          error: 'Order is not an available next order',
        });
      }
    }

    const offerResult = await client.query(
      `
      INSERT INTO order_offers (
        order_id,
        driver_id,
        price,
        status
      )
      VALUES (
        $1,
        $2,
        $3,
        'pending'
      )
      ON CONFLICT (order_id, driver_id)
      DO UPDATE SET
        price = EXCLUDED.price,
        status = 'pending',
        updated_at = now()
      RETURNING
        id,
        order_id,
        driver_id,
        price,
        status,
        created_at,
        updated_at
      `,
      [order.id, driver.id, price],
    );

    await client.query('COMMIT');

    const offer = offerResult.rows[0];

    try {
      if (order.passenger_firebase_uid) {
        sendToUser(order.passenger_firebase_uid, {
          type: 'offer_created',
          orderId: order.id,
          offer: {
            id: offer.id,
            driverId: offer.driver_id,
            price: offer.price,
            status: offer.status,
            createdAt: offer.created_at,
            updatedAt: offer.updated_at,
          },
        });
      }
    } catch (error) {
      console.error('[OrderOfferNotify]', error);
    }

      res.status(201).json({
      id: offer.id,
      orderId: offer.order_id,
      driverId: offer.driver_id,
      price: offer.price,
      status: offer.status,
      createdAt: offer.created_at,
      updatedAt: offer.updated_at,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[OrderOfferCreate]', error);

    res.status(500).json({
      error: 'Failed to create offer',
    });
  } finally {
    client.release();
  }
});


  router.get('/:orderId/offers', requireAuth, async (req, res) => {
    try {
      const accessResult = await pool.query(
        `
        SELECT
          o.id,
          COALESCE(passenger.firebase_uid, passenger.id::text) AS passenger_uid,
          o.driver_approaching_notified_at IS NOT NULL AS was_already_notified,
          cu.id AS current_user_id,
          dp.user_id AS driver_profile_user_id
        FROM orders o
        JOIN users passenger
          ON passenger.id = o.passenger_id
        LEFT JOIN users cu
          ON (cu.firebase_uid = $2 OR cu.id::text = $2)
        LEFT JOIN driver_profiles dp
          ON dp.user_id = cu.id
        WHERE o.id = $1
        `,
        [req.params.orderId, req.user.uid],
      );

      if (accessResult.rows.length === 0) {
        return res.status(404).json({
          error: 'Order not found',
        });
      }

      const access = accessResult.rows[0];

      const isPassenger =
        access.passenger_uid === req.user.uid;

      const isDriver =
        access.current_user_id !== null &&
        access.driver_profile_user_id !== null;

      if (!isPassenger && !isDriver) {
        return res.status(403).json({
          error: 'Access denied',
        });
      }

      let result;

      if (isPassenger) {
        // Пассажир видит все ожидающие предложения.
        result = await pool.query(
          `
          SELECT
            oo.id,
            oo.price,
            oo.status,
            oo.created_at,
            oo.updated_at,
            u.id AS driver_id,
            u.name AS driver_name,
            u.rating AS driver_rating,
            dp.car_model,
            dp.car_color,
            dp.car_number
          FROM order_offers oo
          JOIN users u
            ON u.id = oo.driver_id
          JOIN driver_profiles dp
            ON dp.user_id = u.id
          WHERE
            oo.order_id = $1
            AND oo.status = 'pending'
          ORDER BY oo.price ASC, oo.created_at ASC
          `,
          [req.params.orderId],
        );
      } else {
        // Водитель видит только собственное предложение.
        result = await pool.query(
          `
          SELECT
            oo.id,
            oo.price,
            oo.status,
            oo.created_at,
            oo.updated_at,
            u.id AS driver_id,
            u.name AS driver_name,
            u.rating AS driver_rating,
            dp.car_model,
            dp.car_color,
            dp.car_number
          FROM order_offers oo
          JOIN users u
            ON u.id = oo.driver_id
          JOIN driver_profiles dp
            ON dp.user_id = u.id
          WHERE
            oo.order_id = $1
            AND oo.driver_id = $2
          ORDER BY oo.created_at DESC
          LIMIT 1
          `,
          [
            req.params.orderId,
            access.current_user_id,
          ],
        );
      }

      res.json(
        result.rows.map((offer) => ({
          id: offer.id,
          price: offer.price,
          status: offer.status,
          driver: {
            id: offer.driver_id,
            name: offer.driver_name,
            rating: Number(offer.driver_rating),
            carModel: offer.car_model,
            carColor: offer.car_color,
            carNumber: offer.car_number,
          },
          createdAt: offer.created_at,
          updatedAt: offer.updated_at,
        })),
      );
    } catch (error) {
      console.error('[OrderOffersList]', error);

      res.status(500).json({
        error: 'Failed to load offers',
      });
    }
  });

  router.post('/:orderId/offers/:offerId/accept', requireAuth, async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const accessResult = await client.query(
      `
      SELECT o.id
      FROM orders o
      JOIN users u
        ON u.id = o.passenger_id
      WHERE
        o.id = $1
        AND (u.firebase_uid = $2 OR u.id::text = $2)
      `,
      [req.params.orderId, req.user.uid],
    );

    if (accessResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({
        error: 'Order not found or access denied',
      });
    }

    const preliminaryOfferResult = await client.query(
      `SELECT oo.driver_id,
              COALESCE(driver.firebase_uid, driver.id::text) AS driver_firebase_uid
       FROM order_offers oo
       JOIN users driver ON driver.id = oo.driver_id
       WHERE oo.id = $1 AND oo.order_id = $2`,
      [req.params.offerId, req.params.orderId],
    );
    if (preliminaryOfferResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Offer not found' });
    }
    const preliminaryOffer = preliminaryOfferResult.rows[0];
    await acquireAccountLifecycleLock(
      client,
      preliminaryOffer.driver_firebase_uid,
    );
    const driverLockResult = await client.query(
      'SELECT id FROM users WHERE id = $1 FOR UPDATE',
      [preliminaryOffer.driver_id],
    );
    if (driverLockResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Driver is no longer available' });
    }

    const orderResult = await client.query(
      `SELECT o.id, o.passenger_id, o.driver_id, o.status,
              o.service_type, o.city_id, o.passenger_price, o.pickup_lat, o.pickup_lng
       FROM orders o
       JOIN users passenger ON passenger.id = o.passenger_id
       WHERE o.id = $1
         AND (passenger.firebase_uid = $2 OR passenger.id::text = $2)
       FOR UPDATE OF o`,
      [req.params.orderId, req.user.uid],
    );
    if (orderResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Order not found or access denied' });
    }
    const order = orderResult.rows[0];

    if (await areUsersBlocked(client, order.passenger_id, preliminaryOffer.driver_id)) {
      await client.query('ROLLBACK');
      return res.status(403).json({ code: 'user_blocked', error: 'Future matching is blocked' });
    }

    if (order.status !== 'searching' || order.driver_id !== null) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'Order is no longer available',
      });
    }

    const offerResult = await client.query(
      `
      SELECT
        oo.id,
        oo.driver_id,
        oo.price,
        oo.status,
        oo.updated_at,
        u.name AS driver_name,
        u.phone AS driver_phone,
        u.rating AS driver_rating,
        dp.status AS driver_profile_status,
        dp.access_exempt,
        dp.car_model,
        dp.car_color,
        dp.car_number,
        dp.work_city_id,
        EXISTS (
          SELECT 1
          FROM driver_subscriptions ds
          WHERE
            ds.driver_id = oo.driver_id
            AND ds.status = 'active'
            AND ds.payment_status = 'paid'
            AND ds.valid_until > now()
        ) AS subscription_active
      FROM order_offers oo
      JOIN users u
        ON u.id = oo.driver_id
      JOIN driver_profiles dp
        ON dp.user_id = oo.driver_id
      WHERE
        oo.id = $1
        AND oo.order_id = $2
      FOR UPDATE
      `,
      [req.params.offerId, order.id],
    );

    if (offerResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        error: 'Offer not found',
      });
    }

    const offer = offerResult.rows[0];

    if (['city', 'delivery'].includes(order.service_type) &&
        Number(order.city_id) !== Number(offer.work_city_id)) {
      await client.query('ROLLBACK');
      return res.status(409).json({ code: 'wrong_city', error: 'Driver works in another city' });
    }

    if (offer.status !== 'pending') {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Offer is no longer active',
      });
    }

    const driverAccessGranted = offer.driver_profile_status === 'active';

    if (!driverAccessGranted) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Driver access is no longer active',
      });
    }

    const offerContextResult = await client.query(
      `
      SELECT id, status, destination_lat, destination_lng
      FROM orders
      WHERE
        driver_id = $1
        AND service_type = 'city'
        AND started_at IS NOT NULL
        AND started_at <= $2
        AND (completed_at IS NULL OR completed_at >= $2)
      ORDER BY started_at DESC
      LIMIT 2
      FOR UPDATE
      `,
      [offer.driver_id, offer.updated_at],
    );

    let acceptedOrderResult;
    if (offerContextResult.rows.length > 0) {
      if (offerContextResult.rows.length !== 1) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Next order offer is no longer valid' });
      }
      const currentOrder = offerContextResult.rows[0];
      const queuedResult = await client.query(
        `SELECT id FROM orders
         WHERE driver_id = $1 AND status = 'queued'
         LIMIT 1
         FOR UPDATE`,
        [offer.driver_id],
      );
      const distanceMeters = nextOrderDistanceMeters({
        currentDestinationLat: currentOrder.destination_lat,
        currentDestinationLng: currentOrder.destination_lng,
        newPickupLat: order.pickup_lat,
        newPickupLng: order.pickup_lng,
      });
      if (
        currentOrder.status !== 'in_progress'
        || queuedResult.rows.length > 0
        || order.service_type !== 'city'
        || distanceMeters === null
        || distanceMeters > nextOrderMaximumDistanceMeters
      ) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Next order offer is no longer valid' });
      }
      acceptedOrderResult = await client.query(
        `UPDATE orders
         SET driver_id = $1, status = 'queued', agreed_price = $2,
             queued_after_order_id = $3, updated_at = now()
         WHERE id = $4 AND service_type = 'city'
           AND status = 'searching' AND driver_id IS NULL
         RETURNING id, passenger_id, driver_id, status, passenger_price,
                   agreed_price, accepted_at, created_at,
                   queued_after_order_id`,
        [offer.driver_id, offer.price, currentOrder.id, order.id],
      );
    } else {
      const activeDriverOrder = await client.query(
        `SELECT id FROM orders
         WHERE driver_id = $1
           AND status IN ('accepted', 'driver_arrived', 'in_progress')
         LIMIT 1
         FOR UPDATE`,
        [offer.driver_id],
      );
      if (activeDriverOrder.rows.length > 0) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Driver already has an active order' });
      }
      acceptedOrderResult = await client.query(
        `UPDATE orders
         SET driver_id = $1, status = 'accepted', agreed_price = $2,
             accepted_at = now(), updated_at = now()
         WHERE id = $3 AND status = 'searching' AND driver_id IS NULL
         RETURNING id, passenger_id, driver_id, status, passenger_price,
                   agreed_price, accepted_at, created_at,
                   queued_after_order_id`,
        [offer.driver_id, offer.price, order.id],
      );
    }

    if (acceptedOrderResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Order was accepted by another driver',
      });
    }

    await client.query(
      `
      UPDATE order_offers
      SET
        status = CASE
          WHEN id = $1 THEN 'accepted'
          ELSE 'rejected'
        END,
        updated_at = now()
      WHERE
        order_id = $2
        AND status = 'pending'
      `,
      [offer.id, order.id],
    );

    await client.query('COMMIT');

    const acceptedOrder = acceptedOrderResult.rows[0];
    if (acceptedOrder.status === 'accepted') {
      try {
        const driverUidResult = await pool.query(
          'SELECT COALESCE(firebase_uid, id::text) AS identity_key FROM users WHERE id = $1',
          [offer.driver_id],
        );
        const driverUid = driverUidResult.rows[0]?.identity_key;
        if (driverUid) await sendPushToUser(driverUid, {
          data: { type: 'offer_accepted', orderId: acceptedOrder.id, serviceType: order.service_type },
        });
      } catch (pushError) {
        console.error('[OrderOfferAcceptPush]', pushError);
      }
    }

    res.json({
      id: acceptedOrder.id,
      status: acceptedOrder.status,
      passengerPrice: acceptedOrder.passenger_price,
      agreedPrice: acceptedOrder.agreed_price,
      acceptedAt: acceptedOrder.accepted_at,
      queuedAfterOrderId: acceptedOrder.queued_after_order_id,
      driver: {
        id: offer.driver_id,
        name: offer.driver_name,
        phone: offer.driver_phone,
        rating: Number(offer.driver_rating),
        carModel: offer.car_model,
        carColor: offer.car_color,
        carNumber: offer.car_number,
      },
    });
  } catch (error) {
    await client.query('ROLLBACK');

    if (error.code === '23505') {
      return res.status(409).json({
        error: 'Driver already has an active order',
      });
    }

    console.error('[OrderOfferAccept]', error);

    res.status(500).json({
      error: 'Failed to accept offer',
    });
  } finally {
    client.release();
  }
});

  // Водитель сообщает, что прибыл к пассажиру
router.post('/:orderId/arrive', requireAuth, async (req, res) => {
  try {
    const result = await pool.query(
      `
      UPDATE orders o
      SET
        status = 'driver_arrived',
        driver_arrived_at = now(),
        updated_at = now()
      FROM users u
      WHERE
        o.id = $1
        AND o.driver_id = u.id
        AND (u.firebase_uid = $2 OR u.id::text = $2)
        AND o.status = 'accepted'
      RETURNING
        o.id,
        o.status,
        o.driver_arrived_at,
        (
          SELECT COALESCE(passenger.firebase_uid, passenger.id::text)
          FROM users passenger
          WHERE passenger.id = o.passenger_id
        ) AS passenger_uid
      `,
      [req.params.orderId, req.user.uid],
    );

    if (result.rows.length === 0) {
      return res.status(409).json({
        error: 'Order cannot be marked as arrived',
      });
    }

	await notifyOrderParticipants(req.params.orderId, {
  type: 'order_status_changed',
  orderId: req.params.orderId,
  status: 'driver_arrived',
  driverArrivedAt: result.rows[0].driver_arrived_at,
});

    const passengerUid = result.rows[0].passenger_uid;

    if (passengerUid) {
      try {
        await sendPushToUser(passengerUid, {
          data: {
            type: 'driver_arrived',
            orderId: req.params.orderId,
          },
        });
      } catch (pushError) {
        console.error('[OrderArrivePush]', pushError);
      }
    }

    res.json({
      id: result.rows[0].id,
      status: result.rows[0].status,
      driverArrivedAt: result.rows[0].driver_arrived_at,
    });
  } catch (error) {
    console.error('[OrderArrive]', error);

    res.status(500).json({
      error: 'Failed to update order',
    });
  }
});


// Водитель начинает поездку
router.post('/:orderId/start', requireAuth, async (req, res) => {
  try {
    const result = await pool.query(
      `
      UPDATE orders o
      SET
        status = 'in_progress',
        started_at = now(),
        updated_at = now()
      FROM users u
      WHERE
        o.id = $1
        AND o.driver_id = u.id
        AND (u.firebase_uid = $2 OR u.id::text = $2)
        AND o.status = 'driver_arrived'
      RETURNING
        o.id,
        o.status,
        o.started_at
      `,
      [req.params.orderId, req.user.uid],
    );

    if (result.rows.length === 0) {
      return res.status(409).json({
        error: 'Order cannot be started',
      });
    }

	await notifyOrderParticipants(req.params.orderId, {
  type: 'order_status_changed',
  orderId: req.params.orderId,
  status: 'in_progress',
  startedAt: result.rows[0].started_at,
});
    await pushOrderEvent(req.params.orderId, 'passenger', 'in_progress');

    res.json({
      id: result.rows[0].id,
      status: result.rows[0].status,
      startedAt: result.rows[0].started_at,
    });
  } catch (error) {
    console.error('[OrderStart]', error);

    res.status(500).json({
      error: 'Failed to start order',
    });
  }
});


// Водитель завершает поездку
router.post('/:orderId/stops/advance', requireAuth, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      `SELECT s.id, s.sequence
       FROM order_stops s
       JOIN orders o ON o.id = s.order_id
       JOIN users driver ON driver.id = o.driver_id
       WHERE o.id = $1
         AND (driver.firebase_uid = $2 OR driver.id::text = $2)
         AND o.status = 'in_progress'
         AND s.reached_at IS NULL
       ORDER BY s.sequence
       FOR UPDATE OF s`,
      [req.params.orderId, req.user.uid],
    );
    if (result.rows.length < 2) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'No intermediate stop to advance' });
    }
    await client.query('UPDATE order_stops SET reached_at = now() WHERE id = $1', [result.rows[0].id]);
    const stopsResult = await client.query(
      `SELECT sequence, type, address, latitude, longitude, reached_at
       FROM order_stops WHERE order_id = $1 ORDER BY sequence`,
      [req.params.orderId],
    );
    await client.query('COMMIT');
    return res.json({ stops: stopsResult.rows.map((stop) => ({
      sequence: stop.sequence,
      type: stop.type,
      address: stop.address,
      latitude: stop.latitude,
      longitude: stop.longitude,
      reachedAt: stop.reached_at,
    })) });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[OrderStopAdvance]', error);
    return res.status(500).json({ error: 'Failed to advance order stop' });
  } finally {
    client.release();
  }
});

router.post('/:orderId/complete', requireAuth, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await acquireAccountLifecycleLock(client, req.user.uid);
    const lifecycle = await loadAccountLifecycleState(client, req.user.uid);
    if (lifecycle.kind !== 'active') {
      await client.query('ROLLBACK');
      return res.status(lifecycle.kind === 'deleted' ? 410 : 403).json({
        code: lifecycle.kind === 'deleted'
          ? 'account_deleted'
          : 'account_unavailable',
        error: lifecycle.kind === 'deleted'
          ? 'Account has been deleted'
          : 'Driver profile not found',
      });
    }
    const driverId = lifecycle.user.id;

    const currentResult = await client.query(
      `SELECT id, driver_id, service_type, status, agreed_price
       FROM orders
       WHERE id = $1 AND driver_id = $2 AND status = 'in_progress'
       FOR UPDATE`,
      [req.params.orderId, driverId],
    );
    if (currentResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Order cannot be completed' });
    }
    const currentOrder = currentResult.rows[0];

    const pendingStops = await client.query(
      `SELECT sequence FROM order_stops
       WHERE order_id = $1 AND reached_at IS NULL
       ORDER BY sequence`,
      [currentOrder.id],
    );
    if (pendingStops.rows.length > 1) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Intermediate stops are not completed' });
    }

    const linkedQueuedResult = await client.query(
      `SELECT next_order.id, next_order.driver_id, next_order.status,
              next_order.service_type, next_order.agreed_price,
              next_order.queued_after_order_id,
              COALESCE(passenger.firebase_uid, passenger.id::text) AS passenger_uid
       FROM orders next_order
       JOIN users passenger ON passenger.id = next_order.passenger_id
       WHERE next_order.queued_after_order_id = $1
       ORDER BY next_order.created_at
       LIMIT 2
       FOR UPDATE OF next_order`,
      [currentOrder.id],
    );
    if (linkedQueuedResult.rows.length > 1) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Linked queued order is invalid' });
    }
    const linkedQueued = linkedQueuedResult.rows[0] ?? null;
    if (
      linkedQueued !== null
      && (
        currentOrder.service_type !== 'city'
        || linkedQueued.status !== 'queued'
        || linkedQueued.driver_id !== driverId
        || linkedQueued.queued_after_order_id !== currentOrder.id
        || linkedQueued.service_type !== 'city'
        || linkedQueued.agreed_price == null
      )
    ) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Linked queued order is invalid' });
    }

    const completedResult = await client.query(
      `
      UPDATE orders
      SET
        status = 'completed',
        completed_at = now(),
        updated_at = now()
      WHERE
        id = $1
        AND driver_id = $2
        AND status = 'in_progress'
      RETURNING
        id, status, completed_at, agreed_price
      `,
      [currentOrder.id, driverId],
    );
    if (completedResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Order cannot be completed' });
    }

    let activatedNext = null;
    if (linkedQueued !== null) {
      const activatedResult = await client.query(
        `UPDATE orders
         SET status = 'accepted', accepted_at = now(),
             queued_after_order_id = NULL, updated_at = now()
         WHERE id = $1 AND driver_id = $2 AND status = 'queued'
           AND queued_after_order_id = $3 AND service_type = 'city'
           AND agreed_price IS NOT NULL
         RETURNING id, driver_id, agreed_price, accepted_at`,
        [linkedQueued.id, driverId, currentOrder.id],
      );
      if (activatedResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Linked queued order is invalid' });
      }
      activatedNext = {
        ...activatedResult.rows[0],
        passenger_uid: linkedQueued.passenger_uid,
      };
    }

    await client.query('COMMIT');
    const completedOrder = completedResult.rows[0];
    await pushOrderEvent(currentOrder.id, 'passenger', 'completed');

	await notifyOrderParticipants(currentOrder.id, {
      type: 'order_status_changed',
      orderId: currentOrder.id,
      status: 'completed',
      completedAt: completedOrder.completed_at,
      agreedPrice: completedOrder.agreed_price,
    });

    if (activatedNext !== null) {
      await notifyOrderParticipants(activatedNext.id, {
        type: 'order_status_changed',
        orderId: activatedNext.id,
        status: 'accepted',
        acceptedAt: activatedNext.accepted_at,
        agreedPrice: activatedNext.agreed_price,
      });
      if (activatedNext.passenger_uid) {
        try {
          await sendPushToUser(activatedNext.passenger_uid, {
            title: 'Водитель направляется к вам',
            body:
              'Предыдущая поездка завершена — водитель уже едет к месту подачи.',
            data: {
              type: 'driver_heading_to_pickup',
              orderId: activatedNext.id,
            },
          });
        } catch (pushError) {
          console.error('[NextOrderActivatedPush]', pushError);
        }
      }
    }

    res.json({
      id: completedOrder.id,
      status: completedOrder.status,
      agreedPrice: completedOrder.agreed_price,
      completedAt: completedOrder.completed_at,
      nextOrderActivated: activatedNext !== null,
      nextOrderId: activatedNext?.id ?? null,
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[OrderComplete]', error);

    res.status(500).json({
      error: 'Failed to complete order',
    });
  } finally {
    client.release();
  }
});

  // Поставить рейтинг второму участнику завершённой поездки
// Public fields only; authorization is through the caller's own assigned order.
router.get('/:orderId/driver-profile', requireAuth, async (req, res) => {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(req.params.orderId)) {
    return res.status(400).json({ error: 'Invalid order id' });
  }
  try {
    const assigned = await pool.query(`
      SELECT o.driver_id, driver.name, dp.car_model, dp.car_color, dp.car_number
      FROM orders o
      JOIN users caller ON (caller.firebase_uid = $2 OR caller.id::text = $2)
      JOIN users driver ON driver.id = o.driver_id
      LEFT JOIN driver_profiles dp ON dp.user_id = o.driver_id
      WHERE o.id = $1 AND o.passenger_id = caller.id
        AND o.driver_id <> caller.id
        AND o.status IN ('accepted', 'driver_arrived', 'in_progress', 'completed', 'queued')
    `, [req.params.orderId, req.user.uid]);
    const driver = assigned.rows[0];
    if (!driver) return res.status(404).json({ error: 'Driver profile not available' });

    // Do not reuse users.rating: that legacy aggregate includes both roles.
    const aggregate = await pool.query(`
      SELECT ROUND(AVG(r.score)::numeric, 2) AS average_rating,
             COUNT(*)::integer AS ratings_count
      FROM ratings r
      JOIN orders rated_order ON rated_order.id = r.order_id
      WHERE r.to_user_id = $1 AND rated_order.driver_id = r.to_user_id
        AND rated_order.passenger_id = r.from_user_id
        AND r.from_user_id <> r.to_user_id AND rated_order.status = 'completed'
    `, [driver.driver_id]);
    const reviews = await pool.query(`
      SELECT r.id, r.score, r.comment, r.created_at
      FROM ratings r
      JOIN orders rated_order ON rated_order.id = r.order_id
      WHERE r.to_user_id = $1 AND rated_order.driver_id = r.to_user_id
        AND rated_order.passenger_id = r.from_user_id
        AND r.from_user_id <> r.to_user_id AND rated_order.status = 'completed'
        AND NULLIF(btrim(r.comment), '') IS NOT NULL
      ORDER BY r.created_at DESC, r.id DESC LIMIT 20
    `, [driver.driver_id]);
    const summary = aggregate.rows[0];
    return res.json({
      driverId: driver.driver_id,
      name: driver.name,
      carModel: driver.car_model,
      carColor: driver.car_color,
      carNumber: driver.car_number,
      averageRating: summary?.average_rating == null ? null : Number(summary.average_rating),
      ratingsCount: Number(summary?.ratings_count ?? 0),
      reviews: reviews.rows.map((r) => ({
        id: r.id, score: Number(r.score), comment: r.comment, createdAt: r.created_at,
      })),
    });
  } catch (error) {
    console.error('[AssignedDriverProfile]', { code: error.code });
    return res.status(500).json({ error: 'Failed to load driver profile' });
  }
});

router.post('/:orderId/rating', requireAuth, requireCurrentTerms, async (req, res) => {
  const client = await pool.connect();

  try {
    const score = req.body?.score;
    const rawComment = req.body?.comment;
    if (rawComment != null && typeof rawComment !== 'string') {
      return res.status(400).json({ error: 'Comment must be text' });
    }
    const comment = rawComment?.trim() || null;
    if (comment && Array.from(comment).length > 500) {
      return res.status(400).json({ error: 'Comment must not exceed 500 characters' });
    }

    if (!Number.isInteger(score) || score < 1 || score > 5) {
      return res.status(400).json({
        error: 'Rating must be an integer from 1 to 5',
      });
    }

    await client.query('BEGIN');

    // Определяем текущего пользователя
    const currentUserResult = await client.query(
      `
      SELECT id
      FROM users
      WHERE (firebase_uid = $1 OR id::text = $1)
      `,
      [req.user.uid],
    );

    if (currentUserResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        error: 'User profile not found',
      });
    }

    const currentUserId = currentUserResult.rows[0].id;

    // Блокируем завершённый заказ
    const orderResult = await client.query(
      `
      SELECT
        id,
        passenger_id,
        driver_id,
        status
      FROM orders
      WHERE id = $1
      FOR UPDATE
      `,
      [req.params.orderId],
    );

    if (orderResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        error: 'Order not found',
      });
    }

    const order = orderResult.rows[0];

    if (order.status !== 'completed') {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Only completed orders can be rated',
      });
    }

    if (!order.driver_id) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Completed order has no driver',
      });
    }

    let targetUserId;

    if (currentUserId === order.passenger_id) {
      targetUserId = order.driver_id;
    } else if (currentUserId === order.driver_id) {
      targetUserId = order.passenger_id;
    } else {
      await client.query('ROLLBACK');

      return res.status(403).json({
        error: 'User did not participate in this order',
      });
    }

    if (targetUserId === currentUserId) {
      await client.query('ROLLBACK');

      return res.status(400).json({
        error: 'User cannot rate themselves',
      });
    }

    if (comment && currentUserId !== order.passenger_id) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Only the passenger can leave a driver review' });
    }

    // Создаём оценку. UNIQUE в БД не даст оценить повторно.
    try {
      await client.query(
        `
        INSERT INTO ratings (
          order_id,
          from_user_id,
          to_user_id,
          score,
          comment
        )
        VALUES ($1, $2, $3, $4, $5)
        `,
        [
          order.id,
          currentUserId,
          targetUserId,
          score,
          comment,
        ],
      );
    } catch (error) {
      if (error.code === '23505') {
        await client.query('ROLLBACK');

        return res.status(409).json({
          error: 'Rating for this order has already been submitted',
        });
      }

      throw error;
    }

    // Обновляем агрегированный рейтинг получателя
    const ratingResult = await client.query(
      `
      UPDATE users
      SET
        rating_sum = rating_sum + $1,
        rating_count = rating_count + 1,
        rating = ROUND(
          (rating_sum + $1)::numeric /
          (rating_count + 1),
          2
        ),
        updated_at = now()
      WHERE id = $2
      RETURNING
        id,
        rating,
        rating_sum,
        rating_count
      `,
      [score, targetUserId],
    );

    if (ratingResult.rows.length === 0) {
      throw new Error('Rating target user not found');
    }

    await client.query('COMMIT');

    const rating = ratingResult.rows[0];

    res.status(201).json({
      orderId: order.id,
      score,
      targetUserId,
      targetRating: Number(rating.rating),
      targetRatingSum: rating.rating_sum,
      targetRatingCount: rating.rating_count,
    });
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      // transaction may already be rolled back
    }

    console.error('[OrderRating]', error);

    res.status(500).json({
      error: 'Failed to submit rating',
    });
  } finally {
    client.release();
  }
});

router.get('/active/me', requireAuth, async (req, res) => {
  try {
    await expireStaleSearchingOrders(pool);

    const result = await pool.query(
      `
      SELECT
        o.id,
        o.passenger_id,
        o.driver_id,
        o.service_type,
        o.status,
        o.passenger_price,
        o.agreed_price,
        o.pickup_address,
        o.destination_address,
        o.pickup_lat,
        o.pickup_lng,
        o.destination_lat,
        o.destination_lng,
        o.distance_meters,
        o.created_at,
        o.accepted_at,
        o.driver_arrived_at,
        o.started_at,
        o.completed_at,
        COALESCE(
          (SELECT jsonb_agg(jsonb_build_object('sequence', s.sequence, 'type', s.type, 'address', s.address, 'latitude', s.latitude, 'longitude', s.longitude, 'reachedAt', s.reached_at) ORDER BY s.sequence)
           FROM order_stops s WHERE s.order_id = o.id),
          jsonb_build_array(jsonb_build_object('sequence', 0, 'type', 'destination', 'address', o.destination_address, 'latitude', o.destination_lat, 'longitude', o.destination_lng))
        ) AS stops,
        u.id AS current_user_id,
        o.driver_lat,
	o.driver_lng,
	o.driver_location_updated_at,
        assigned_driver.name AS driver_name,
        dp.car_model,
        dp.car_color,
        dp.car_number
      FROM users u
      JOIN orders o
        ON (
          o.passenger_id = u.id
          OR o.driver_id = u.id
        )
      LEFT JOIN users assigned_driver
        ON assigned_driver.id = o.driver_id
      LEFT JOIN driver_profiles dp
        ON dp.user_id = o.driver_id
      WHERE
        (u.firebase_uid = $1 OR u.id::text = $1)
        AND (
          (
            o.passenger_id = u.id
            AND o.status IN (
              'searching',
              'queued',
              'accepted',
              'driver_arrived',
              'in_progress'
            )
          )
          OR (
            o.driver_id = u.id
            AND o.status IN (
              'accepted',
              'driver_arrived',
              'in_progress'
            )
          )
        )
      ORDER BY o.created_at DESC
      LIMIT 1
      `,
      [req.user.uid],
    );

    if (result.rows.length === 0) {
      return res.status(200).json({
        activeOrder: null,
      });
    }

    const order = result.rows[0];

    const role =
      order.current_user_id === order.passenger_id
        ? 'passenger'
        : 'driver';

    res.json({
      activeOrder: {
        id: order.id,
        role,
        serviceType: order.service_type,
        status: order.status,
        driverId: order.driver_id,
        driverName: order.driver_name,
        carModel: order.car_model,
        carColor: order.car_color,
        carNumber: order.car_number,
        passengerPrice: order.passenger_price,
        agreedPrice: order.agreed_price,
        pickupAddress: order.pickup_address,
        destinationAddress: order.destination_address,
        pickupLat: order.pickup_lat,
        pickupLng: order.pickup_lng,
        destinationLat: order.destination_lat,
        destinationLng: order.destination_lng,
        distanceMeters: order.distance_meters,
        createdAt: order.created_at,
        acceptedAt: order.accepted_at,
        driverArrivedAt: order.driver_arrived_at,
        startedAt: order.started_at,
        completedAt: order.completed_at,
        stops: order.stops,
	driverLat: order.driver_lat,
	driverLng: order.driver_lng,
	driverLocationUpdatedAt: order.driver_location_updated_at,
      },
    });
  } catch (error) {
    console.error('[ActiveOrder]', error);

    res.status(500).json({
      error: 'Failed to load active order',
    });
  }
});

router.post('/:orderId/cancel', requireAuth, async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const userResult = await client.query(
      `
      SELECT id
      FROM users
      WHERE (firebase_uid = $1 OR id::text = $1)
      `,
      [req.user.uid],
    );

    if (userResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        error: 'User profile not found',
      });
    }

    const userId = userResult.rows[0].id;

    const orderResult = await client.query(
      `
      SELECT
        id,
        passenger_id,
        driver_id,
        status,
        service_type,
        queued_after_order_id
      FROM orders
      WHERE id = $1
      FOR UPDATE
      `,
      [req.params.orderId],
    );

    if (orderResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        error: 'Order not found',
      });
    }

    const order = orderResult.rows[0];

    const isPassenger = order.passenger_id === userId;
    const isDriver = order.driver_id === userId;

    if (!isPassenger && !isDriver) {
      await client.query('ROLLBACK');

      return res.status(403).json({
        error: 'User did not participate in this order',
      });
    }

    if (order.service_type === 'city' && order.status === 'cancelled') {
      await client.query('COMMIT');
      return res.json({ id: order.id, status: 'cancelled', alreadyCancelled: true });
    }

    const cityOrder = order.service_type === 'city';
    const cancellationRole = isPassenger ? 'passenger' : 'driver';
    if (cityOrder && !canCancelCityOrder(order.status, cancellationRole)) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Order cannot be cancelled now' });
    }
    const reason = cityOrder
      ? validateCityCancellationReason({
        status: order.status,
        role: cancellationRole,
        reasonCode: req.body?.reasonCode,
        reasonText: req.body?.reasonText,
      })
      : { ok: true, reasonCode: null, reasonText: null };
    if (!reason.ok) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: reason.error });
    }

    // Non-city orders keep their existing cancellation policy.
    if (
      !cityOrder && isPassenger &&
      !['searching', 'queued', 'accepted', 'driver_arrived'].includes(order.status)
    ) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Passenger cannot cancel this order now',
      });
    }

    if (
      !cityOrder && isDriver &&
      !['accepted', 'driver_arrived'].includes(order.status)
    ) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Driver cannot cancel this order now',
      });
    }

    const result = await client.query(
      `
      UPDATE orders
      SET
        status = 'cancelled',
        cancelled_at = now(),
        cancelled_by_user_id = $2,
        cancelled_by_role = $3,
        cancellation_reason_code = $4,
        cancellation_reason_text = $5,
        queued_after_order_id = NULL,
        updated_at = now()
      WHERE id = $1
      RETURNING
        id,
        status,
        cancelled_at
      `,
      [order.id, userId, cancellationRole, reason.reasonCode, reason.reasonText],
    );

    await client.query(
      `
      UPDATE order_offers
      SET
        status = CASE
          WHEN status = 'pending' THEN 'rejected'
          ELSE status
        END,
        updated_at = now()
      WHERE order_id = $1
      `,
      [order.id],
    );

    await client.query('COMMIT');

	await notifyOrderParticipants(order.id, {
  type: 'order_cancelled',
  orderId: order.id,
  status: 'cancelled',
  cancelledAt: result.rows[0].cancelled_at,
  cancelledBy:
    isPassenger ? 'passenger' : 'driver',
});
    await pushOrderEvent(order.id, isPassenger ? 'driver' : 'passenger', 'cancelled',
      cityOrder ? { cancelledBy: cancellationRole } : {});

    res.json({
      id: result.rows[0].id,
      status: result.rows[0].status,
      cancelledAt: result.rows[0].cancelled_at,
    });
  } catch (error) {
    await client.query('ROLLBACK');

    console.error('[OrderCancel]', error);

    res.status(500).json({
      error: 'Failed to cancel order',
    });
  } finally {
    client.release();
  }
});

async function notifyOrderParticipants(orderId, payload) {
  try {
    const result = await pool.query(
      `
      SELECT
        COALESCE(passenger.firebase_uid, passenger.id::text) AS passenger_uid,
        COALESCE(driver.firebase_uid, driver.id::text) AS driver_uid
      FROM orders o
      JOIN users passenger
        ON passenger.id = o.passenger_id
      LEFT JOIN users driver
        ON driver.id = o.driver_id
      WHERE o.id = $1
      `,
      [orderId],
    );

    if (result.rows.length === 0) {
      return;
    }

    const row = result.rows[0];

    if (row.passenger_uid) {
      sendToUser(row.passenger_uid, payload);
    }

    if (row.driver_uid) {
      sendToUser(row.driver_uid, payload);
    }
  } catch (error) {
    console.error('[OrderRealtimeNotify]', error);
  }
}

router.post('/:orderId/location', requireAuth, async (req, res) => {
  try {
    const lat = req.body?.lat;
    const lng = req.body?.lng;

    if (
      typeof lat !== 'number' ||
      typeof lng !== 'number' ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180
    ) {
      return res.status(400).json({
        error: 'Invalid coordinates',
      });
    }

    const claimId = randomUUID();
    const result = await pool.query(
      `
      WITH eligible AS (
        SELECT
          o.id,
          COALESCE(passenger.firebase_uid, passenger.id::text) AS passenger_uid,
          o.driver_approaching_notified_at IS NOT NULL AS was_already_notified,
          6371000 * 2 * asin(
            sqrt(
              power(sin(radians($1 - o.pickup_lat) / 2), 2)
              + cos(radians(o.pickup_lat)) * cos(radians($1))
              * power(sin(radians($2 - o.pickup_lng) / 2), 2)
            )
          ) AS distance_to_pickup_meters,
          (
            o.status = 'accepted'
            AND o.driver_approaching_notified_at IS NULL
            AND (o.driver_approaching_claim_id IS NULL
              OR o.driver_approaching_claimed_at < now() - interval '5 minutes')
            AND 6371000 * 2 * asin(
              sqrt(
                power(sin(radians($1 - o.pickup_lat) / 2), 2)
                + cos(radians(o.pickup_lat)) * cos(radians($1))
                * power(sin(radians($2 - o.pickup_lng) / 2), 2)
              )
            ) <= 200
          ) AS should_notify_approaching
        FROM orders o
        JOIN users driver ON driver.id = o.driver_id
        JOIN users passenger ON passenger.id = o.passenger_id
        WHERE
          o.id = $3
          AND (driver.firebase_uid = $4 OR driver.id::text = $4)
          AND o.status IN (
            'accepted',
            'driver_arrived',
            'in_progress'
          )
        FOR UPDATE OF o
      )
      UPDATE orders o
      SET
        driver_lat = $1,
        driver_lng = $2,
        driver_location_updated_at = now(),
        driver_approaching_claim_id = CASE
          WHEN eligible.should_notify_approaching THEN $5::uuid
          ELSE o.driver_approaching_claim_id
        END,
        driver_approaching_claimed_at = CASE
          WHEN eligible.should_notify_approaching THEN now()
          ELSE o.driver_approaching_claimed_at
        END,
        updated_at = now()
      FROM eligible
      WHERE
        o.id = eligible.id
      RETURNING
        o.id,
        o.driver_lat,
        o.driver_lng,
        o.driver_location_updated_at,
        eligible.passenger_uid,
        eligible.should_notify_approaching,
        eligible.distance_to_pickup_meters,
        eligible.was_already_notified
      `,
      [
        lat,
        lng,
        req.params.orderId,
        req.user.uid,
        claimId,
      ],
    );

    if (result.rows.length === 0) {
      return res.status(403).json({
        error: 'Driver cannot update location for this order',
      });
    }

    const location = result.rows[0];

    await notifyOrderParticipants(req.params.orderId, {
      type: 'driver_location',
      orderId: req.params.orderId,
      lat: location.driver_lat,
      lng: location.driver_lng,
      updatedAt: location.driver_location_updated_at,
    });

    const distanceMeters = Number(location.distance_to_pickup_meters);
    const releaseClaim = () => pool.query(
      `UPDATE orders
       SET driver_approaching_claim_id = NULL,
           driver_approaching_claimed_at = NULL
       WHERE id = $1 AND driver_approaching_claim_id = $2::uuid`,
      [req.params.orderId, claimId],
    );
    let approachingResult = 'skipped_outside_threshold_or_already_notified';
    if (location.should_notify_approaching && location.passenger_uid) {
      try {
        const pushResult = await sendPushToUser(location.passenger_uid, {
          data: {
            type: 'driver_approaching_pickup',
            orderId: req.params.orderId,
          },
        });
        if (Number(pushResult?.successCount) > 0) {
          await pool.query(
            `UPDATE orders
             SET driver_approaching_notified_at = now(),
                 driver_approaching_claim_id = NULL,
                 driver_approaching_claimed_at = NULL
             WHERE id = $1 AND driver_approaching_claim_id = $2::uuid`,
            [req.params.orderId, claimId],
          );
          approachingResult = 'notification_sent';
        } else {
          approachingResult = 'notification_not_delivered_retry_enabled';
          await releaseClaim();
        }
      } catch (pushError) {
        approachingResult = 'notification_error_retry_enabled';
        await releaseClaim();
        console.error('[DriverApproachingPush]', pushError);
      }
    } else if (!location.passenger_uid) {
      if (location.should_notify_approaching) await releaseClaim();
      approachingResult = 'skipped_missing_passenger';
    }

    console.log(
      `[DriverApproaching] orderId=${req.params.orderId} `
      + `distanceMeters=${Number.isFinite(distanceMeters) ? Math.round(distanceMeters) : 'unknown'} `
      + 'threshold=200 '
      + `alreadyNotified=${location.was_already_notified} `
      + `result=${approachingResult}`,
    );

    res.json({
      orderId: location.id,
      lat: location.driver_lat,
      lng: location.driver_lng,
      updatedAt: location.driver_location_updated_at,
    });
  } catch (error) {
    console.error('[DriverLocation]', error);

    res.status(500).json({
      error: 'Failed to update driver location',
    });
  }
});



// История заказов текущего пользователя.
// Возвращает завершённые/отменённые/истёкшие заказы,
// где пользователь был пассажиром или водителем.
router.get('/history', requireAuth, async (req, res) => {
  try {
    await expireStaleSearchingOrders(pool);

    const result = await pool.query(
      `
      SELECT
        o.id,
        o.passenger_id,
        o.driver_id,
        o.service_type,
        o.status,
        o.passenger_price,
        o.agreed_price,
        o.pickup_address,
        o.destination_address,
        o.distance_meters,
        o.created_at,
        o.completed_at,
        o.cancelled_at,

        COALESCE(passenger.firebase_uid, passenger.id::text) AS passenger_uid,
        COALESCE(driver.firebase_uid, driver.id::text) AS driver_uid,

        dd.item_description,
        dd.sender_name,
        dd.recipient_name,
        dd.pickup_handoff_type,
        dd.pickup_entrance,
        dd.pickup_apartment,
        dd.pickup_floor,
        dd.pickup_intercom,
        dd.pickup_comment,
        dd.destination_handoff_type,
        dd.destination_entrance,
        dd.destination_apartment,
        dd.destination_floor,
        dd.destination_intercom,
        dd.destination_comment,

        ic.departure_at,
        ic.passenger_count,
        ic.has_luggage,
        ic.comment AS intercity_comment

      FROM orders o

      JOIN users passenger
        ON passenger.id = o.passenger_id

      LEFT JOIN users driver
        ON driver.id = o.driver_id

      LEFT JOIN delivery_details dd
        ON dd.order_id = o.id

      LEFT JOIN intercity_details ic
        ON ic.order_id = o.id

      WHERE
        (
          passenger.firebase_uid = $1 OR passenger.id::text = $1
          OR driver.firebase_uid = $1 OR driver.id::text = $1
        )
        AND o.status IN ('completed', 'cancelled', 'expired')

      ORDER BY o.created_at DESC
      LIMIT 200
      `,
      [req.user.uid],
    );

    res.json({
      orders: result.rows.map((order) => {
        const role =
          order.passenger_uid === req.user.uid
            ? 'passenger'
            : 'driver';

        const delivery =
          order.service_type === 'delivery'
            ? {
                itemDescription: order.item_description,
                senderName: order.sender_name,
                recipientName: order.recipient_name,
                pickupHandoffType: order.pickup_handoff_type,
                pickupEntrance: order.pickup_entrance,
                pickupApartment: order.pickup_apartment,
                pickupFloor: order.pickup_floor,
                pickupIntercom: order.pickup_intercom,
                pickupComment: order.pickup_comment,
                destinationHandoffType:
                  order.destination_handoff_type,
                destinationEntrance:
                  order.destination_entrance,
                destinationApartment:
                  order.destination_apartment,
                destinationFloor:
                  order.destination_floor,
                destinationIntercom:
                  order.destination_intercom,
                destinationComment:
                  order.destination_comment,
              }
            : null;

        const intercity =
          order.service_type === 'intercity'
            ? {
                departureAt: order.departure_at,
                passengerCount: order.passenger_count,
                hasLuggage: order.has_luggage,
                comment: order.intercity_comment,
              }
            : null;

        return {
          id: order.id,
          serviceType: order.service_type,
          status: order.status,
          role,

          pickupAddress: order.pickup_address,
          destinationAddress: order.destination_address,

          passengerPrice: order.passenger_price,
          agreedPrice: order.agreed_price,
          distanceMeters: order.distance_meters,

          delivery,
          intercity,

          createdAt: order.created_at,
          completedAt: order.completed_at,
          cancelledAt: order.cancelled_at,
        };
      }),
    });
  } catch (error) {
    console.error('[OrderHistory]', error);

    res.status(500).json({
      error: 'Failed to load order history',
    });
  }
});

router.get('/:orderId/details', requireAuth, async (req, res) => {
    try {
      const result = await pool.query(
        `
        SELECT
          o.id,
          o.passenger_id,
          o.driver_id,
          o.service_type,
          o.status,
          o.passenger_price,
          o.agreed_price,
          o.pickup_address,
          o.destination_address,
          o.pickup_lat,
          o.pickup_lng,
          o.destination_lat,
          o.destination_lng,
          o.distance_meters,
          o.driver_lat,
          o.driver_lng,
          o.driver_location_updated_at,
          o.created_at,
          o.accepted_at,
          o.driver_arrived_at,
          o.started_at,
          o.completed_at,
          o.cancelled_at,
          COALESCE(
            (SELECT jsonb_agg(jsonb_build_object('sequence', s.sequence, 'type', s.type, 'address', s.address, 'latitude', s.latitude, 'longitude', s.longitude, 'reachedAt', s.reached_at) ORDER BY s.sequence)
             FROM order_stops s WHERE s.order_id = o.id),
            jsonb_build_array(jsonb_build_object('sequence', 0, 'type', 'destination', 'address', o.destination_address, 'latitude', o.destination_lat, 'longitude', o.destination_lng))
          ) AS stops,

          COALESCE(passenger.firebase_uid, passenger.id::text) AS passenger_uid,
          passenger.name AS passenger_name,
          passenger.phone AS passenger_phone,
          passenger.rating AS passenger_rating,

          COALESCE(driver.firebase_uid, driver.id::text) AS driver_uid,
          driver.name AS driver_name,
          driver.phone AS driver_phone,
          driver.rating AS driver_rating,

          dp.car_model,
          dp.car_color,
          dp.car_number,

          dd.item_description,
          dd.sender_name,
          dd.sender_phone,
          dd.recipient_name,
          dd.recipient_phone,
          dd.pickup_handoff_type,
          dd.pickup_entrance,
          dd.pickup_apartment,
          dd.pickup_floor,
          dd.pickup_intercom,
          dd.pickup_comment,
          dd.destination_handoff_type,
          dd.destination_entrance,
          dd.destination_apartment,
          dd.destination_floor,
          dd.destination_intercom,
          dd.destination_comment,

          ic.departure_at,
          ic.passenger_count,
          ic.has_luggage,
          ic.comment AS intercity_comment

        FROM orders o

        JOIN users passenger
          ON passenger.id = o.passenger_id

        LEFT JOIN users driver
          ON driver.id = o.driver_id

        LEFT JOIN driver_profiles dp
          ON dp.user_id = o.driver_id

        LEFT JOIN delivery_details dd
          ON dd.order_id = o.id

        LEFT JOIN intercity_details ic
          ON ic.order_id = o.id

        WHERE o.id = $1
        `,
        [req.params.orderId],
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          error: 'Order not found',
        });
      }

      const order = result.rows[0];

      const isPassenger =
        order.passenger_uid === req.user.uid;

      const isDriver =
        order.driver_uid !== null &&
        order.driver_uid === req.user.uid;

      if (!isPassenger && !isDriver) {
        return res.status(403).json({
          error: 'Access denied',
        });
      }

      const activeDriverContactAccess =
        isDriver &&
        ['accepted', 'driver_arrived', 'in_progress'].includes(order.status);

      const canSeeContacts =
        isPassenger || activeDriverContactAccess;

      const delivery =
        order.service_type === 'delivery'
          ? {
              itemDescription: order.item_description,
              senderName: order.sender_name,
              senderPhone: canSeeContacts ? order.sender_phone : null,
              recipientName: order.recipient_name,
              recipientPhone: canSeeContacts ? order.recipient_phone : null,
              pickupHandoffType: order.pickup_handoff_type,
              pickupEntrance: order.pickup_entrance,
              pickupApartment: order.pickup_apartment,
              pickupFloor: order.pickup_floor,
              pickupIntercom: order.pickup_intercom,
              pickupComment: order.pickup_comment,
              destinationHandoffType: order.destination_handoff_type,
              destinationEntrance: order.destination_entrance,
              destinationApartment: order.destination_apartment,
              destinationFloor: order.destination_floor,
              destinationIntercom: order.destination_intercom,
              destinationComment: order.destination_comment,
            }
          : null;

      const intercity =
        order.service_type === 'intercity'
          ? {
              departureAt: order.departure_at,
              passengerCount: order.passenger_count,
              hasLuggage: order.has_luggage,
              comment: order.intercity_comment,
            }
          : null;

      res.json({
        id: order.id,
        role: isPassenger ? 'passenger' : 'driver',
        serviceType: order.service_type,
        status: order.status,

        passengerPrice: order.passenger_price,
        agreedPrice: order.agreed_price,

        pickupAddress: order.pickup_address,
        destinationAddress: order.destination_address,

        pickupLat: order.pickup_lat,
        pickupLng: order.pickup_lng,
        destinationLat: order.destination_lat,
        destinationLng: order.destination_lng,

        distanceMeters: order.distance_meters,
        stops: order.stops,

          driverLat: order.driver_lat,
          driverLng: order.driver_lng,
          driverLocationUpdatedAt:
            order.driver_location_updated_at,

        passenger: {
          id: order.passenger_id,
          name: order.passenger_name,
          phone: canSeeContacts ? order.passenger_phone : null,
          rating: Number(order.passenger_rating),
        },

        driver: order.driver_id
          ? {
              id: order.driver_id,
              name: order.driver_name,
              phone: isPassenger ? order.driver_phone : null,
              rating: Number(order.driver_rating),
              carModel: order.car_model,
              carColor: order.car_color,
              carNumber: order.car_number,
            }
          : null,

        delivery,
        intercity,

        createdAt: order.created_at,
        acceptedAt: order.accepted_at,
        driverArrivedAt: order.driver_arrived_at,
        startedAt: order.started_at,
        completedAt: order.completed_at,
        cancelledAt: order.cancelled_at,
      });
    } catch (error) {
      console.error('[OrderDetails]', error);

      res.status(500).json({
        error: 'Failed to load order details',
      });
    }
  });


  // Активный заказ текущего водителя.
  router.get('/active/driver', requireAuth, async (req, res) => {
    try {
      const result = await pool.query(
        `
        SELECT
          o.id,
          o.service_type,
          o.status,
          o.passenger_price,
          o.agreed_price,
          o.pickup_address,
          o.destination_address,
          o.pickup_lat,
          o.pickup_lng,
          o.destination_lat,
          o.destination_lng,
          o.distance_meters,
          o.created_at,
          o.accepted_at,
          o.driver_arrived_at,
          o.started_at,
          o.completed_at,
          COALESCE(
            (SELECT jsonb_agg(jsonb_build_object('sequence', s.sequence, 'type', s.type, 'address', s.address, 'latitude', s.latitude, 'longitude', s.longitude, 'reachedAt', s.reached_at) ORDER BY s.sequence)
             FROM order_stops s WHERE s.order_id = o.id),
            jsonb_build_array(jsonb_build_object('sequence', 0, 'type', 'destination', 'address', o.destination_address, 'latitude', o.destination_lat, 'longitude', o.destination_lng))
          ) AS stops,

          passenger.id AS passenger_id,
          passenger.name AS passenger_name,
          passenger.phone AS passenger_phone,
          passenger.rating AS passenger_rating

        FROM orders o

        JOIN users driver
          ON driver.id = o.driver_id

        JOIN users passenger
          ON passenger.id = o.passenger_id

        WHERE
          (driver.firebase_uid = $1 OR driver.id::text = $1)
          AND o.status IN (
            'accepted',
            'driver_arrived',
            'in_progress'
          )

        ORDER BY o.updated_at DESC
        LIMIT 1
        `,
        [req.user.uid],
      );

      if (result.rows.length === 0) {
        return res.json({
          activeOrder: null,
        });
      }

      const order = result.rows[0];

      const legacyStatus =
        order.status === 'driver_arrived'
          ? 'arrived'
          : order.status;

      res.json({
        activeOrder: {
          id: order.id,
          serviceType: order.service_type,
          status: legacyStatus,

          price:
            order.agreed_price ??
            order.passenger_price,

          passengerPrice:
            order.passenger_price,

          agreedPrice:
            order.agreed_price,

          fromAddress:
            order.pickup_address,

          toAddress:
            order.destination_address,

          fromLat:
            order.pickup_lat,

          fromLng:
            order.pickup_lng,

          toLat:
            order.destination_lat,

          toLng:
            order.destination_lng,

          distanceMeters:
            order.distance_meters,

          stops: order.stops,

          passengerId:
            order.passenger_id,

          passengerName:
            order.passenger_name,

          passengerPhone:
            order.passenger_phone,

          passengerRating:
            Number(order.passenger_rating),

          createdAt:
            order.created_at,

          acceptedAt:
            order.accepted_at,

          arrivedAt:
            order.driver_arrived_at,

          startedAt:
            order.started_at,

          completedAt:
            order.completed_at,
        },
      });
    } catch (error) {
      console.error('[ActiveDriverOrder]', error);

      res.status(500).json({
        error: 'Failed to load active driver order',
      });
    }
  });

return router;
}
