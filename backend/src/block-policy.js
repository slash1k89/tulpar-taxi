export async function areUsersBlocked(queryable, firstUserId, secondUserId) {
  if (!firstUserId || !secondUserId) return false;
  const result = await queryable.query(
    `SELECT 1 FROM user_blocks
      WHERE (blocker_user_id = $1 AND blocked_user_id = $2)
         OR (blocker_user_id = $2 AND blocked_user_id = $1)
      LIMIT 1`,
    [firstUserId, secondUserId],
  );
  return result.rowCount > 0;
}

export function blockedPairSql(firstExpression, secondExpression) {
  return `NOT EXISTS (
    SELECT 1 FROM user_blocks ub
    WHERE (ub.blocker_user_id = ${firstExpression} AND ub.blocked_user_id = ${secondExpression})
       OR (ub.blocker_user_id = ${secondExpression} AND ub.blocked_user_id = ${firstExpression})
  )`;
}

export function canBlockedPairWriteChat({ blocked, activeTrip }) {
  return !blocked || activeTrip;
}
