const MAX_ID_LENGTH = 128;

/**
 * Validates a callable identifier.
 * @param {object} data Callable request data.
 * @param {string} field Field name.
 * @param {Function} HttpsError Callable error constructor.
 * @return {string} Validated identifier.
 */
function requireId(data, field, HttpsError) {
  const value = data && data[field];
  if (typeof value !== "string" || value.trim().length === 0 ||
      value.length > MAX_ID_LENGTH) {
    throw new HttpsError(
        "invalid-argument", `${field} must be a non-empty string.`);
  }
  return value;
}

/**
 * Resolves the only rating field the caller is allowed to write.
 * @param {object} params Rating policy inputs.
 * @return {{ratingField: string, targetUserId: string}} Rating target.
 */
function resolveRatingTarget(params) {
  const {uid, targetUserId, score, orderData, HttpsError} = params;
  if (!Number.isInteger(score) || score < 1 || score > 5) {
    throw new HttpsError(
        "invalid-argument", "score must be an integer from 1 to 5.");
  }

  const passengerId = orderData.passengerId;
  const driverId = orderData.driverId;
  if (typeof passengerId !== "string" || typeof driverId !== "string" ||
      passengerId.length === 0 || driverId.length === 0 ||
      passengerId === driverId) {
    throw new HttpsError(
        "failed-precondition", "Order participants are invalid.");
  }
  if (uid === targetUserId) {
    throw new HttpsError("permission-denied", "Self-rating is not allowed.");
  }

  let expectedTargetId;
  let ratingField;
  if (uid === passengerId) {
    expectedTargetId = driverId;
    ratingField = "driverRating";
  } else if (uid === driverId) {
    expectedTargetId = passengerId;
    ratingField = "passengerRating";
  } else {
    throw new HttpsError(
        "permission-denied", "Only order participants can submit a rating.");
  }

  if (targetUserId !== expectedTargetId) {
    throw new HttpsError(
        "permission-denied", "The rating target is not the other participant.");
  }
  if (orderData.status !== "completed") {
    throw new HttpsError(
        "failed-precondition", "Only completed orders can be rated.");
  }
  if (Object.prototype.hasOwnProperty.call(orderData, ratingField)) {
    throw new HttpsError(
        "already-exists", "This participant has already rated the order.");
  }

  return {ratingField, targetUserId: expectedTargetId};
}

/**
 * Calculates normalized rating aggregates for the target profile.
 * @param {object} userData Existing target profile.
 * @param {number} score New score.
 * @return {{rating: number, ratingSum: number, ratingCount: number}} Update.
 */
function calculateRatingAggregate(userData, score) {
  const storedSum = userData.ratingSum;
  const storedCount = userData.ratingCount;
  const ratingSum = typeof storedSum === "number" &&
      Number.isFinite(storedSum) && storedSum >= 0 ? storedSum : 0;
  const ratingCount = Number.isInteger(storedCount) && storedCount >= 0 ?
    storedCount : 0;
  const nextSum = ratingSum + score;
  const nextCount = ratingCount + 1;
  return {
    rating: nextSum / nextCount,
    ratingSum: nextSum,
    ratingCount: nextCount,
  };
}

/**
 * Creates the submitRating callable handler.
 * @param {object} dependencies Firebase dependencies.
 * @return {Function} Callable handler.
 */
function createSubmitRatingHandler(dependencies) {
  const {db, HttpsError} = dependencies;
  return async (data, context) => {
    if (!context.auth || !context.auth.uid) {
      throw new HttpsError(
          "unauthenticated", "Sign in before submitting a rating.");
    }

    const uid = context.auth.uid;
    const orderId = requireId(data, "orderId", HttpsError);
    const targetUserId = requireId(data, "targetUserId", HttpsError);
    const score = data && data.score;
    const orderRef = db.collection("orders").doc(orderId);
    const targetRef = db.collection("users").doc(targetUserId);
    let result;

    await db.runTransaction(async (transaction) => {
      const order = await transaction.get(orderRef);
      if (!order.exists) {
        throw new HttpsError("not-found", "Order not found.");
      }

      const target = resolveRatingTarget({
        uid,
        targetUserId,
        score,
        orderData: order.data(),
        HttpsError,
      });
      const user = await transaction.get(targetRef);
      if (!user.exists) {
        throw new HttpsError("not-found", "Rating target not found.");
      }

      const aggregate = calculateRatingAggregate(user.data(), score);
      transaction.update(targetRef, aggregate);
      transaction.update(orderRef, {[target.ratingField]: score});
      result = {
        orderId,
        targetUserId: target.targetUserId,
        score,
        rating: aggregate.rating,
      };
    });

    return result;
  };
}

module.exports = {
  calculateRatingAggregate,
  createSubmitRatingHandler,
  resolveRatingTarget,
};
