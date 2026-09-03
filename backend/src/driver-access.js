export async function loadIntercityDriverAccess(queryable, firebaseUid) {
  const result = await queryable.query(
    `SELECT u.id AS driver_id, u.name AS driver_name,
            dp.status, dp.access_exempt, dp.car_model, dp.car_color,
            (dp.access_exempt = TRUE OR EXISTS (
              SELECT 1 FROM driver_subscriptions ds
              WHERE ds.driver_id = u.id AND ds.status = 'active'
                AND ds.payment_status = 'paid' AND ds.valid_until > now()
            )) AS has_access
       FROM users u JOIN driver_profiles dp ON dp.user_id = u.id
      WHERE (u.firebase_uid = $1 OR u.id::text = $1)
        AND u.account_status = 'active' LIMIT 1`,
    [firebaseUid],
  );
  const row = result.rows[0] ?? null;
  return row && row.status === 'active' && row.has_access === true ? row : null;
}
