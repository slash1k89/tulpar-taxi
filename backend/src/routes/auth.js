import express from 'express';

import { OtpChallengeError } from '../auth/otp-service.js';
import { PhoneIdentityConflictError } from '../auth/phone-identity-service.js';

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function requestMetadata(req) {
  return {
    requestIp: req.ip ?? null,
    deviceId: typeof req.body?.deviceId === 'string'
      ? req.body.deviceId.trim() || null
      : null,
    deviceName: typeof req.body?.deviceName === 'string'
      ? req.body.deviceName.trim() || null
      : null,
    userAgent: req.get('user-agent') ?? null,
  };
}

function authError(res, status, code, message) {
  return res.status(status).json({ code, error: message });
}

export function createAuthRouter({
  otpService,
  identityService,
  sessionService,
  smsSender,
  authenticateAccessToken,
  verificationProvider,
} = {}) {
  const router = express.Router();

  router.post('/otp/request', async (req, res) => {
    if (!otpService || !smsSender?.configured) {
      return authError(res, 503, 'auth_unavailable', 'Authentication is temporarily unavailable');
    }
    try {
      const challenge = await otpService.createOtpChallenge(
        req.body?.phone,
        requestMetadata(req),
      );
      try {
        await smsSender.sendOtp({
          phone: challenge.phoneNormalized,
          code: challenge.rawOtp,
        });
      } catch (error) {
        try {
          await otpService.invalidateOtpChallenge(challenge.challengeId);
        } catch (_) {}
        throw error;
      }
      const resendAfterSeconds = Math.max(0, Math.ceil(
        (challenge.resendAvailableAt.getTime() - Date.now()) / 1000,
      ));
      return res.status(202).json({
        status: 'accepted',
        challengeId: challenge.challengeId,
        resendAfterSeconds,
      });
    } catch (error) {
      if (error instanceof OtpChallengeError && error.code === 'resend_cooldown') {
        return authError(res, 429, 'resend_cooldown', 'Please wait before requesting another code');
      }
      if (error?.message === 'Invalid Kazakhstan phone number') {
        return authError(res, 400, 'invalid_phone', 'Invalid phone number');
      }
      return authError(res, 503, 'auth_unavailable', 'Authentication is temporarily unavailable');
    }
  });

  router.post('/otp/verify', async (req, res) => {
    const challengeId = req.body?.challengeId;
    if (typeof challengeId !== 'string' || !UUID_PATTERN.test(challengeId)) {
      return authError(res, 400, 'invalid_request', 'Invalid authentication request');
    }
    try {
      const verified = await otpService.verifyOtpChallenge(
        challengeId,
        req.body?.phone,
        req.body?.code,
      );
      const identity = await identityService.resolveVerifiedPhone(
        verified.phoneNormalized,
      );
      const session = await sessionService.createSession(
        identity.userId,
        requestMetadata(req),
      );
      return res.json({
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        accessTokenExpiresIn: session.accessTokenExpiresIn,
        sessionId: session.sessionId,
        userId: identity.userId,
      });
    } catch (error) {
      if (error instanceof PhoneIdentityConflictError) {
        return authError(res, 409, 'identity_conflict', 'Unable to resolve account identity');
      }
      if (error instanceof OtpChallengeError || error?.message === 'Invalid Kazakhstan phone number') {
        return authError(res, 401, 'invalid_otp', 'Invalid or expired verification code');
      }
      return authError(res, 500, 'auth_failed', 'Authentication failed');
    }
  });

  router.post('/verification/request', async (req, res) => {
    if (
      !otpService ||
      !verificationProvider?.configured ||
      verificationProvider.method !== 'flash_call'
    ) {
      return authError(res, 503, 'auth_unavailable', 'Authentication is temporarily unavailable');
    }
    if (req.body?.method !== 'flash_call') {
      return authError(res, 400, 'unsupported_method', 'Unsupported verification method');
    }
    try {
      const challenge = await otpService.createExternalChallenge(
        req.body?.phone,
        {
          method: 'flash_call',
          provider: verificationProvider.provider,
          requestCode: (phone) => verificationProvider.requestVerification(phone),
          metadata: requestMetadata(req),
        },
      );
      const now = Date.now();
      return res.status(202).json({
        status: 'accepted',
        challengeId: challenge.challengeId,
        method: 'flash_call',
        expiresIn: Math.max(0, Math.ceil(
          (challenge.expiresAt.getTime() - now) / 1000,
        )),
        resendAfter: Math.max(0, Math.ceil(
          (challenge.resendAvailableAt.getTime() - now) / 1000,
        )),
      });
    } catch (error) {
      if (error instanceof OtpChallengeError && error.code === 'resend_cooldown') {
        return authError(res, 429, 'resend_cooldown', 'Please wait before requesting another verification');
      }
      if (error?.message === 'Invalid Kazakhstan phone number') {
        return authError(res, 400, 'invalid_phone', 'Invalid phone number');
      }
      return authError(res, 503, 'auth_unavailable', 'Authentication is temporarily unavailable');
    }
  });

  router.post('/verification/verify', async (req, res) => {
    const challengeId = req.body?.challengeId;
    if (typeof challengeId !== 'string' || !UUID_PATTERN.test(challengeId)) {
      return authError(res, 400, 'invalid_request', 'Invalid authentication request');
    }
    try {
      const verified = await otpService.verifyChallenge(
        challengeId,
        req.body?.phone,
        req.body?.code,
        { method: 'flash_call' },
      );
      const identity = await identityService.resolveVerifiedPhone(
        verified.phoneNormalized,
      );
      const session = await sessionService.createSession(
        identity.userId,
        requestMetadata(req),
      );
      return res.json({
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        accessTokenExpiresIn: session.accessTokenExpiresIn,
        sessionId: session.sessionId,
        userId: identity.userId,
        profileRequired: identity.created,
      });
    } catch (error) {
      if (error instanceof PhoneIdentityConflictError) {
        return authError(res, 409, 'identity_conflict', 'Unable to resolve account identity');
      }
      if (error instanceof OtpChallengeError || error?.message === 'Invalid Kazakhstan phone number') {
        return authError(res, 401, 'invalid_verification', 'Invalid or expired verification code');
      }
      return authError(res, 500, 'auth_failed', 'Authentication failed');
    }
  });

  router.post('/refresh', async (req, res) => {
    try {
      const rotated = await sessionService.rotateRefreshToken(
        req.body?.refreshToken,
        requestMetadata(req),
      );
      if (!rotated) {
        return authError(res, 401, 'invalid_refresh_token', 'Invalid or expired refresh token');
      }
      return res.json({
        accessToken: rotated.accessToken,
        refreshToken: rotated.refreshToken,
        accessTokenExpiresIn: rotated.accessTokenExpiresIn,
        sessionId: rotated.sessionId,
      });
    } catch (_) {
      return authError(res, 401, 'invalid_refresh_token', 'Invalid or expired refresh token');
    }
  });

  router.post('/logout', authenticateAccessToken, async (req, res) => {
    try {
      await sessionService.revokeSession(req.auth.sessionId, req.auth.userId);
      return res.json({ status: 'logged_out' });
    } catch (_) {
      return authError(res, 500, 'logout_failed', 'Unable to log out');
    }
  });

  return router;
}
