import {
  acquireAccountLifecycleLock,
  loadAccountLifecycleState,
} from './account-lifecycle.js';

async function rollbackQuietly(client) {
  try {
    await client.query('ROLLBACK');
  } catch (_) {
    // Preserve the original database error.
  }
}

export async function syncActiveUser({ pool, firebaseUid, phone, name }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await acquireAccountLifecycleLock(client, firebaseUid);
    const lifecycle = await loadAccountLifecycleState(client, firebaseUid);
    if (lifecycle.kind === 'deleted') {
      await client.query('ROLLBACK');
      return { kind: 'deleted' };
    }

    const result = await client.query(
      `INSERT INTO users (
         firebase_uid, phone, name, rating, rating_sum, rating_count
       ) VALUES ($1, $2, $3, 5.00, 0, 0)
       ON CONFLICT (firebase_uid)
       DO UPDATE SET
         phone = COALESCE(EXCLUDED.phone, users.phone),
         name = COALESCE(EXCLUDED.name, users.name),
         updated_at = now()
       WHERE users.account_status = 'active'
       RETURNING id, firebase_uid, phone, name, rating, rating_sum,
         rating_count, created_at, updated_at`,
      [firebaseUid, phone, name],
    );
    if (result.rowCount === 0) {
      await client.query('ROLLBACK');
      return { kind: 'deleted' };
    }
    await client.query('COMMIT');
    return { kind: 'active', user: result.rows[0] };
  } catch (error) {
    await rollbackQuietly(client);
    throw error;
  } finally {
    client.release();
  }
}
