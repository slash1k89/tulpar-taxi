import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import request from 'supertest';

import {
  createAccessToken,
  verifyAccessToken,
} from '../src/auth/access-token.js';
import { createAccessTokenMiddleware } from '../src/auth/authenticate-access-token.js';
import { OtpChallengeError } from '../src/auth/otp-service.js';
import { PhoneIdentityConflictError } from '../src/auth/phone-identity-service.js';
import { PasswordAuthError } from '../src/auth/password-service.js';
import { normalizeKazakhstanPhone } from '../src/auth/phone-normalization.js';
import { createAuthRouter } from '../src/routes/auth.js';

const secret = 'test-only-auth-route-secret-at-least-32-characters';
const existingUserId = '00000000-0000-4000-8000-000000000010';
const newUserId = '00000000-0000-4000-8000-000000000011';
const challengeId = '00000000-0000-4000-8000-000000000020';

class FakeOtpService {
  consumed = false;

  async createOtpChallenge() {
    return {
      challengeId,
      phoneNormalized: '+77771234567',
      rawOtp: '123456',
      resendAvailableAt: new Date(Date.now() + 60_000),
    };
  }

  async verifyOtpChallenge(id, phone, code) {
    if (id !== challengeId || normalizeKazakhstanPhone(phone) !== '+77771234567') {
      throw new OtpChallengeError('challenge_not_found');
    }
    if (this.consumed) throw new OtpChallengeError('challenge_consumed');
    if (code !== '123456') throw new OtpChallengeError('invalid_code');
    this.consumed = true;
    return { challengeId, phoneNormalized: '+77771234567', verified: true };
  }

  async invalidateOtpChallenge() {
    this.consumed = true;
    return true;
  }

  async createExternalChallenge(phone, { method, provider, requestCode, purpose = 'login' }) {
    const normalized = normalizeKazakhstanPhone(phone);
    const result = await requestCode(normalized);
    if (method !== 'flash_call' || provider !== 'autocall') {
      throw new OtpChallengeError('unsupported_method');
    }
    this.flashCode = result.code;
    this.purpose = purpose;
    this.consumed = false;
    return {
      challengeId,
      phoneNormalized: normalized,
      method,
      expiresAt: new Date(Date.now() + 300_000),
      resendAvailableAt: new Date(Date.now() + 60_000),
    };
  }

  async verifyChallenge(id, phone, code, { method, purpose = 'login' }) {
    if (
      id !== challengeId ||
      normalizeKazakhstanPhone(phone) !== '+77771234567' ||
      method !== 'flash_call'
      || purpose !== this.purpose
    ) {
      throw new OtpChallengeError('challenge_not_found');
    }
    if (this.consumed || code !== this.flashCode) {
      throw new OtpChallengeError('invalid_code');
    }
    this.consumed = true;
    return { challengeId, phoneNormalized: '+77771234567', verified: true };
  }
}

class FakePasswordService {
  constructor() {
    this.passwordHash = null;
    this.context = null;
    this.loginCalls = 0;
  }

  async findVerifiedIdentity() {
    return this.passwordHash === 'missing-identity'
      ? null
      : { user_id: existingUserId, password_hash: this.passwordHash };
  }

  async createVerificationContext(context) {
    this.context = context;
    return 'verified-context-token-012345678901234567890123456789';
  }

  async setPassword({ verificationToken, purpose, password }) {
    if (verificationToken !== 'verified-context-token-012345678901234567890123456789'
      || purpose !== this.context?.purpose) {
      throw new PasswordAuthError('verification_required');
    }
    if (password.length < 8) throw new PasswordAuthError('invalid_password');
    this.passwordHash = password;
    return this.context.userId;
  }

  async login(phone, password) {
    this.loginCalls++;
    return this.passwordHash === password ? existingUserId : null;
  }
}

class FakeIdentityService {
  constructor(userId = existingUserId) {
    this.userId = userId;
    this.conflict = false;
  }

  async resolveVerifiedPhone() {
    if (this.conflict) throw new PhoneIdentityConflictError();
    return { userId: this.userId, created: this.userId === newUserId };
  }
}

class FakeSessionService {
  sessions = new Map();
  createCalls = 0;
  counter = 0;

  _issue(userId, sessionId) {
    const refreshToken = `refresh-${++this.counter}`;
    const accessToken = createAccessToken({ userId, sessionId, secret });
    this.sessions.set(refreshToken, { userId, sessionId, revoked: false });
    return {
      accessToken,
      refreshToken,
      accessTokenExpiresIn: 900,
      sessionId,
    };
  }

  async createSession(userId) {
    this.createCalls += 1;
    return this._issue(userId, '00000000-0000-4000-8000-000000000030');
  }

  async rotateRefreshToken(refreshToken) {
    const current = this.sessions.get(refreshToken);
    if (!current || current.revoked) return null;
    current.revoked = true;
    return this._issue(current.userId, current.sessionId);
  }

  async revokeSession(sessionId, userId) {
    for (const session of this.sessions.values()) {
      if (session.sessionId === sessionId && session.userId === userId) {
        session.revoked = true;
      }
    }
    return true;
  }
}

class FakeSmsSender {
  configured = true;
  sent = [];

  async sendOtp(message) {
    this.sent.push(message);
  }
}

class FakeVerificationProvider {
  configured = true;
  method = 'flash_call';
  provider = 'autocall';
  calls = [];

  async requestVerification(phone) {
    this.calls.push(phone);
    return {
      provider: 'autocall',
      providerRequestId: 'provider-request-1',
      code: '4321',
    };
  }
}

function fixture({ userId = existingUserId, smsConfigured = true } = {}) {
  const otpService = new FakeOtpService();
  const identityService = new FakeIdentityService(userId);
  const sessionService = new FakeSessionService();
  const smsSender = new FakeSmsSender();
  const verificationProvider = new FakeVerificationProvider();
  const passwordService = new FakePasswordService();
  smsSender.configured = smsConfigured;
  const app = express();
  app.use(express.json());
  app.use('/api/auth', createAuthRouter({
    otpService,
    identityService,
    sessionService,
    smsSender,
    authenticateAccessToken: createAccessTokenMiddleware({ secret }),
    verificationProvider,
    passwordService,
  }));
  return {
    app,
    otpService,
    identityService,
    sessionService,
    smsSender,
    verificationProvider,
    passwordService,
  };
}

test('Flash Call request is neutral and never returns provider code', async () => {
  const target = fixture();
  const response = await request(target.app)
    .post('/api/auth/verification/request')
    .send({
      phone: '87771234567',
      method: 'flash_call',
      passengerId: 'attacker',
      code: '9999',
    });
  assert.equal(response.status, 202);
  assert.equal(response.body.method, 'flash_call');
  assert.equal(response.body.challengeId, challengeId);
  assert.equal(JSON.stringify(response.body).includes('4321'), false);
  assert.deepEqual(target.verificationProvider.calls, ['+77771234567']);
});

test('Flash Call verification creates a Tulpar session once', async () => {
  const target = fixture();
  await request(target.app).post('/api/auth/verification/request').send({
    phone: '87771234567', method: 'flash_call',
  });
  const body = {
    challengeId, phone: '87771234567', code: '4321',
    firebaseUid: 'attacker', userId: 'attacker',
  };
  const verified = await request(target.app)
    .post('/api/auth/verification/verify').send(body);
  assert.equal(verified.status, 200);
  assert.equal(verified.body.userId, existingUserId);
  assert.equal(typeof verified.body.accessToken, 'string');
  assert.equal(typeof verified.body.refreshToken, 'string');
  assert.equal((await request(target.app)
    .post('/api/auth/verification/verify').send(body)).status, 401);
  assert.equal(target.sessionService.createCalls, 1);
});

test('password login uses credentials without requesting Flash Call', async () => {
  const target = fixture();
  target.passwordService.passwordHash = 'correct-password';
  const response = await request(target.app).post('/api/auth/login').send({
    phone: '87771234567', password: 'correct-password',
  });
  assert.equal(response.status, 200);
  assert.equal(response.body.userId, existingUserId);
  assert.equal(target.passwordService.loginCalls, 1);
  assert.equal(target.verificationProvider.calls.length, 0);
  assert.equal((await request(target.app).post('/api/auth/login').send({
    phone: '87771234567', password: 'wrong-password',
  })).status, 401);
});

test('setup Flash Call grants a one-use password context, not a session', async () => {
  const target = fixture();
  const requested = await request(target.app).post('/api/auth/verification/request').send({
    phone: '87771234567', method: 'flash_call', purpose: 'setup',
  });
  assert.equal(requested.status, 202);
  const verified = await request(target.app).post('/api/auth/verification/verify').send({
    challengeId, phone: '87771234567', code: '4321', purpose: 'setup',
  });
  assert.equal(verified.status, 200);
  assert.equal(verified.body.purpose, 'setup');
  assert.equal(typeof verified.body.verificationToken, 'string');
  assert.equal(verified.body.accessToken, undefined);
  assert.equal(target.sessionService.createCalls, 0);
  const setup = await request(target.app).post('/api/auth/password/setup').send({
    verificationToken: verified.body.verificationToken,
    password: 'correct-password',
  });
  assert.equal(setup.status, 200);
  assert.equal(setup.body.userId, existingUserId);
  assert.equal(target.sessionService.createCalls, 1);
});

test('reset Flash Call cannot be replayed as setup or bypass verification', async () => {
  const target = fixture();
  target.passwordService.passwordHash = 'old-password';
  await request(target.app).post('/api/auth/verification/request').send({
    phone: '87771234567', method: 'flash_call', purpose: 'reset',
  });
  const wrongPurpose = await request(target.app).post('/api/auth/verification/verify').send({
    challengeId, phone: '87771234567', code: '4321', purpose: 'setup',
  });
  assert.equal(wrongPurpose.status, 401);
  const verified = await request(target.app).post('/api/auth/verification/verify').send({
    challengeId, phone: '87771234567', code: '4321', purpose: 'reset',
  });
  assert.equal(verified.status, 200);
  assert.equal((await request(target.app).post('/api/auth/password/setup').send({
    verificationToken: verified.body.verificationToken,
    password: 'new-password',
  })).status, 400);
  assert.equal((await request(target.app).post('/api/auth/password/reset').send({
    verificationToken: verified.body.verificationToken,
    password: 'new-password',
  })).status, 200);
  assert.equal(target.passwordService.passwordHash, 'new-password');
});

test('Flash Call rejects unsupported method and malformed four-digit code', async () => {
  const target = fixture();
  assert.equal((await request(target.app)
    .post('/api/auth/verification/request')
    .send({ phone: '87771234567', method: 'sms' })).status, 400);
  await request(target.app).post('/api/auth/verification/request').send({
    phone: '87771234567', method: 'flash_call',
  });
  assert.equal((await request(target.app)
    .post('/api/auth/verification/verify').send({
      challengeId, phone: '87771234567', code: '123456',
    })).status, 401);
});

test('OTP request omits raw code and returns neutral response', async () => {
  const { app } = fixture();
  const response = await request(app).post('/api/auth/otp/request').send({
    phone: '+7 (777) 123-45-67', userId: 'attacker', firebaseUid: 'attacker',
  });
  assert.equal(response.status, 202);
  assert.deepEqual(Object.keys(response.body).sort(), [
    'challengeId', 'resendAfterSeconds', 'status',
  ]);
  assert.equal(JSON.stringify(response.body).includes('123456'), false);
});

test('OTP request does not query or disclose user existence', async () => {
  const first = await request(fixture({ userId: existingUserId }).app)
    .post('/api/auth/otp/request').send({ phone: '87771234567' });
  const second = await request(fixture({ userId: newUserId }).app)
    .post('/api/auth/otp/request').send({ phone: '87771234567' });
  assert.deepEqual(first.body, second.body);
});

test('SMS sender receives normalized phone and raw OTP internally', async () => {
  const { app, smsSender } = fixture();
  await request(app).post('/api/auth/otp/request').send({ phone: '87771234567' });
  assert.deepEqual(smsSender.sent, [{ phone: '+77771234567', code: '123456' }]);
});

test('missing SMS provider fails closed without exposing OTP', async () => {
  const response = await request(fixture({ smsConfigured: false }).app)
    .post('/api/auth/otp/request').send({ phone: '87771234567' });
  assert.equal(response.status, 503);
  assert.equal(JSON.stringify(response.body).includes('123456'), false);
});

test('successful SMS send preserves resend cooldown', async () => {
  let active = false;
  const target = fixture();
  target.otpService.createOtpChallenge = async () => {
    if (active) throw new OtpChallengeError('resend_cooldown');
    active = true;
    return {
      challengeId, phoneNormalized: '+77771234567', rawOtp: '123456',
      resendAvailableAt: new Date(Date.now() + 60_000),
    };
  };
  assert.equal((await request(target.app).post('/api/auth/otp/request')
    .send({ phone: '87771234567' })).status, 202);
  assert.equal((await request(target.app).post('/api/auth/otp/request')
    .send({ phone: '87771234567' })).status, 429);
});

test('failed SMS send invalidates challenge and allows immediate retry', async () => {
  let active = false;
  const target = fixture();
  target.otpService.createOtpChallenge = async () => {
    if (active) throw new OtpChallengeError('resend_cooldown');
    active = true;
    return {
      challengeId, phoneNormalized: '+77771234567', rawOtp: '123456',
      resendAvailableAt: new Date(Date.now() + 60_000),
    };
  };
  target.otpService.invalidateOtpChallenge = async () => {
    active = false;
    return true;
  };
  target.smsSender.sendOtp = async () => {
    throw new Error('provider failed');
  };
  assert.equal((await request(target.app).post('/api/auth/otp/request')
    .send({ phone: '87771234567' })).status, 503);
  target.smsSender.sendOtp = async () => {};
  assert.equal((await request(target.app).post('/api/auth/otp/request')
    .send({ phone: '87771234567' })).status, 202);
});

for (const [name, userId] of [
  ['existing user keeps the same users.id', existingUserId],
  ['new user receives the server-created users.id', newUserId],
]) {
  test(`valid OTP: ${name}`, async () => {
    const { app } = fixture({ userId });
    const response = await request(app).post('/api/auth/otp/verify').send({
      challengeId, phone: '87771234567', code: '123456',
      userId: 'attacker', firebaseUid: 'attacker',
    });
    assert.equal(response.status, 200);
    assert.equal(response.body.userId, userId);
    const claims = verifyAccessToken(response.body.accessToken, { secret });
    assert.equal(claims.sub, userId);
    assert.equal(typeof response.body.refreshToken, 'string');
  });
}

test('ambiguous duplicate phone identity is rejected', async () => {
  const target = fixture();
  target.identityService.conflict = true;
  const response = await request(target.app).post('/api/auth/otp/verify').send({
    challengeId, phone: '87771234567', code: '123456',
  });
  assert.equal(response.status, 409);
  assert.equal(target.sessionService.createCalls, 0);
});

test('wrong OTP creates no session', async () => {
  const target = fixture();
  const response = await request(target.app).post('/api/auth/otp/verify').send({
    challengeId, phone: '87771234567', code: '000000',
  });
  assert.equal(response.status, 401);
  assert.equal(target.sessionService.createCalls, 0);
});

test('consumed OTP cannot create a second session', async () => {
  const target = fixture();
  const body = { challengeId, phone: '87771234567', code: '123456' };
  assert.equal((await request(target.app).post('/api/auth/otp/verify').send(body)).status, 200);
  assert.equal((await request(target.app).post('/api/auth/otp/verify').send(body)).status, 401);
  assert.equal(target.sessionService.createCalls, 1);
});

test('malformed challenge UUID is rejected before OTP verification', async () => {
  const target = fixture();
  const response = await request(target.app).post('/api/auth/otp/verify').send({
    challengeId: 'not-a-uuid', phone: '87771234567', code: '123456',
  });
  assert.equal(response.status, 400);
  assert.equal(target.sessionService.createCalls, 0);
});

test('refresh rotates token and rejects reuse of the old token', async () => {
  const target = fixture();
  const login = await request(target.app).post('/api/auth/otp/verify').send({
    challengeId, phone: '87771234567', code: '123456',
  });
  const oldRefresh = login.body.refreshToken;
  const rotated = await request(target.app).post('/api/auth/refresh')
    .send({ refreshToken: oldRefresh });
  assert.equal(rotated.status, 200);
  assert.notEqual(rotated.body.refreshToken, oldRefresh);
  assert.equal((await request(target.app).post('/api/auth/refresh')
    .send({ refreshToken: oldRefresh })).status, 401);
});

test('logout revokes current Tulpar session and is idempotent', async () => {
  const target = fixture();
  const login = await request(target.app).post('/api/auth/otp/verify').send({
    challengeId, phone: '87771234567', code: '123456',
  });
  for (let index = 0; index < 2; index += 1) {
    const response = await request(target.app).post('/api/auth/logout')
      .set('Authorization', `Bearer ${login.body.accessToken}`);
    assert.equal(response.status, 200);
  }
  assert.equal((await request(target.app).post('/api/auth/refresh')
    .send({ refreshToken: login.body.refreshToken })).status, 401);
});
