import express from 'express';
import {
  acquireAccountLifecycleLock,
  loadAccountLifecycleState,
} from '../account-lifecycle.js';
import { loadIntercityDriverAccess } from '../driver-access.js';
import {
  isUuid,
  validateIntercityRideBooking,
  validateIntercityRideCreate,
  validateIntercityRidePatch,
  validateIntercityRideRequestCreate,
  validateIntercityRideSearch,
} from '../intercity-ride-policy.js';
import { areUsersBlocked } from '../block-policy.js';

const selectRide = `SELECT r.*, u.name AS driver_name, dp.car_model,
    dp.car_color
  FROM intercity_rides r
  JOIN users u ON u.id = r.driver_id
  JOIN driver_profiles dp ON dp.user_id = r.driver_id`;

const selectBooking = `SELECT
    b.id AS booking_id,
    b.ride_id,
    b.seats,
    b.price_per_seat AS booking_price_per_seat,
    b.total_price,
    b.status AS booking_status,
    b.client_request_id,
    b.pickup_address,
    b.pickup_lat,
    b.pickup_lng,
    b.passenger_comment,
    b.pickup_reached_at,
    b.cancelled_at AS booking_cancelled_at,
    b.completed_at AS booking_completed_at,
    b.created_at AS booking_created_at,
    b.updated_at AS booking_updated_at,
    r.origin_city,
    r.origin_lat,
    r.origin_lng,
    r.destination_city,
    r.destination_lat,
    r.destination_lng,
    r.departure_at,
    r.status AS ride_status,
    du.name AS driver_name,
    du.phone AS driver_phone,
    dp.car_model,
    dp.car_color,
    dp.car_number,
    pu.name AS passenger_name,
    pu.phone AS passenger_phone
  FROM intercity_ride_bookings b
  JOIN intercity_rides r ON r.id = b.ride_id
  JOIN users du ON du.id = r.driver_id
  JOIN driver_profiles dp ON dp.user_id = r.driver_id
  JOIN users pu ON pu.id = b.passenger_id`;

const selectRideRequest = `SELECT q.*,
    COALESCE(
      array_agg(n.ride_id ORDER BY n.created_at, n.ride_id)
        FILTER (WHERE n.ride_id IS NOT NULL),
      ARRAY[]::uuid[]
    ) AS matched_ride_ids
  FROM intercity_ride_requests q
  LEFT JOIN intercity_ride_request_notifications n ON n.request_id = q.id`;

function publicRide(row) {
  return {
    rideId: row.id,
    originCity: row.origin_city,
    originLat: row.origin_lat == null ? null : Number(row.origin_lat),
    originLng: row.origin_lng == null ? null : Number(row.origin_lng),
    destinationCity: row.destination_city,
    destinationLat:
      row.destination_lat == null ? null : Number(row.destination_lat),
    destinationLng:
      row.destination_lng == null ? null : Number(row.destination_lng),
    departureAt: row.departure_at,
    totalSeats: row.total_seats,
    availableSeats: row.available_seats,
    pricePerSeat: row.price_per_seat,
    allowsLuggage: row.allows_luggage,
    comment: row.comment,
    status: row.status,
    driver: {
      name: row.driver_name ?? null,
      carModel: row.car_model ?? null,
      carColor: row.car_color ?? null,
    },
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function publicBooking(row, { viewer }) {
  const confirmed = row.booking_status === 'confirmed';
  const completedRecently = row.booking_status === 'completed'
    && row.booking_completed_at
    && Date.now() - new Date(row.booking_completed_at).getTime() <= 24 * 60 * 60 * 1000;
  const contactAllowed = confirmed || completedRecently;
  const result = {
    bookingId: row.booking_id,
    rideId: row.ride_id,
    seats: row.seats,
    pricePerSeat: row.booking_price_per_seat,
    totalPrice: row.total_price,
    status: row.booking_status,
    route: {
      originCity: row.origin_city,
      originLat: row.origin_lat == null ? null : Number(row.origin_lat),
      originLng: row.origin_lng == null ? null : Number(row.origin_lng),
      destinationCity: row.destination_city,
      destinationLat:
        row.destination_lat == null ? null : Number(row.destination_lat),
      destinationLng:
        row.destination_lng == null ? null : Number(row.destination_lng),
    },
    departureAt: row.departure_at,
    rideStatus: row.ride_status,
    createdAt: row.booking_created_at,
    updatedAt: row.booking_updated_at,
    pickupAddress: row.pickup_address ?? null,
    pickupLat: row.pickup_lat == null ? null : Number(row.pickup_lat),
    pickupLng: row.pickup_lng == null ? null : Number(row.pickup_lng),
    passengerComment: row.passenger_comment ?? null,
    pickupReachedAt: row.pickup_reached_at ?? null,
    chatAvailable: contactAllowed,
  };

  if (viewer === 'passenger') {
    result.driver = {
      name: row.driver_name ?? null,
      carModel: row.car_model ?? null,
      carColor: row.car_color ?? null,
    };
    if (contactAllowed) {
      result.driver.carNumber = row.car_number ?? null;
      if (row.driver_phone) result.driver.phone = row.driver_phone;
    }
  } else {
    result.passenger = { name: row.passenger_name ?? null };
    if (contactAllowed && row.passenger_phone) {
      result.passenger.phone = row.passenger_phone;
    }
  }

  return result;
}

function publicRideRequest(row) {
  const travelDate = row.travel_date instanceof Date
    ? row.travel_date.toISOString().slice(0, 10)
    : row.travel_date;
  return {
    requestId: row.id,
    originCity: row.origin_city,
    destinationCity: row.destination_city,
    travelDate,
    seats: row.seats,
    status: row.status,
    matchedRideIds: row.matched_ride_ids ?? [],
    pickupAddress: row.pickup_address ?? null,
    pickupLat: row.pickup_lat == null ? null : Number(row.pickup_lat),
    pickupLng: row.pickup_lng == null ? null : Number(row.pickup_lng),
    passengerComment: row.passenger_comment ?? null,
    cancelledAt: row.cancelled_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function error(res, status, message) {
  return res.status(status).json({ error: message });
}

function lifecycleError(res, lifecycle, fallbackMessage) {
  const deleted = lifecycle.kind === 'deleted';
  return res.status(deleted ? 410 : 403).json({
    code: deleted ? 'account_deleted' : 'account_unavailable',
    error: deleted ? 'Account has been deleted' : fallbackMessage,
  });
}

async function rollbackQuietly(client) {
  try {
    await client.query('ROLLBACK');
  } catch (_) {
    // Preserve the original database error.
  }
}

async function sendIntercityPush(sendPushToUser, firebaseUid, payload) {
  if (!firebaseUid) return;
  try {
    await sendPushToUser(firebaseUid, payload);
  } catch (pushError) {
    console.error(
      '[IntercityRidePush]',
      payload.data.type,
      pushError?.code ?? 'failed',
    );
  }
}

async function sendIntercityPushes(sendPushToUser, events) {
  await Promise.all(
    events.map((event) =>
      sendIntercityPush(sendPushToUser, event.firebaseUid, event.payload)),
  );
}

function seatsLabel(seats) {
  if (seats === 1) return 'место';
  if (seats >= 2 && seats <= 4) return 'места';
  return 'мест';
}

async function loadAuthenticatedUser(queryable, firebaseUid) {
  const result = await queryable.query(
    `SELECT id, name, phone FROM users
      WHERE (firebase_uid = $1 OR id::text = $1)
        AND account_status = 'active' LIMIT 1`,
    [firebaseUid],
  );
  return result.rows[0] ?? null;
}

function kazakhstanDate(value) {
  return new Date(new Date(value).getTime() + 5 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}

async function lockMatchingRoute(
  queryable,
  originCityKey,
  destinationCityKey,
  travelDate,
) {
  await queryable.query(
    `SELECT pg_advisory_xact_lock(141500, hashtext($1))`,
    [JSON.stringify([originCityKey, destinationCityKey, travelDate])],
  );
}

async function matchRidesForRequest(queryable, rideRequest) {
  const result = await queryable.query(
    `INSERT INTO intercity_ride_request_notifications (request_id, ride_id)
     SELECT $1, r.id
     FROM intercity_rides r
     WHERE r.status = 'scheduled'
       AND r.departure_at > now()
       AND r.origin_city_key = $2
       AND r.destination_city_key = $3
       AND (r.departure_at AT TIME ZONE 'Asia/Almaty')::date = $4::date
       AND r.available_seats >= $5
       AND NOT EXISTS (
         SELECT 1 FROM user_blocks ub
         WHERE (ub.blocker_user_id = $6 AND ub.blocked_user_id = r.driver_id)
            OR (ub.blocker_user_id = r.driver_id AND ub.blocked_user_id = $6)
       )
     ON CONFLICT (request_id, ride_id) DO NOTHING
     RETURNING ride_id`,
    [
      rideRequest.id,
      rideRequest.origin_city_key,
      rideRequest.destination_city_key,
      rideRequest.travel_date,
      rideRequest.seats,
      rideRequest.passenger_id,
    ],
  );
  return result.rows.map((row) => row.ride_id);
}

async function matchRequestsForRide(queryable, ride) {
  const result = await queryable.query(
    `INSERT INTO intercity_ride_request_notifications (request_id, ride_id)
     SELECT q.id, $1
     FROM intercity_ride_requests q
     WHERE q.status = 'active'
       AND q.origin_city_key = $2
       AND q.destination_city_key = $3
       AND q.travel_date =
         ($4::timestamptz AT TIME ZONE 'Asia/Almaty')::date
       AND q.seats <= $5
       AND $4::timestamptz > now()
       AND NOT EXISTS (
         SELECT 1 FROM user_blocks ub
         WHERE (ub.blocker_user_id = q.passenger_id AND ub.blocked_user_id = $6)
            OR (ub.blocker_user_id = $6 AND ub.blocked_user_id = q.passenger_id)
       )
     ON CONFLICT (request_id, ride_id) DO NOTHING
     RETURNING request_id`,
    [
      ride.id,
      ride.origin_city_key,
      ride.destination_city_key,
      ride.departure_at,
      ride.available_seats,
      ride.driver_id,
    ],
  );
  const requestIds = result.rows.map((row) => row.request_id);
  if (requestIds.length === 0) return [];
  const recipients = await queryable.query(
    `SELECT q.id AS request_id,
            COALESCE(u.firebase_uid, u.id::text) AS firebase_uid
     FROM intercity_ride_requests q
     JOIN users u ON u.id = q.passenger_id
     WHERE q.id = ANY($1::uuid[])`,
    [requestIds],
  );
  return recipients.rows.map((row) => ({
    requestId: row.request_id,
    firebaseUid: row.firebase_uid,
  }));
}

async function loadRideRequestWithMatches(queryable, requestId) {
  const result = await queryable.query(
    `${selectRideRequest}
     WHERE q.id = $1
     GROUP BY q.id`,
    [requestId],
  );
  return result.rows[0] ?? null;
}

async function loadBookingByRequest(
  queryable,
  passengerId,
  clientRequestId,
  { forUpdate = false } = {},
) {
  const result = await queryable.query(
    `${selectBooking}
      WHERE b.passenger_id = $1 AND b.client_request_id = $2
      ${forUpdate ? 'FOR UPDATE OF b' : ''}`,
    [passengerId, clientRequestId],
  );
  return result.rows[0] ?? null;
}

function isCompatibleReplay(booking, rideId, bookingRequest) {
  return (
    booking.ride_id === rideId
    && booking.seats === bookingRequest.seats
    && booking.booking_status === 'confirmed'
    && (booking.pickup_address ?? null) === bookingRequest.pickupAddress
    && (booking.pickup_lat == null ? null : Number(booking.pickup_lat))
      === bookingRequest.pickupLat
    && (booking.pickup_lng == null ? null : Number(booking.pickup_lng))
      === bookingRequest.pickupLng
    && (booking.passenger_comment ?? null) === bookingRequest.passengerComment
  );
}

export function createIntercityRidesRouter({
  pool,
  requireAuth,
  sendPushToUser = async () => ({ successCount: 0, failureCount: 0 }),
}) {
  const router = express.Router();
  router.use(requireAuth);

  router.post('/', async (req, res) => {
    const checked = validateIntercityRideCreate(req.body);
    if (!checked.ok) return error(res, 400, checked.error);
    let client;
    try {
      client = await pool.connect();
      const v = checked.value;
      await client.query('BEGIN');
      await acquireAccountLifecycleLock(client, req.user.uid);
      const lifecycle = await loadAccountLifecycleState(client, req.user.uid);
      if (lifecycle.kind !== 'active') {
        await client.query('ROLLBACK');
        return lifecycleError(res, lifecycle, 'Active driver access is required');
      }
      const driver = await loadIntercityDriverAccess(client, req.user.uid);
      if (!driver) {
        await client.query('ROLLBACK');
        return error(res, 403, 'Active driver access is required');
      }
      await lockMatchingRoute(
        client,
        v.originCityKey,
        v.destinationCityKey,
        kazakhstanDate(v.departureAt),
      );
      const result = await client.query(
        `INSERT INTO intercity_rides (driver_id, origin_city, origin_city_key,
          origin_lat, origin_lng, destination_city, destination_city_key,
          destination_lat, destination_lng, departure_at, total_seats,
          available_seats, price_per_seat, allows_luggage, comment)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$11,$12,$13,$14)
         RETURNING *`,
        [
          driver.driver_id,
          v.originCity,
          v.originCityKey,
          v.originLat,
          v.originLng,
          v.destinationCity,
          v.destinationCityKey,
          v.destinationLat,
          v.destinationLng,
          v.departureAt,
          v.totalSeats,
          v.pricePerSeat,
          v.allowsLuggage,
          v.comment,
        ],
      );
      const matchedRequests = await matchRequestsForRide(
        client,
        result.rows[0],
      );
      await client.query('COMMIT');
      await sendIntercityPushes(
        sendPushToUser,
        matchedRequests.map((match) => ({
          firebaseUid: match.firebaseUid,
          payload: {
            title: 'MEKEN',
            body: `Появилась попутка ${v.originCity} → ${v.destinationCity}`,
            data: {
              type: 'intercity_ride_match_available',
              rideId: result.rows[0].id,
              requestId: match.requestId,
              originCity: v.originCity,
              destinationCity: v.destinationCity,
            },
          },
        })),
      );
      res.status(201).json({
        ride: publicRide({
          ...result.rows[0],
          driver_name: driver.driver_name,
          car_model: driver.car_model,
          car_color: driver.car_color,
          car_number: driver.car_number,
        }),
        matchedRequestCount: matchedRequests.length,
      });
    } catch (e) {
      if (client) await rollbackQuietly(client);
      console.error('[IntercityRideCreate]', e);
      error(res, 500, 'Failed to create ride');
    } finally {
      client?.release();
    }
  });

  router.get('/search', async (req, res) => {
    const checked = validateIntercityRideSearch(req.query);
    if (!checked.ok) return error(res, 400, checked.error);
    try {
      const v = checked.value;
      const result = await pool.query(
        `${selectRide}
         WHERE r.origin_city_key=$1 AND r.destination_city_key=$2
           AND r.departure_at >= $3 AND r.departure_at < $4
           AND r.departure_at > now() AND r.status='scheduled'
           AND r.available_seats >= $5
           AND NOT EXISTS (
             SELECT 1 FROM users viewer JOIN user_blocks ub
               ON (ub.blocker_user_id = viewer.id AND ub.blocked_user_id = r.driver_id)
               OR (ub.blocker_user_id = r.driver_id AND ub.blocked_user_id = viewer.id)
             WHERE viewer.firebase_uid = $6 OR viewer.id::text = $6
           )
         ORDER BY r.departure_at, r.id`,
        [v.originCityKey, v.destinationCityKey, v.start, v.end, v.seats, req.user.uid],
      );
      res.json({ rides: result.rows.map(publicRide) });
    } catch (e) {
      console.error('[IntercityRideSearch]', e);
      error(res, 500, 'Failed to search rides');
    }
  });

  router.get('/mine', async (req, res) => {
    try {
      const result = await pool.query(
        `${selectRide}
         WHERE (u.firebase_uid=$1 OR u.id::text=$1)
         ORDER BY r.departure_at DESC`,
        [req.user.uid],
      );
      res.json({ rides: result.rows.map(publicRide) });
    } catch (e) {
      console.error('[IntercityRideMine]', e);
      error(res, 500, 'Failed to load rides');
    }
  });

  router.post('/requests', async (req, res) => {
    const checked = validateIntercityRideRequestCreate(req.body);
    if (!checked.ok) return error(res, 400, checked.error);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await acquireAccountLifecycleLock(client, req.user.uid);
      const lifecycle = await loadAccountLifecycleState(client, req.user.uid);
      if (lifecycle.kind !== 'active') {
        await client.query('ROLLBACK');
        return lifecycleError(res, lifecycle, 'Registered user is required');
      }
      const passenger = lifecycle.user;
      const v = checked.value;
      await lockMatchingRoute(
        client,
        v.originCityKey,
        v.destinationCityKey,
        v.travelDate,
      );
      const duplicate = await client.query(
        `SELECT id FROM intercity_ride_requests
         WHERE passenger_id = $1
           AND origin_city_key = $2
           AND destination_city_key = $3
           AND travel_date = $4::date
           AND status = 'active'
         LIMIT 1`,
        [
          passenger.id,
          v.originCityKey,
          v.destinationCityKey,
          v.travelDate,
        ],
      );
      if (duplicate.rows[0]) {
        await client.query('ROLLBACK');
        return error(res, 409, 'An active request already exists');
      }

      const inserted = await client.query(
        `INSERT INTO intercity_ride_requests (
           passenger_id, origin_city, origin_city_key,
           destination_city, destination_city_key, travel_date, seats,
           pickup_address, pickup_lat, pickup_lng, passenger_comment
         ) VALUES ($1, $2, $3, $4, $5, $6::date, $7, $8, $9, $10, $11)
         RETURNING *`,
        [
          passenger.id,
          v.originCity,
          v.originCityKey,
          v.destinationCity,
          v.destinationCityKey,
          v.travelDate,
          v.seats,
          v.pickupAddress,
          v.pickupLat,
          v.pickupLng,
          v.passengerComment,
        ],
      );
      const matchedRideIds = await matchRidesForRequest(
        client,
        inserted.rows[0],
      );
      await client.query('COMMIT');
      await sendIntercityPushes(
        sendPushToUser,
        matchedRideIds.map((matchedRideId) => ({
          firebaseUid: req.user.uid,
          payload: {
            title: 'MEKEN',
            body: `Появилась попутка ${v.originCity} → ${v.destinationCity}`,
            data: {
              type: 'intercity_ride_match_available',
              rideId: matchedRideId,
              requestId: inserted.rows[0].id,
              originCity: v.originCity,
              destinationCity: v.destinationCity,
            },
          },
        })),
      );
      return res.status(201).json({
        request: publicRideRequest({
          ...inserted.rows[0],
          matched_ride_ids: matchedRideIds,
        }),
      });
    } catch (e) {
      await rollbackQuietly(client);
      console.error('[IntercityRideRequestCreate]', e);
      return error(res, 500, 'Failed to create ride request');
    } finally {
      client.release();
    }
  });

  router.get('/requests/mine', async (req, res) => {
    try {
      const passenger = await loadAuthenticatedUser(pool, req.user.uid);
      if (!passenger) return error(res, 403, 'Registered user is required');
      const result = await pool.query(
        `${selectRideRequest}
         WHERE q.passenger_id = $1
         GROUP BY q.id
         ORDER BY q.created_at DESC, q.id`,
        [passenger.id],
      );
      return res.json({ requests: result.rows.map(publicRideRequest) });
    } catch (e) {
      console.error('[IntercityRideRequestsMine]', e);
      return error(res, 500, 'Failed to load ride requests');
    }
  });

  router.post('/requests/:requestId/cancel', async (req, res) => {
    if (!isUuid(req.params.requestId)) {
      return error(res, 400, 'Invalid requestId');
    }
    let passenger;
    try {
      passenger = await loadAuthenticatedUser(pool, req.user.uid);
    } catch (e) {
      console.error('[IntercityRideRequestCancelUser]', e);
      return error(res, 500, 'Failed to cancel ride request');
    }
    if (!passenger) return error(res, 403, 'Registered user is required');

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const reference = await client.query(
        `SELECT origin_city_key, destination_city_key, travel_date
         FROM intercity_ride_requests
         WHERE id = $1 AND passenger_id = $2`,
        [req.params.requestId, passenger.id],
      );
      if (!reference.rows[0]) {
        await client.query('ROLLBACK');
        return error(res, 404, 'Ride request not found');
      }
      await lockMatchingRoute(
        client,
        reference.rows[0].origin_city_key,
        reference.rows[0].destination_city_key,
        reference.rows[0].travel_date,
      );
      await client.query(`SELECT id FROM users WHERE id = $1 FOR UPDATE`, [
        passenger.id,
      ]);
      const locked = await client.query(
        `SELECT * FROM intercity_ride_requests
         WHERE id = $1 AND passenger_id = $2
         FOR UPDATE`,
        [req.params.requestId, passenger.id],
      );
      const rideRequest = locked.rows[0];
      if (!rideRequest) {
        await client.query('ROLLBACK');
        return error(res, 404, 'Ride request not found');
      }
      if (rideRequest.status === 'cancelled') {
        const current = await loadRideRequestWithMatches(
          client,
          rideRequest.id,
        );
        await client.query('COMMIT');
        return res.json({ request: publicRideRequest(current) });
      }
      if (rideRequest.status !== 'active') {
        await client.query('ROLLBACK');
        return error(res, 409, 'Only active ride requests can be cancelled');
      }

      await client.query(
        `UPDATE intercity_ride_requests
         SET status = 'cancelled', cancelled_at = now(), updated_at = now()
         WHERE id = $1`,
        [rideRequest.id],
      );
      const updated = await loadRideRequestWithMatches(
        client,
        rideRequest.id,
      );
      await client.query('COMMIT');
      return res.json({ request: publicRideRequest(updated) });
    } catch (e) {
      await rollbackQuietly(client);
      console.error('[IntercityRideRequestCancel]', e);
      return error(res, 500, 'Failed to cancel ride request');
    } finally {
      client.release();
    }
  });

  router.get('/bookings/mine', async (req, res) => {
    try {
      const passenger = await loadAuthenticatedUser(pool, req.user.uid);
      if (!passenger) return error(res, 403, 'Registered user is required');
      const result = await pool.query(
        `${selectBooking}
         WHERE b.passenger_id = $1
         ORDER BY b.created_at DESC, b.id`,
        [passenger.id],
      );
      res.json({
        bookings: result.rows.map((row) =>
          publicBooking(row, { viewer: 'passenger' })),
      });
    } catch (e) {
      console.error('[IntercityRideBookingsMine]', e);
      error(res, 500, 'Failed to load bookings');
    }
  });

  router.post('/bookings/:bookingId/cancel', async (req, res) => {
    if (!isUuid(req.params.bookingId)) {
      return error(res, 400, 'Invalid bookingId');
    }
    let passenger;
    try {
      passenger = await loadAuthenticatedUser(pool, req.user.uid);
    } catch (e) {
      console.error('[IntercityRideBookingCancelUser]', e);
      return error(res, 500, 'Failed to cancel booking');
    }
    if (!passenger) return error(res, 403, 'Registered user is required');
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const reference = await client.query(
        `SELECT ride_id FROM intercity_ride_bookings WHERE id = $1`,
        [req.params.bookingId],
      );
      if (!reference.rows[0]) {
        await client.query('ROLLBACK');
        return error(res, 404, 'Booking not found');
      }

      const rideResult = await client.query(
        `SELECT r.*,
                COALESCE(u.firebase_uid, u.id::text) AS driver_firebase_uid
         FROM intercity_rides r
         JOIN users u ON u.id = r.driver_id
         WHERE r.id = $1 FOR UPDATE OF r`,
        [reference.rows[0].ride_id],
      );
      const bookingResult = await client.query(
        `SELECT * FROM intercity_ride_bookings WHERE id = $1 FOR UPDATE`,
        [req.params.bookingId],
      );
      const ride = rideResult.rows[0];
      const booking = bookingResult.rows[0];
      if (!ride || !booking) {
        await client.query('ROLLBACK');
        return error(res, 404, 'Booking not found');
      }
      if (booking.passenger_id !== passenger.id) {
        await client.query('ROLLBACK');
        return error(res, 403, 'Booking ownership required');
      }

      if (booking.status === 'cancelled') {
        const current = await client.query(
          `${selectBooking} WHERE b.id = $1`,
          [booking.id],
        );
        await client.query('COMMIT');
        return res.json({
          booking: publicBooking(current.rows[0], { viewer: 'passenger' }),
        });
      }
      if (booking.status !== 'confirmed') {
        await client.query('ROLLBACK');
        return error(res, 409, 'Only confirmed bookings can be cancelled');
      }
      if (
        ride.status !== 'scheduled'
        || new Date(ride.departure_at) <= new Date()
      ) {
        await client.query('ROLLBACK');
        return error(res, 409, 'Booking can no longer be cancelled');
      }

      await client.query(
        `UPDATE intercity_ride_bookings
         SET status = 'cancelled', cancelled_at = now(), updated_at = now()
         WHERE id = $1`,
        [booking.id],
      );
      await client.query(
        `UPDATE intercity_rides
         SET available_seats = available_seats + $1, updated_at = now()
         WHERE id = $2`,
        [booking.seats, ride.id],
      );
      const updated = await client.query(
        `${selectBooking} WHERE b.id = $1`,
        [booking.id],
      );
      await client.query('COMMIT');
      await sendIntercityPush(sendPushToUser, ride.driver_firebase_uid, {
        title: 'MEKEN',
        body: 'Пассажир отменил бронирование',
        data: {
          type: 'intercity_booking_cancelled',
          rideId: ride.id,
          bookingId: booking.id,
        },
      });
      return res.json({
        booking: publicBooking(updated.rows[0], { viewer: 'passenger' }),
      });
    } catch (e) {
      await rollbackQuietly(client);
      console.error('[IntercityRideBookingCancel]', e);
      return error(res, 500, 'Failed to cancel booking');
    } finally {
      client.release();
    }
  });

  router.post('/:rideId/book', async (req, res) => {
    if (!isUuid(req.params.rideId)) return error(res, 400, 'Invalid rideId');
    const checked = validateIntercityRideBooking(req.body);
    if (!checked.ok) return error(res, 400, checked.error);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await acquireAccountLifecycleLock(client, req.user.uid);
      const lifecycle = await loadAccountLifecycleState(client, req.user.uid);
      if (lifecycle.kind !== 'active') {
        await client.query('ROLLBACK');
        return lifecycleError(res, lifecycle, 'Registered user is required');
      }
      const passenger = lifecycle.user;
      const preexisting = await loadBookingByRequest(
        client,
        passenger.id,
        checked.value.clientRequestId,
      );
      if (
        preexisting
        && !isCompatibleReplay(
          preexisting,
          req.params.rideId,
          checked.value,
        )
      ) {
        await client.query('ROLLBACK');
        return error(res, 409, 'clientRequestId was already used');
      }

      const rideResult = await client.query(
        `SELECT r.*, du.name AS driver_name, du.phone AS driver_phone,
            COALESCE(du.firebase_uid, du.id::text) AS driver_firebase_uid,
            dp.car_model, dp.car_color, dp.car_number
         FROM intercity_rides r
         JOIN users du ON du.id = r.driver_id
         JOIN driver_profiles dp ON dp.user_id = r.driver_id
         WHERE r.id = $1
         FOR UPDATE OF r`,
        [req.params.rideId],
      );
      const ride = rideResult.rows[0];
      if (!ride) {
        await client.query('ROLLBACK');
        return error(res, 404, 'Ride not found');
      }

      const existing = await loadBookingByRequest(
        client,
        passenger.id,
        checked.value.clientRequestId,
        { forUpdate: true },
      );
      if (existing) {
        if (
          !isCompatibleReplay(
            existing,
            req.params.rideId,
            checked.value,
          )
        ) {
          await client.query('ROLLBACK');
          return error(res, 409, 'clientRequestId was already used');
        }
        await client.query('COMMIT');
        return res.status(200).json({
          booking: publicBooking(existing, { viewer: 'passenger' }),
        });
      }

      if (passenger.id === ride.driver_id) {
        await client.query('ROLLBACK');
        return error(res, 403, 'Drivers cannot book their own ride');
      }
      if (await areUsersBlocked(client, passenger.id, ride.driver_id)) {
        await client.query('ROLLBACK');
        return res.status(403).json({ code: 'user_blocked', error: 'Future booking is blocked' });
      }
      if (
        ride.status !== 'scheduled'
        || new Date(ride.departure_at) <= new Date()
      ) {
        await client.query('ROLLBACK');
        return error(res, 409, 'Ride is no longer available');
      }
      if (ride.available_seats < checked.value.seats) {
        await client.query('ROLLBACK');
        return error(res, 409, 'Not enough available seats');
      }

      const inserted = await client.query(
        `INSERT INTO intercity_ride_bookings (
           ride_id, passenger_id, seats, price_per_seat, client_request_id,
           pickup_address, pickup_lat, pickup_lng, passenger_comment
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT DO NOTHING
         RETURNING *`,
        [
          ride.id,
          passenger.id,
          checked.value.seats,
          ride.price_per_seat,
          checked.value.clientRequestId,
          checked.value.pickupAddress,
          checked.value.pickupLat,
          checked.value.pickupLng,
          checked.value.passengerComment,
        ],
      );

      if (!inserted.rows[0]) {
        const idempotencyConflict = await loadBookingByRequest(
          client,
          passenger.id,
          checked.value.clientRequestId,
          { forUpdate: true },
        );
        if (
          idempotencyConflict
          && isCompatibleReplay(
            idempotencyConflict,
            req.params.rideId,
            checked.value,
          )
        ) {
          await client.query('COMMIT');
          return res.status(200).json({
            booking: publicBooking(idempotencyConflict, {
              viewer: 'passenger',
            }),
          });
        }
        await client.query(
          `SELECT id FROM intercity_ride_bookings
           WHERE ride_id = $1 AND passenger_id = $2
             AND status = 'confirmed'
           FOR UPDATE`,
          [ride.id, passenger.id],
        );
        await client.query('ROLLBACK');
        return error(res, 409, 'Passenger already has a booking for this ride');
      }

      const inventory = await client.query(
        `UPDATE intercity_rides
         SET available_seats = available_seats - $1, updated_at = now()
         WHERE id = $2 AND status = 'scheduled' AND departure_at > now()
           AND available_seats >= $1
         RETURNING *`,
        [checked.value.seats, ride.id],
      );
      if (!inventory.rows[0]) {
        await client.query('ROLLBACK');
        return error(res, 409, 'Ride is no longer available');
      }

      const created = await client.query(
        `${selectBooking} WHERE b.id = $1`,
        [inserted.rows[0].id],
      );
      await client.query('COMMIT');
      await sendIntercityPush(sendPushToUser, ride.driver_firebase_uid, {
        title: 'MEKEN',
        body: `Пассажир забронировал ${checked.value.seats} ${seatsLabel(checked.value.seats)}`,
        data: {
          type: 'intercity_booking_created',
          rideId: ride.id,
          bookingId: inserted.rows[0].id,
          seats: checked.value.seats,
        },
      });
      return res.status(201).json({
        booking: publicBooking(created.rows[0], { viewer: 'passenger' }),
      });
    } catch (e) {
      await rollbackQuietly(client);
      console.error('[IntercityRideBook]', e);
      return error(res, 500, 'Failed to book ride');
    } finally {
      client.release();
    }
  });

  router.get('/:rideId/bookings', async (req, res) => {
    if (!isUuid(req.params.rideId)) return error(res, 400, 'Invalid rideId');
    try {
      const driver = await loadAuthenticatedUser(pool, req.user.uid);
      if (!driver) return error(res, 403, 'Registered user is required');
      const ride = await pool.query(
        `SELECT driver_id FROM intercity_rides WHERE id = $1`,
        [req.params.rideId],
      );
      if (!ride.rows[0]) return error(res, 404, 'Ride not found');
      if (ride.rows[0].driver_id !== driver.id) {
        return error(res, 403, 'Ride ownership required');
      }
      const result = await pool.query(
        `${selectBooking}
         WHERE b.ride_id = $1
         ORDER BY b.created_at, b.id`,
        [req.params.rideId],
      );
      return res.json({
        bookings: result.rows.map((row) =>
          publicBooking(row, { viewer: 'driver' })),
      });
    } catch (e) {
      console.error('[IntercityRideBookingsDriver]', e);
      return error(res, 500, 'Failed to load ride bookings');
    }
  });

  router.post('/:rideId/bookings/:bookingId/pickup-reached', async (req, res) => {
    if (!isUuid(req.params.rideId) || !isUuid(req.params.bookingId)) {
      return error(res, 400, 'Invalid rideId or bookingId');
    }
    try {
      const driver = await loadAuthenticatedUser(pool, req.user.uid);
      if (!driver) return error(res, 403, 'Registered user is required');
      const updated = await pool.query(
        `UPDATE intercity_ride_bookings b
         SET pickup_reached_at = COALESCE(b.pickup_reached_at, now()),
             updated_at = now()
         FROM intercity_rides r
         WHERE b.id = $1
           AND b.ride_id = $2
           AND r.id = b.ride_id
           AND r.driver_id = $3
           AND r.status = 'departed'
           AND b.status = 'confirmed'
           AND b.pickup_address IS NOT NULL
           AND b.pickup_lat IS NOT NULL
           AND b.pickup_lng IS NOT NULL
         RETURNING b.id`,
        [req.params.bookingId, req.params.rideId, driver.id],
      );
      if (!updated.rows[0]) {
        return error(res, 409, 'Pickup cannot be marked reached');
      }
      const result = await pool.query(
        `${selectBooking} WHERE b.id = $1`,
        [req.params.bookingId],
      );
      return res.json({
        booking: publicBooking(result.rows[0], { viewer: 'driver' }),
      });
    } catch (e) {
      console.error('[IntercityPickupReached]', e);
      return error(res, 500, 'Failed to mark pickup reached');
    }
  });

  router.get('/:rideId', async (req, res) => {
    if (!isUuid(req.params.rideId)) return error(res, 400, 'Invalid rideId');
    try {
      const result = await pool.query(
        `${selectRide}
         WHERE r.id=$1 AND (
           (u.firebase_uid=$2 OR u.id::text=$2)
           OR (r.status='scheduled' AND r.departure_at > now())
         )`,
        [req.params.rideId, req.user.uid],
      );
      if (!result.rows[0]) return error(res, 404, 'Ride not found');
      res.json({ ride: publicRide(result.rows[0]) });
    } catch (e) {
      console.error('[IntercityRideGet]', e);
      error(res, 500, 'Failed to load ride');
    }
  });

  router.patch('/:rideId', async (req, res) => {
    if (!isUuid(req.params.rideId)) return error(res, 400, 'Invalid rideId');
    const checked = validateIntercityRidePatch(req.body);
    if (!checked.ok) return error(res, 400, checked.error);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const current = await client.query(
        `SELECT r.*,
                COALESCE(u.firebase_uid, u.id::text) AS firebase_uid,
                u.name AS driver_name,
            dp.car_model, dp.car_color, dp.car_number
         FROM intercity_rides r
         JOIN users u ON u.id=r.driver_id
         JOIN driver_profiles dp ON dp.user_id=r.driver_id
         WHERE r.id=$1 FOR UPDATE OF r`,
        [req.params.rideId],
      );
      const ride = current.rows[0];
      if (!ride) {
        await client.query('ROLLBACK');
        return error(res, 404, 'Ride not found');
      }
      if (ride.firebase_uid !== req.user.uid) {
        await client.query('ROLLBACK');
        return error(res, 403, 'Ride ownership required');
      }
      if (ride.status !== 'scheduled') {
        await client.query('ROLLBACK');
        return error(res, 409, 'Only scheduled rides can be updated');
      }
      const nextOriginKey =
        checked.value.originCityKey ?? ride.origin_city_key;
      const nextDestinationKey =
        checked.value.destinationCityKey ?? ride.destination_city_key;
      if (nextOriginKey === nextDestinationKey) {
        await client.query('ROLLBACK');
        return error(res, 400, 'Origin and destination cities must be different');
      }
      const locked = [
        'originCity',
        'originLat',
        'originLng',
        'destinationCity',
        'destinationLat',
        'destinationLng',
        'departureAt',
        'totalSeats',
      ];
      if (locked.some((key) => Object.hasOwn(req.body, key))) {
        const bookings = await client.query(
          `SELECT 1 FROM intercity_ride_bookings
           WHERE ride_id=$1 AND status='confirmed' LIMIT 1`,
          [ride.id],
        );
        if (bookings.rows.length) {
          await client.query('ROLLBACK');
          return error(
            res,
            409,
            'Route, departure and seats cannot change after booking',
          );
        }
      }
      const v = checked.value;
      const sets = [];
      const params = [];
      const add = (column, value) => {
        params.push(value);
        sets.push(`${column}=$${params.length}`);
      };
      const mapping = {
        originCity: 'origin_city',
        originCityKey: 'origin_city_key',
        originLat: 'origin_lat',
        originLng: 'origin_lng',
        destinationCity: 'destination_city',
        destinationCityKey: 'destination_city_key',
        destinationLat: 'destination_lat',
        destinationLng: 'destination_lng',
        departureAt: 'departure_at',
        pricePerSeat: 'price_per_seat',
        allowsLuggage: 'allows_luggage',
        comment: 'comment',
      };
      for (const [key, column] of Object.entries(mapping)) {
        if (Object.hasOwn(v, key)) add(column, v[key]);
      }
      if (Object.hasOwn(v, 'totalSeats')) {
        const reserved = ride.total_seats - ride.available_seats;
        if (v.totalSeats < reserved) {
          await client.query('ROLLBACK');
          return error(res, 409, 'totalSeats is below booked seats');
        }
        add('total_seats', v.totalSeats);
        add('available_seats', v.totalSeats - reserved);
      }
      params.push(ride.id);
      const updated = await client.query(
        `UPDATE intercity_rides
         SET ${sets.join(', ')}, updated_at=now()
         WHERE id=$${params.length} RETURNING *`,
        params,
      );
      await client.query('COMMIT');
      res.json({
        ride: publicRide({
          ...updated.rows[0],
          driver_name: ride.driver_name,
          car_model: ride.car_model,
          car_color: ride.car_color,
          car_number: ride.car_number,
        }),
      });
    } catch (e) {
      await rollbackQuietly(client);
      console.error('[IntercityRidePatch]', e);
      error(res, 500, 'Failed to update ride');
    } finally {
      client.release();
    }
  });

  const transitions = [
    ['cancel', 'scheduled', 'cancelled', 'cancelled_at'],
    ['depart', 'scheduled', 'departed', 'departed_at'],
    ['complete', 'departed', 'completed', 'completed_at'],
  ];
  for (const [action, from, to, timestamp] of transitions) {
    router.post(`/:rideId/${action}`, async (req, res) => {
      if (!isUuid(req.params.rideId)) return error(res, 400, 'Invalid rideId');
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const current = await client.query(
          `SELECT r.*,
                  COALESCE(u.firebase_uid, u.id::text) AS firebase_uid,
                  u.name AS driver_name,
              dp.car_model, dp.car_color, dp.car_number
           FROM intercity_rides r
           JOIN users u ON u.id = r.driver_id
           JOIN driver_profiles dp ON dp.user_id = r.driver_id
           WHERE r.id = $1 FOR UPDATE OF r`,
          [req.params.rideId],
        );
        const ride = current.rows[0];
        if (!ride) {
          await client.query('ROLLBACK');
          return error(res, 404, 'Ride not found');
        }
        if (ride.firebase_uid !== req.user.uid) {
          await client.query('ROLLBACK');
          return error(res, 403, 'Ride ownership required');
        }
        if (ride.status !== from) {
          await client.query('ROLLBACK');
          return error(
            res,
            409,
            `Ride cannot transition from current status to ${to}`,
          );
        }

        let passengerRecipients = [];
        if (action === 'cancel' || action === 'depart' || action === 'complete') {
          const recipients = await client.query(
            `SELECT b.id AS booking_id,
                COALESCE(u.firebase_uid, u.id::text) AS passenger_firebase_uid
             FROM intercity_ride_bookings b
             JOIN users u ON u.id = b.passenger_id
             WHERE b.ride_id = $1 AND b.status = 'confirmed'
             ORDER BY b.id`,
            [ride.id],
          );
          passengerRecipients = recipients.rows;
        }

        if (action === 'cancel') {
          await client.query(
            `UPDATE intercity_ride_bookings
             SET status = 'cancelled', cancelled_at = now(),
                 updated_at = now()
             WHERE ride_id = $1 AND status = 'confirmed'`,
            [ride.id],
          );
        } else if (action === 'complete') {
          await client.query(
            `UPDATE intercity_ride_bookings
             SET status = 'completed', completed_at = now(),
                 updated_at = now()
             WHERE ride_id = $1 AND status = 'confirmed'`,
            [ride.id],
          );
        }

        const resetInventory =
          action === 'cancel' ? ', available_seats = total_seats' : '';
        const result = await client.query(
          `UPDATE intercity_rides
           SET status = $1, ${timestamp} = now(), updated_at = now()
               ${resetInventory}
           WHERE id = $2 RETURNING *`,
          [to, ride.id],
        );
        await client.query('COMMIT');
        if (action === 'cancel' || action === 'depart' || action === 'complete') {
          const eventType = action === 'cancel'
            ? 'intercity_ride_cancelled'
            : action === 'depart'
            ? 'intercity_trip_started'
            : 'intercity_trip_completed';
          const body = action === 'cancel'
            ? 'Водитель отменил попутку'
            : action === 'depart'
            ? 'Попутка отправилась'
            : 'Междугородняя поездка завершена';
          await sendIntercityPushes(
            sendPushToUser,
            passengerRecipients.map((recipient) => ({
              firebaseUid: recipient.passenger_firebase_uid,
              payload: {
                title: 'MEKEN',
                body,
                data: {
                  type: eventType,
                  rideId: ride.id,
                  bookingId: recipient.booking_id,
                },
              },
            })),
          );
        }
        return res.json({
          ride: publicRide({
            ...result.rows[0],
            driver_name: ride.driver_name,
            car_model: ride.car_model,
            car_color: ride.car_color,
            car_number: ride.car_number,
          }),
        });
      } catch (e) {
        await rollbackQuietly(client);
        console.error(`[IntercityRide${action}]`, e);
        return error(res, 500, 'Failed to change ride status');
      } finally {
        client.release();
      }
    });
  }

  return router;
}
