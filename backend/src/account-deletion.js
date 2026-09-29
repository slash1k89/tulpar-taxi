import {
  accountIdentityHash,
  acquireAccountLifecycleLock,
  newAccountLifecycleToken,
} from './account-lifecycle.js';

export const RECENT_LOGIN_MAX_AGE_SECONDS = 5 * 60;
export const MAX_RETRY_ATTEMPTS = 20;
export const ACCOUNT_DELETION_LEASE_SECONDS = 5 * 60;

// A terminal failed job intentionally retains firebase_uid: without it an
// operator could not finish deleting the remote Firebase identity. Failed
// jobs are never selected automatically; access to this recovery identifier
// must therefore remain restricted with the deletion-job table itself.

export function firebaseUidHash(firebaseUid) {
  return accountIdentityHash(firebaseUid);
}

export async function isDeletedFirebaseUid(pool, firebaseUid) {
  const result = await pool.query(
    `SELECT 1 FROM account_deletion_jobs
      WHERE firebase_uid_hash = $1
      LIMIT 1`,
    [firebaseUidHash(firebaseUid)],
  );
  return result.rowCount > 0;
}

export function hasRecentAuthentication(
  authTime,
  { nowSeconds = Math.floor(Date.now() / 1000) } = {},
) {
  if (!Number.isFinite(authTime)) return false;
  const age = nowSeconds - authTime;
  return age >= -30 && age <= RECENT_LOGIN_MAX_AGE_SECONDS;
}

function firebaseErrorCode(error) {
  const raw = typeof error?.code === 'string' ? error.code : 'firebase_unavailable';
  return /^[a-z0-9/_-]{1,100}$/i.test(raw) ? raw : 'firebase_unavailable';
}

function isFirebaseUserMissing(error) {
  return error?.code === 'auth/user-not-found';
}

export async function markFirebaseDeletionCompleted(pool, jobId, claimToken) {
  return pool.query(
    `UPDATE account_deletion_jobs
        SET status = 'completed', firebase_uid = NULL, completed_at = now(),
            last_error_code = NULL, claimed_at = NULL, lease_until = NULL,
            claim_token = NULL, updated_at = now()
      WHERE id = $1 AND claim_token = $2 AND status = 'pending'`,
    [jobId, claimToken],
  );
}

export async function claimAccountDeletionJob({
  pool,
  jobId = null,
  leaseSeconds = ACCOUNT_DELETION_LEASE_SECONDS,
  claimToken = newAccountLifecycleToken(),
}) {
  const result = await pool.query(
    `WITH candidate AS (
       SELECT id
         FROM account_deletion_jobs
        WHERE status = 'pending'
          AND firebase_uid IS NOT NULL
          AND next_attempt_at <= now()
          AND (lease_until IS NULL OR lease_until <= now())
          AND ($1::uuid IS NULL OR id = $1::uuid)
        ORDER BY next_attempt_at, created_at
        FOR UPDATE SKIP LOCKED
        LIMIT 1
     )
     UPDATE account_deletion_jobs j
        SET claim_token = $2::uuid, claimed_at = now(),
            lease_until = now() + ($3 * interval '1 second'),
            updated_at = now()
       FROM candidate
      WHERE j.id = candidate.id
      RETURNING j.id, j.user_id, j.firebase_uid, j.status,
        j.attempt_count, j.claim_token, j.lease_until`,
    [jobId, claimToken, leaseSeconds],
  );
  return result.rows[0] ?? null;
}

export async function processClaimedFirebaseDeletion({
  pool,
  deleteFirebaseUser,
  job,
}) {
  try {
    await deleteFirebaseUser(job.firebase_uid);
    const finalized = await markFirebaseDeletionCompleted(
      pool,
      job.id,
      job.claim_token,
    );
    return { completed: finalized.rowCount === 1, status: 'completed' };
  } catch (error) {
    if (isFirebaseUserMissing(error)) {
      const finalized = await markFirebaseDeletionCompleted(
        pool,
        job.id,
        job.claim_token,
      );
      return { completed: finalized.rowCount === 1, status: 'completed' };
    }

    const code = firebaseErrorCode(error);
    const result = await pool.query(
      `UPDATE account_deletion_jobs
          SET status = CASE WHEN attempt_count + 1 >= $2 THEN 'failed' ELSE 'pending' END,
              attempt_count = attempt_count + 1,
              last_error_code = $3,
              next_attempt_at = CASE
                WHEN attempt_count + 1 >= $2 THEN next_attempt_at
                ELSE now() +
                  (LEAST(3600, 30 * power(2, LEAST(attempt_count, 7))) * interval '1 second')
              END,
              claimed_at = NULL, lease_until = NULL, claim_token = NULL,
              updated_at = now()
        WHERE id = $1 AND claim_token = $4 AND status = 'pending'
        RETURNING status`,
      [job.id, MAX_RETRY_ATTEMPTS, code, job.claim_token],
    );
    return {
      completed: false,
      status: result.rows[0]?.status ?? 'claim_lost',
    };
  }
}

export async function attemptFirebaseDeletion({
  pool,
  deleteFirebaseUser,
  job,
}) {
  if (job.status === 'completed') return { completed: true, status: 'completed' };
  if (job.status === 'failed') return { completed: false, status: 'failed' };
  const claimed = await claimAccountDeletionJob({ pool, jobId: job.id });
  if (!claimed) return { completed: false, status: 'pending' };
  return processClaimedFirebaseDeletion({
    pool,
    deleteFirebaseUser,
    job: claimed,
  });
}

export async function retryPendingAccountDeletions({
  pool,
  deleteFirebaseUser,
  limit = 10,
}) {
  let processed = 0;
  for (let index = 0; index < limit; index += 1) {
    const job = await claimAccountDeletionJob({ pool });
    if (!job) break;
    processed += 1;
    try {
      const outcome = await processClaimedFirebaseDeletion({
        pool,
        deleteFirebaseUser,
        job,
      });
      console.log(
        `[AccountDeletionRetry] job=${job.id} user=${job.user_id} `
          + `status=${outcome.status}`,
      );
    } catch (_) {
      console.error(
        `[AccountDeletionRetry] job=${job.id} user=${job.user_id} status=deferred`,
      );
    }
  }
  return processed;
}

async function findBlocker(client, userId) {
  const checks = [
    [
      'active_order',
      `SELECT 1 FROM orders
        WHERE passenger_id = $1
          AND status IN ('searching', 'accepted', 'driver_arrived', 'in_progress')
        LIMIT 1`,
    ],
    [
      'active_driver_order',
      `SELECT 1 FROM orders
        WHERE driver_id = $1
          AND status IN ('accepted', 'driver_arrived', 'in_progress')
        LIMIT 1`,
    ],
    [
      'active_ride',
      `SELECT 1 FROM intercity_rides
        WHERE driver_id = $1 AND status IN ('scheduled', 'departed')
        LIMIT 1`,
    ],
    [
      'active_booking',
      `SELECT 1
         FROM intercity_ride_bookings b
         JOIN intercity_rides r ON r.id = b.ride_id
        WHERE b.passenger_id = $1 AND b.status = 'confirmed'
          AND r.status IN ('scheduled', 'departed')
        LIMIT 1`,
    ],
    [
      'active_ride_request',
      `SELECT 1 FROM intercity_ride_requests
        WHERE passenger_id = $1 AND status = 'active'
        LIMIT 1`,
    ],
  ];

  for (const [code, sql] of checks) {
    const result = await client.query(sql, [userId]);
    if (result.rowCount > 0) return code;
  }
  return null;
}

async function anonymizeUser(client, userId, phone) {
  await client.query('DELETE FROM user_push_tokens WHERE user_id = $1', [userId]);
  await client.query('DELETE FROM auth_phone_identities WHERE user_id = $1', [userId]);
  await client.query('DELETE FROM auth_sessions WHERE user_id = $1', [userId]);
  await client.query(
    `DELETE FROM auth_password_verifications
      WHERE user_id = $1
         OR ($2::text IS NOT NULL AND phone_normalized = $2)`,
    [userId, phone],
  );
  await client.query(
    `DELETE FROM auth_otp_challenges
      WHERE $1::text IS NOT NULL AND phone_normalized = $1`,
    [phone],
  );
  await client.query('DELETE FROM user_terms_acceptances WHERE user_id = $1', [userId]);
  await client.query(
    'DELETE FROM user_blocks WHERE blocker_user_id = $1 OR blocked_user_id = $1',
    [userId],
  );
  await client.query('DELETE FROM driver_profiles WHERE user_id = $1', [userId]);
  await client.query(
    `UPDATE order_offers SET status = 'withdrawn', updated_at = now()
      WHERE driver_id = $1 AND status = 'pending'`,
    [userId],
  );
  await client.query(
    `UPDATE driver_subscriptions
        SET status = 'cancelled'
      WHERE driver_id = $1 AND status = 'active'`,
    [userId],
  );
  await client.query(
    `UPDATE orders
        SET driver_lat = NULL, driver_lng = NULL,
            driver_location_updated_at = NULL, updated_at = now()
      WHERE driver_id = $1`,
    [userId],
  );
  await client.query(
    `UPDATE order_stops s
        SET address = NULL, latitude = NULL, longitude = NULL
       FROM orders o
      WHERE s.order_id = o.id
        AND (o.passenger_id = $1 OR o.driver_id = $1)`,
    [userId],
  );
  await client.query(
    `UPDATE orders
        SET pickup_address = NULL, destination_address = NULL,
            pickup_lat = NULL, pickup_lng = NULL,
            destination_lat = NULL, destination_lng = NULL,
            updated_at = now()
      WHERE passenger_id = $1`,
    [userId],
  );
  await client.query(
    `UPDATE order_messages SET text = '[сообщение удалено]'
      WHERE sender_id = $1`,
    [userId],
  );
  await client.query(
    `UPDATE intercity_booking_messages SET text = '[сообщение удалено]'
      WHERE sender_id = $1`,
    [userId],
  );
  await client.query(
    `UPDATE ratings SET comment = NULL WHERE from_user_id = $1`,
    [userId],
  );
  await client.query(
    `UPDATE delivery_details d
        SET item_description = '[удалено]', sender_name = NULL,
            sender_phone = NULL, recipient_name = NULL, recipient_phone = NULL,
            pickup_entrance = NULL, pickup_apartment = NULL,
            pickup_floor = NULL, pickup_intercom = NULL, pickup_comment = NULL,
            destination_entrance = NULL, destination_apartment = NULL,
            destination_floor = NULL, destination_intercom = NULL,
            destination_comment = NULL, updated_at = now()
       FROM orders o
      WHERE d.order_id = o.id AND o.passenger_id = $1`,
    [userId],
  );
  await client.query(
    `UPDATE intercity_details d SET comment = NULL, updated_at = now()
       FROM orders o
      WHERE d.order_id = o.id AND o.passenger_id = $1`,
    [userId],
  );
  await client.query(
    `UPDATE intercity_rides
        SET origin_lat = NULL, origin_lng = NULL,
            destination_lat = NULL, destination_lng = NULL,
            comment = NULL, updated_at = now()
      WHERE driver_id = $1`,
    [userId],
  );
  await client.query(
    `UPDATE intercity_ride_bookings
        SET pickup_address = NULL, pickup_lat = NULL, pickup_lng = NULL,
            passenger_comment = NULL, updated_at = now()
      WHERE passenger_id = $1`,
    [userId],
  );
  await client.query(
    `UPDATE intercity_ride_requests
        SET pickup_address = NULL, pickup_lat = NULL, pickup_lng = NULL,
            passenger_comment = NULL, updated_at = now()
      WHERE passenger_id = $1`,
    [userId],
  );
  await client.query(
    `UPDATE users
        SET firebase_uid = NULL, phone = NULL, name = NULL, password_hash = NULL,
            rating = 5.00, rating_sum = 0, rating_count = 0,
            account_status = 'deleted', deleted_at = now(), updated_at = now()
      WHERE id = $1`,
    [userId],
  );
}

export async function beginAccountDeletionByUserId({ pool, userId }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await acquireAccountLifecycleLock(client, `user:${userId}`);
    const userResult = await client.query(
      `SELECT id, firebase_uid, phone FROM users
        WHERE id = $1 AND account_status = 'active' FOR UPDATE`,
      [userId],
    );
    if (!userResult.rowCount) {
      const existing = await client.query(
        `SELECT id, user_id, firebase_uid, status FROM account_deletion_jobs
          WHERE user_id = $1`,
        [userId],
      );
      await client.query('COMMIT');
      if (!existing.rowCount) return { kind: 'not_found' };
      return { kind: 'existing', job: existing.rows[0] };
    }
    const user = userResult.rows[0];
    const blocker = await findBlocker(client, user.id);
    if (blocker) {
      await client.query('ROLLBACK');
      return { kind: 'blocked', code: blocker };
    }
    const identity = user.firebase_uid ?? `tulpar-user:${user.id}`;
    const remoteDeletionRequired = Boolean(user.firebase_uid);
    const jobResult = await client.query(
      `INSERT INTO account_deletion_jobs (
        user_id, firebase_uid_hash, firebase_uid, status, completed_at
       ) VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (user_id) DO UPDATE SET updated_at = now()
       RETURNING id, user_id, firebase_uid, status`,
      [user.id, firebaseUidHash(identity), user.firebase_uid,
        remoteDeletionRequired ? 'pending' : 'completed',
        remoteDeletionRequired ? null : new Date()],
    );
    await anonymizeUser(client, user.id, user.phone);
    await client.query('COMMIT');
    return { kind: 'created', job: jobResult.rows[0] };
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    throw error;
  } finally {
    client.release();
  }
}

export async function beginAccountDeletion({ pool, firebaseUid }) {
  const uidHash = firebaseUidHash(firebaseUid);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await acquireAccountLifecycleLock(client, firebaseUid);
    const userResult = await client.query(
      `SELECT id, phone FROM users
        WHERE firebase_uid = $1 AND account_status = 'active'
        FOR UPDATE`,
      [firebaseUid],
    );

    if (userResult.rowCount === 0) {
      const existing = await client.query(
        `SELECT id, user_id, firebase_uid, status
           FROM account_deletion_jobs
          WHERE firebase_uid_hash = $1`,
        [uidHash],
      );
      await client.query('COMMIT');
      if (existing.rowCount === 0) return { kind: 'not_found' };
      return { kind: 'existing', job: existing.rows[0] };
    }

    const userId = userResult.rows[0].id;
    const phone = userResult.rows[0].phone;
    const blocker = await findBlocker(client, userId);
    if (blocker !== null) {
      await client.query('ROLLBACK');
      return { kind: 'blocked', code: blocker };
    }

    const jobResult = await client.query(
      `INSERT INTO account_deletion_jobs (
         user_id, firebase_uid_hash, firebase_uid, status
       ) VALUES ($1, $2, $3, 'pending')
       ON CONFLICT (user_id) DO UPDATE SET updated_at = now()
       RETURNING id, user_id, firebase_uid, status`,
      [userId, uidHash, firebaseUid],
    );
    await anonymizeUser(client, userId, phone);
    await client.query('COMMIT');
    return { kind: 'created', job: jobResult.rows[0] };
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {}
    throw error;
  } finally {
    client.release();
  }
}
