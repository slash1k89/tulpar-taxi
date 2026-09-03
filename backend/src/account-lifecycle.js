import { createHash, randomUUID } from 'node:crypto';

const ACCOUNT_LIFECYCLE_NAMESPACE = 'tulpar-account-lifecycle-v1:';

// Lock order for every transaction that creates/restores user-owned active
// state: lifecycle advisory lock -> users row -> domain rows/route lock ->
// writes. Account deletion follows the same prefix before blocker checks and
// anonymization. No protected flow may acquire the lifecycle lock after a
// domain row lock; keeping that order prevents cross-flow deadlocks.

export function accountIdentityHash(firebaseUid) {
  return createHash('sha256').update(firebaseUid, 'utf8').digest('hex');
}

function lifecycleLockKeys(firebaseUid) {
  const digest = createHash('sha256')
    .update(`${ACCOUNT_LIFECYCLE_NAMESPACE}${firebaseUid}`, 'utf8')
    .digest();
  return [digest.readInt32BE(0), digest.readInt32BE(4)];
}

export async function acquireAccountLifecycleLock(client, firebaseUid) {
  const [key1, key2] = lifecycleLockKeys(firebaseUid);
  await client.query('SELECT pg_advisory_xact_lock($1, $2)', [key1, key2]);
}

export async function loadAccountLifecycleState(client, firebaseUid) {
  const user = await client.query(
    `SELECT id, name, phone, account_status
       FROM users
      WHERE (firebase_uid = $1 OR id::text = $1)
      FOR UPDATE`,
    [firebaseUid],
  );
  if (user.rows[0]?.account_status === 'active') {
    return { kind: 'active', user: user.rows[0] };
  }

  const deletion = await client.query(
    `SELECT 1 FROM account_deletion_jobs
      WHERE firebase_uid_hash = $1
      LIMIT 1`,
    [accountIdentityHash(firebaseUid)],
  );
  return deletion.rowCount > 0
    ? { kind: 'deleted' }
    : { kind: 'unavailable' };
}

export function newAccountLifecycleToken() {
  return randomUUID();
}
