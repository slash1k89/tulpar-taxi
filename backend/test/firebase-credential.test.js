import assert from 'node:assert/strict';
import test from 'node:test';

import {
  defaultServiceAccountPath,
  resolveFirebaseCredential,
} from '../src/firebase-credential.js';

test('mounted Firebase service account is preferred over missing ADC project detection', () => {
  const calls = [];
  const credential = resolveFirebaseCredential({
    credentialPath: '',
    fileExists: (path) => path === defaultServiceAccountPath,
    readFile: (path) => {
      calls.push(path);
      return JSON.stringify({ project_id: 'taxi-esil' });
    },
    certificate: (serviceAccount) => ({ kind: 'cert', serviceAccount }),
    fallback: () => ({ kind: 'adc' }),
  });

  assert.equal(credential.kind, 'cert');
  assert.equal(credential.serviceAccount.project_id, 'taxi-esil');
  assert.deepEqual(calls, [defaultServiceAccountPath]);
});

test('explicit credential path is honored without exposing its contents', () => {
  const credential = resolveFirebaseCredential({
    credentialPath: '/secure/firebase.json',
    fileExists: (path) => path === '/secure/firebase.json',
    readFile: () => JSON.stringify({ project_id: 'explicit-project' }),
    certificate: (serviceAccount) => serviceAccount.project_id,
    fallback: () => 'adc',
  });

  assert.equal(credential, 'explicit-project');
});

test('developer environments without a credential file retain ADC fallback', () => {
  const credential = resolveFirebaseCredential({
    credentialPath: '',
    fileExists: () => false,
    fallback: () => 'adc',
  });

  assert.equal(credential, 'adc');
});
