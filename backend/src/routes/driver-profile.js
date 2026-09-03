import express from 'express';

// Only verified server-side phone identities can grant automatic approval.
const verifiedWhitelistCte = `WITH verified_whitelist AS (
  SELECT DISTINCT identity.user_id
  FROM auth_phone_identities identity
  JOIN driver_phone_whitelist whitelist
    ON whitelist.phone_normalized = identity.phone_normalized
)`;

export function createDriverProfileRouter({ pool, requireAuth }) {
  const router = express.Router();

  router.get('/me', requireAuth, async (req, res) => {
    try {
      const result = await pool.query(
        `
        SELECT
          dp.user_id,
          dp.status,
          dp.car_model,
          dp.car_color,
          dp.car_number,
          dp.agreement_version,
          dp.agreement_accepted_at,
          dp.created_at,
          dp.updated_at
        FROM driver_profiles dp
        JOIN users u ON u.id = dp.user_id
        WHERE (u.firebase_uid = $1 OR u.id::text = $1)
        `,
        [req.user.uid],
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          error: 'Driver profile not found',
        });
      }

      const profile = result.rows[0];

      res.json({
        userId: profile.user_id,
        status: profile.status,
        carModel: profile.car_model,
        carColor: profile.car_color,
        carNumber: profile.car_number,
        agreementVersion: profile.agreement_version,
        agreementAcceptedAt: profile.agreement_accepted_at,
        createdAt: profile.created_at,
        updatedAt: profile.updated_at,
      });
    } catch (error) {
      console.error('[DriverProfileGet]', error);

      res.status(500).json({
        error: 'Failed to load driver profile',
      });
    }
  });

  router.post('/draft', requireAuth, async (req, res) => {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const userResult = await client.query(
        `
        SELECT id
        FROM users
        WHERE (firebase_uid = $1 OR id::text = $1)
        FOR UPDATE
        `,
        [req.user.uid],
      );

      if (userResult.rows.length === 0) {
        await client.query('ROLLBACK');

        return res.status(409).json({
          error: 'User profile must be synchronized first',
        });
      }

      const userId = userResult.rows[0].id;

      const profileResult = await client.query(
        `
        INSERT INTO driver_profiles (
          user_id,
          status
        )
        VALUES ($1, 'draft')
        ON CONFLICT (user_id)
        DO UPDATE SET
          updated_at = driver_profiles.updated_at
        RETURNING
          user_id,
          status,
          car_model,
          car_color,
          car_number,
          agreement_version,
          agreement_accepted_at,
          created_at,
          updated_at
        `,
        [userId],
      );

      await client.query('COMMIT');

      const profile = profileResult.rows[0];

      res.json({
        userId: profile.user_id,
        status: profile.status,
        carModel: profile.car_model,
        carColor: profile.car_color,
        carNumber: profile.car_number,
        agreementVersion: profile.agreement_version,
        agreementAcceptedAt: profile.agreement_accepted_at,
        createdAt: profile.created_at,
        updatedAt: profile.updated_at,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('[DriverProfileDraft]', error);

      res.status(500).json({
        error: 'Failed to create driver profile',
      });
    } finally {
      client.release();
    }
  });

  router.post('/agreement', requireAuth, async (req, res) => {
    try {
      const version = '1.0';

      const result = await pool.query(
        `
        UPDATE driver_profiles dp
        SET
          agreement_version = $1,
          agreement_accepted_at = now(),
          updated_at = now()
        FROM users u
        WHERE
          dp.user_id = u.id
          AND (u.firebase_uid = $2 OR u.id::text = $2)
          AND dp.status = 'draft'
        RETURNING
          dp.user_id,
          dp.status,
          dp.agreement_version,
          dp.agreement_accepted_at
        `,
        [version, req.user.uid],
      );

      if (result.rows.length === 0) {
        return res.status(409).json({
          error: 'Driver profile is not in draft state',
        });
      }

      const profile = result.rows[0];

      res.json({
        userId: profile.user_id,
        status: profile.status,
        agreementVersion: profile.agreement_version,
        agreementAcceptedAt: profile.agreement_accepted_at,
      });
    } catch (error) {
      console.error('[DriverAgreement]', error);

      res.status(500).json({
        error: 'Failed to accept agreement',
      });
    }
  });

  router.post('/vehicle', requireAuth, async (req, res) => {
    try {
      const carModel = req.body?.carModel?.trim();
      const carColor = req.body?.carColor?.trim();
      const carNumber = req.body?.carNumber?.trim();

      if (!carModel || !carColor || !carNumber) {
        return res.status(400).json({
          error: 'Car model, color and number are required',
        });
      }

      if (
        carModel.length > 100 ||
        carColor.length > 50 ||
        carNumber.length > 30
      ) {
        return res.status(400).json({
          error: 'Vehicle data is too long',
        });
      }

      const result = await pool.query(
        `
        ${verifiedWhitelistCte}
        UPDATE driver_profiles dp
        SET
          car_model = $1,
          car_color = $2,
          car_number = $3,
          status = CASE
            WHEN approved.user_id IS NOT NULL THEN 'active'
            ELSE 'pending'
          END,
          access_exempt = (approved.user_id IS NOT NULL),
          updated_at = now()
        FROM users u
        LEFT JOIN verified_whitelist approved ON approved.user_id = u.id
        WHERE
          dp.user_id = u.id
          AND (u.firebase_uid = $4 OR u.id::text = $4)
          AND dp.status = 'draft'
          AND dp.agreement_accepted_at IS NOT NULL
        RETURNING
          dp.user_id,
          dp.status,
          dp.car_model,
          dp.car_color,
          dp.car_number,
          dp.agreement_version,
          dp.agreement_accepted_at
        `,
        [carModel, carColor, carNumber, req.user.uid],
      );

      if (result.rows.length === 0) {
        return res.status(409).json({
          error: 'Agreement must be accepted before vehicle submission',
        });
      }

      const profile = result.rows[0];

      res.json({
        userId: profile.user_id,
        status: profile.status,
        carModel: profile.car_model,
        carColor: profile.car_color,
        carNumber: profile.car_number,
        agreementVersion: profile.agreement_version,
        agreementAcceptedAt: profile.agreement_accepted_at,
      });
    } catch (error) {
      console.error('[DriverVehicle]', error);

      res.status(500).json({
        error: 'Failed to submit vehicle data',
      });
    }
  });


router.patch('/vehicle-model', requireAuth, async (req, res) => {
  try {
    const rawCarModel = req.body?.carModel;

    if (typeof rawCarModel !== 'string') {
      return res.status(400).json({
        error: 'Car model is required',
      });
    }

    const carModel = rawCarModel.trim();

    if (carModel.length < 1 || carModel.length > 100) {
      return res.status(400).json({
        error: 'Car model must contain from 1 to 100 characters',
      });
    }

    const result = await pool.query(
      `
      ${verifiedWhitelistCte}
      UPDATE driver_profiles dp
      SET
        car_model = $1::varchar(100),
        status = CASE
          WHEN
            dp.status = 'active'
            AND dp.car_model IS DISTINCT FROM $1::varchar(100)
            AND approved.user_id IS NULL
          THEN 'pending'
          ELSE dp.status
        END,
        access_exempt = dp.access_exempt OR (
          dp.status = 'active' AND approved.user_id IS NOT NULL
        ),
        updated_at = now()
      FROM users u
      LEFT JOIN verified_whitelist approved ON approved.user_id = u.id
      WHERE
        dp.user_id = u.id
        AND (u.firebase_uid = $2 OR u.id::text = $2)
      RETURNING
        dp.user_id,
        dp.status,
        dp.car_model,
        dp.car_color,
        dp.car_number,
        dp.agreement_version,
        dp.agreement_accepted_at,
        dp.created_at,
        dp.updated_at
      `,
      [carModel, req.user.uid],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'Driver profile not found',
      });
    }

    const profile = result.rows[0];

    res.json({
      userId: profile.user_id,
      status: profile.status,
      carModel: profile.car_model,
      carColor: profile.car_color,
      carNumber: profile.car_number,
      agreementVersion: profile.agreement_version,
      agreementAcceptedAt: profile.agreement_accepted_at,
      createdAt: profile.created_at,
      updatedAt: profile.updated_at,
    });
  } catch (error) {
    console.error('[DriverVehicleModelUpdate]', error);

    res.status(500).json({
      error: 'Failed to update vehicle model',
    });
  }
});

router.get('/access', requireAuth, async (req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT
        dp.status,
        dp.access_exempt,
        ds.valid_until
      FROM users u
      LEFT JOIN driver_profiles dp
        ON dp.user_id = u.id
      LEFT JOIN LATERAL (
        SELECT valid_until
        FROM driver_subscriptions
        WHERE
          driver_id = u.id
          AND status = 'active'
          AND payment_status = 'paid'
          AND valid_until > now()
        ORDER BY valid_until DESC
        LIMIT 1
      ) ds ON TRUE
      WHERE (u.firebase_uid = $1 OR u.id::text = $1)
      `,
      [req.user.uid],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'User profile not found',
      });
    }

    const row = result.rows[0];

    const profileActive = row.status === 'active';
    const suspended = row.status === 'suspended';
    const subscriptionActive = row.valid_until !== null;
    const accessExempt = row.access_exempt === true;

    res.json({
      profileStatus: row.status,
      profileActive,
      suspended,
      accessExempt,
      subscriptionActive,
      accessGranted:
        profileActive &&
        !suspended &&
        (accessExempt || subscriptionActive),
      validUntil: row.valid_until,
    });
  } catch (error) {
    console.error('[DriverAccess]', error);

    res.status(500).json({
      error: 'Failed to check driver access',
    });
  }
});

router.post('/subscription/create', requireAuth, async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const userResult = await client.query(
      `
      SELECT
        u.id,
        dp.status,
        dp.access_exempt
      FROM users u
      LEFT JOIN driver_profiles dp
        ON dp.user_id = u.id
      WHERE (u.firebase_uid = $1 OR u.id::text = $1)
      FOR UPDATE
      `,
      [req.user.uid],
    );

    if (userResult.rows.length === 0) {
      await client.query('ROLLBACK');

      return res.status(404).json({
        error: 'User profile not found',
      });
    }

    const user = userResult.rows[0];

    if (user.status !== 'active') {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Driver profile is not active',
      });
    }

    if (user.access_exempt === true) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Driver has permanent free access',
      });
    }

    const settingsResult = await client.query(
      `
      SELECT
        driver_access_fee,
        driver_access_hours
      FROM app_settings
      WHERE id = 1
      `,
    );

    const settings = settingsResult.rows[0];

    if (!settings) {
      await client.query('ROLLBACK');

      return res.status(500).json({
        error: 'Driver access settings not found',
      });
    }

    const existingPending = await client.query(
      `
      SELECT
        id,
        amount,
        created_at
      FROM driver_subscriptions
      WHERE
        driver_id = $1
        AND payment_status = 'pending'
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [user.id],
    );

    if (existingPending.rows.length > 0) {
      await client.query('ROLLBACK');

      return res.status(409).json({
        error: 'Pending payment already exists',
        paymentId: existingPending.rows[0].id,
      });
    }

    const result = await client.query(
      `
      INSERT INTO driver_subscriptions (
        driver_id,
        amount,
        starts_at,
        valid_until,
        status,
        payment_status
      )
      VALUES (
        $1,
        $2,
        now(),
        now() + ($3 * interval '1 hour'),
        'active',
        'pending'
      )
      RETURNING
        id,
        amount,
        starts_at,
        valid_until,
        status,
        payment_status,
        created_at
      `,
      [
        user.id,
        settings.driver_access_fee,
        settings.driver_access_hours,
      ],
    );

    await client.query('COMMIT');

    const subscription = result.rows[0];

    res.status(201).json({
      paymentId: subscription.id,
      amount: subscription.amount,
      accessHours: settings.driver_access_hours,
      paymentStatus: subscription.payment_status,
      validUntil: subscription.valid_until,
      createdAt: subscription.created_at,
    });
  } catch (error) {
    await client.query('ROLLBACK');

    console.error('[DriverSubscriptionCreate]', error);

    res.status(500).json({
      error: 'Failed to create driver payment',
    });
  } finally {
    client.release();
  }
});

  return router;
}
