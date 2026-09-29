const DEFAULT_BATCH_SIZE = 500;

function batchSize(value = DEFAULT_BATCH_SIZE) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1 || parsed > 5000) {
    throw new Error('Auth history cleanup batch size must be between 1 and 5000');
  }
  return parsed;
}

export async function cleanupExpiredAuthHistory({
  pool,
  now = new Date(),
  limit = DEFAULT_BATCH_SIZE,
} = {}) {
  if (!pool?.query) throw new Error('A PostgreSQL pool is required');
  const safeLimit = batchSize(limit);

  const passwordVerifications = await pool.query(
    `WITH victims AS (
       SELECT id
         FROM auth_password_verifications
        WHERE consumed_at IS NOT NULL OR expires_at <= $1
        ORDER BY expires_at, id
        LIMIT $2
     )
     DELETE FROM auth_password_verifications v
      USING victims
      WHERE v.id = victims.id
      RETURNING v.id`,
    [now, safeLimit],
  );

  const otpChallenges = await pool.query(
    `WITH victims AS (
       SELECT c.id
         FROM auth_otp_challenges c
        WHERE c.expires_at <= $1
          AND c.resend_available_at <= $1
          AND NOT EXISTS (
            SELECT 1 FROM auth_password_verifications v
             WHERE v.challenge_id = c.id
          )
        ORDER BY c.expires_at, c.id
        LIMIT $2
     )
     DELETE FROM auth_otp_challenges c
      USING victims
      WHERE c.id = victims.id
      RETURNING c.id`,
    [now, safeLimit],
  );

  const sessions = await pool.query(
    `WITH victims AS (
       SELECT id
         FROM auth_sessions
        WHERE expires_at <= $1
        ORDER BY expires_at, id
        LIMIT $2
     )
     DELETE FROM auth_sessions s
      USING victims
      WHERE s.id = victims.id
      RETURNING s.id`,
    [now, safeLimit],
  );

  return {
    passwordVerifications: passwordVerifications.rowCount,
    otpChallenges: otpChallenges.rowCount,
    sessions: sessions.rowCount,
  };
}
