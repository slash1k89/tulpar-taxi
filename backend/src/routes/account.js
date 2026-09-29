import express from 'express';

import {
  attemptFirebaseDeletion,
  beginAccountDeletion,
  beginAccountDeletionByUserId,
  hasRecentAuthentication,
} from '../account-deletion.js';
import { verifyPassword } from '../auth/password-service.js';

const BLOCKER_MESSAGES = {
  active_order: 'Finish or cancel your active order first',
  active_driver_order: 'Finish your active driver order first',
  active_ride: 'Finish or cancel your active intercity ride first',
  active_booking: 'Finish or cancel your active booking first',
  active_ride_request: 'Cancel your active ride request first',
};

export function createAccountRouter({
  pool,
  requireAuth,
  deleteFirebaseUser,
  nowSeconds = () => Math.floor(Date.now() / 1000),
  beginDeletion = beginAccountDeletion,
  attemptDeletion = attemptFirebaseDeletion,
  beginPasswordDeletion = beginAccountDeletionByUserId,
  passwordVerifier = verifyPassword,
}) {
  const router = express.Router();

  router.delete('/', requireAuth, async (req, res) => {
    if (req.auth?.type === 'tulpar') {
      const password = req.body?.password;
      if (typeof password !== 'string' || password.length < 8 || password.length > 128) {
        return res.status(400).json({ code: 'password_required', error: 'Current password is required' });
      }
      const credential = await pool.query(
        `SELECT password_hash FROM users
          WHERE id = $1 AND account_status = 'active' LIMIT 1`,
        [req.auth.userId],
      );
      if (!credential.rowCount
        || !await passwordVerifier(password, credential.rows[0].password_hash)) {
        return res.status(401).json({ code: 'wrong_password', error: 'Current password is incorrect' });
      }
    } else {
      if (req.body && Object.keys(req.body).length !== 0) {
        return res.status(400).json({ code: 'invalid_request', error: 'Request body must be empty' });
      }
      if (!hasRecentAuthentication(req.user.authTime, { nowSeconds: nowSeconds() })) {
        return res.status(401).json({ code: 'recent_login_required', error: 'Recent authentication is required' });
      }
    }

    try {
      const deletion = req.auth?.type === 'tulpar'
        ? await beginPasswordDeletion({ pool, userId: req.auth.userId })
        : await beginDeletion({ pool, firebaseUid: req.user.uid });
      if (deletion.kind === 'not_found') {
        return res.status(404).json({
          code: 'account_not_found',
          error: 'Account not found',
        });
      }
      if (deletion.kind === 'blocked') {
        return res.status(409).json({
          code: deletion.code,
          error: BLOCKER_MESSAGES[deletion.code],
        });
      }
      if (deletion.job.status === 'completed') {
        return res.json({ status: 'deleted' });
      }
      if (deletion.job.status === 'failed') {
        return res.status(503).json({
          code: 'account_deletion_manual_recovery_required',
          error: 'Account deletion requires support intervention',
        });
      }

      const outcome = await attemptDeletion({
        pool,
        deleteFirebaseUser,
        job: deletion.job,
      });
      if (outcome.completed) return res.json({ status: 'deleted' });
      if (outcome.status === 'failed') {
        return res.status(503).json({
          code: 'account_deletion_manual_recovery_required',
          error: 'Account deletion requires support intervention',
        });
      }
      return res.status(202).json({ status: 'deletion_pending' });
    } catch (error) {
      console.error('[AccountDeletion] stage=database error=operation_failed');
      return res.status(500).json({
        code: 'account_deletion_failed',
        error: 'Account deletion failed',
      });
    }
  });

  return router;
}
