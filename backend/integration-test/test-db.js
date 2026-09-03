import { Pool } from 'pg';

import { assertSafeDestructiveTestDatabase } from '../src/smoke-test-guard.js';

function required(env, name) {
  const value = String(env[name] ?? '').trim();
  if (!value) throw new Error(`${name} is required for integration tests`);
  return value;
}

export function integrationTestDatabaseConfig(
  env = process.env,
  applicationName = 'tulpar-intercity-integration',
) {
  assertSafeDestructiveTestDatabase(env);
  if (String(env.DATABASE_URL ?? '').trim()) {
    throw new Error(
      'DATABASE_URL is forbidden for integration tests; use explicit test DB variables',
    );
  }

  return {
    host: required(env, 'DB_HOST'),
    port: Number(env.DB_PORT || 5432),
    database: required(env, 'POSTGRES_DB'),
    user: required(env, 'POSTGRES_USER'),
    password: required(env, 'POSTGRES_PASSWORD'),
    application_name: applicationName,
    max: 12,
  };
}

export function createIntegrationPool(applicationName, env = process.env) {
  return new Pool(integrationTestDatabaseConfig(env, applicationName));
}

export async function assertConnectedToSafeTestDatabase(pool, expectedName) {
  const result = await pool.query(
    `SELECT current_database() AS database_name,
            current_setting('server_version_num')::integer AS server_version`,
  );
  const databaseName = result.rows[0]?.database_name;
  if (
    databaseName !== expectedName
    || databaseName === 'tulpar'
    || !databaseName?.endsWith('_test')
  ) {
    throw new Error(`Refusing destructive integration test against ${databaseName}`);
  }
  if (result.rows[0].server_version < 170000) {
    throw new Error('Intercity integration tests require PostgreSQL 17 or newer');
  }
  return result.rows[0];
}

export function stripPsqlMetaCommands(sql) {
  return sql
    .split(/\r?\n/u)
    .filter((line) => !line.trimStart().startsWith('\\'))
    .join('\n');
}

export function splitSqlStatements(sql) {
  return sql
    .split(';')
    .map((statement) => statement.trim())
    .filter(Boolean);
}
