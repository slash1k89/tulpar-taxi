import express from 'express';

import {
  attemptFirebaseDeletion,
  beginAccountDeletion,
  hasRecentAuthentication,
} from '../account-deletion.js';

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
}) {
  const router = express.Router();

  router.delete('/', requireAuth, async (req, res) => {
    if (req.body && Object.keys(req.body).length !== 0) {
      return res.status(400).json({
        code: 'invalid_request',
        error: 'Request body must be empty',
      });
    }
    if (req.auth?.type === 'tulpar') {
      return res.status(409).json({
        code: 'flash_call_step_up_required',
        error: 'Phone verification is required before account deletion',
      });
    }
    if (!hasRecentAuthentication(req.user.authTime, {
      nowSeconds: nowSeconds(),
    })) {
      return res.status(401).json({
        code: 'recent_login_required',
        error: 'Recent authentication is required',
      });
    }

    try {
      const deletion = await beginDeletion({
        pool,
        firebaseUid: req.user.uid,
      });
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
