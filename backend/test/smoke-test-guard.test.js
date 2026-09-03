import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import { assertSafeDestructiveTestDatabase } from '../src/smoke-test-guard.js';

test('smoke tests are forbidden unless explicitly enabled', () => {
  assert.throws(
    () => assertSafeDestructiveTestDatabase({
      DB_HOST: 'localhost',
      POSTGRES_DB: 'tulpar_test',
    }),
    /ALLOW_DESTRUCTIVE_TEST_DB/,
  );
});

test('smoke tests allow an explicit local test database', () => {
  assert.doesNotThrow(() => assertSafeDestructiveTestDatabase({
    ALLOW_DESTRUCTIVE_TEST_DB: '1',
    DB_HOST: '127.0.0.1',
    POSTGRES_DB: 'tulpar_test',
  }));
});

test('production database tulpar is always forbidden', () => {
  assert.throws(
    () => assertSafeDestructiveTestDatabase({
      ALLOW_DESTRUCTIVE_TEST_DB: '1',
      DB_HOST: 'localhost',
      POSTGRES_DB: 'tulpar',
    }),
    /Production database tulpar/,
  );
});

test('database name must explicitly end with _test', () => {
  assert.throws(
    () => assertSafeDestructiveTestDatabase({
      ALLOW_DESTRUCTIVE_TEST_DB: '1',
      DB_HOST: 'localhost',
      POSTGRES_DB: 'staging',
    }),
    /must end with _test/,
  );
});

test('production compose host postgres is always forbidden', () => {
  assert.throws(
    () => assertSafeDestructiveTestDatabase({
      ALLOW_DESTRUCTIVE_TEST_DB: '1',
      DB_HOST: 'postgres',
      POSTGRES_DB: 'tulpar_test',
    }),
    /DB_HOST/,
  );
});

test('ambiguous remote hosts fail closed', () => {
  assert.throws(
    () => assertSafeDestructiveTestDatabase({
      ALLOW_DESTRUCTIVE_TEST_DB: '1',
      DB_HOST: 'db.internal',
      POSTGRES_DB: 'tulpar_test',
    }),
    /DB_HOST/,
  );
});

test('production Docker context excludes smoke launchers and backups', async () => {
  const dockerignore = await readFile(
    new URL('../.dockerignore', import.meta.url),
    'utf8',
  );
  assert.match(dockerignore, /^src\/smoke-test\*\.js$/m);
  assert.match(dockerignore, /^src\/\*\.bak-\*$/m);
});
