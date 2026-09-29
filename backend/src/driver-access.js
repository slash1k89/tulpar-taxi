export async function loadIntercityDriverAccess(queryable, firebaseUid) {
  const result = await queryable.query(
    `SELECT u.id AS driver_id, u.name AS driver_name,
            dp.status, dp.access_exempt, dp.car_model, dp.car_color
       FROM users u JOIN driver_profiles dp ON dp.user_id = u.id
      WHERE (u.firebase_uid = $1 OR u.id::text = $1)
        AND u.account_status = 'active' LIMIT 1`,
    [firebaseUid],
  );
  const row = result.rows[0] ?? null;
  // Store release policy: an approved profile is sufficient. Legacy payment
  // columns stay in the database for history but never gate driver access.
  return row?.status === 'active' ? row : null;
}
