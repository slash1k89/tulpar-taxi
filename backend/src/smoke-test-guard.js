const allowedLoopbackHosts = new Set([
  'localhost',
  '127.0.0.1',
  '::1',
  'host.docker.internal',
]);

function isClearlyTestHost(host) {
  return (
    allowedLoopbackHosts.has(host) ||
    /(^|[-_.])test([-_.]|$)/.test(host)
  );
}

export function assertSafeDestructiveTestDatabase(env = process.env) {
  const allowed = String(env.ALLOW_DESTRUCTIVE_TEST_DB ?? '').trim();
  const database = String(env.POSTGRES_DB ?? '').trim().toLowerCase();
  const host = String(env.DB_HOST ?? '').trim().toLowerCase();

  if (allowed !== '1') {
    throw new Error('Smoke tests require ALLOW_DESTRUCTIVE_TEST_DB=1');
  }
  if (database === 'tulpar') {
    throw new Error('Production database tulpar is forbidden for smoke tests');
  }
  if (!database.endsWith('_test')) {
    throw new Error('Smoke-test database name must end with _test');
  }
  if (host.length === 0 || host === 'postgres' || !isClearlyTestHost(host)) {
    throw new Error('Smoke-test DB_HOST must be an explicit local or test host');
  }
}
