const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const rtdb = admin.database();
const {FieldValue} = admin.firestore;
const {createSubmitRatingHandler} = require("./rating");

/**
 * Grants both order participants access to the active location node.
 * @param {string} orderId Order ID.
 * @param {string} passengerId Passenger UID.
 * @param {string} driverId Driver UID.
 * @return {Promise<void>} Resolves after RTDB access is granted.
 */
async function grantTrackingAccess(orderId, passengerId, driverId) {
  await rtdb.ref().update({
    [`order_tracking_acl/${orderId}/${passengerId}`]: true,
    [`order_tracking_acl/${orderId}/${driverId}`]: true,
    [`driver_active_order/${driverId}`]: orderId,
  });
}

/**
 * Removes active trip coordinates and the associated access list.
 * @param {string} orderId Order ID.
 * @param {string} driverId Driver UID.
 * @return {Promise<void>} Resolves after RTDB tracking data is removed.
 */
async function removeTrackingAccess(orderId, driverId) {
  const updates = {
    [`active_order_locations/${orderId}`]: null,
    [`order_tracking_acl/${orderId}`]: null,
  };
  if (driverId) {
    updates[`driver_active_order/${driverId}`] = null;
  }
  await rtdb.ref().update(updates);
}

/**
 * Validates the callable request's order identifier.
 * @param {object} data Callable request data.
 * @return {string} Validated order ID.
 */
function requireOrderId(data) {
  const orderId = data && data.orderId;
  if (typeof orderId !== "string" ||
      orderId.trim().length === 0 || orderId.length > 128) {
    throw new functions.https.HttpsError(
        "invalid-argument", "orderId must be a non-empty string.");
  }
  return orderId;
}

/**
 * Returns the authenticated caller's UID.
 * @param {object} context Callable request context.
 * @return {string} Authenticated UID.
 */
function requireAuthenticated(context) {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
        "unauthenticated", "Sign in before changing an order.");
  }
  return context.auth.uid;
}

/**
 * Converts an approved driver's private profile to a ride snapshot.
 * @param {FirebaseFirestore.DocumentSnapshot} profile Driver profile document.
 * @param {string} uid Driver UID.
 * @return {object} Public driver snapshot for an order.
 */
function requireDriverProfile(profile, uid) {
  if (!profile.exists || profile.data().role !== "driver") {
    throw new functions.https.HttpsError(
        "permission-denied", "Only approved drivers can accept orders.");
  }

  const data = profile.data();
  const fields = ["name", "phone", "carModel", "carColor", "carNumber"];
  const hasMissingField = fields.some((field) =>
    typeof data[field] !== "string" || data[field].trim().length === 0);
  if (hasMissingField) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Complete the driver profile before accepting orders.");
  }

  return {
    driverId: uid,
    driverName: data.name.trim(),
    driverPhone: data.phone.trim(),
    carModel: data.carModel.trim(),
    carColor: data.carColor.trim(),
    carNumber: data.carNumber.trim(),
  };
}

exports.submitRating = functions.https.onCall(createSubmitRatingHandler({
  db,
  HttpsError: functions.https.HttpsError,
}));

exports.acceptOrder = functions.https.onCall(async (data, context) => {
  const orderId = requireOrderId(data);
  const uid = requireAuthenticated(context);
  const orderRef = db.collection("orders").doc(orderId);
  const driverRef = db.collection("users").doc(uid);
  const onlineSnapshot = await rtdb.ref(
      `driver_presence/${uid}/online`).once("value");
  if (onlineSnapshot.val() !== true) {
    throw new functions.https.HttpsError(
        "failed-precondition", "Go online before accepting an order.");
  }
  let passengerId;

  await db.runTransaction(async (transaction) => {
    const [order, driverProfile] = await Promise.all([
      transaction.get(orderRef),
      transaction.get(driverRef),
    ]);

    if (!order.exists) {
      throw new functions.https.HttpsError("not-found", "Order not found.");
    }
    if (order.data().status !== "searching") {
      throw new functions.https.HttpsError(
          "failed-precondition",
          "This order has already been taken or closed.");
    }

    const driver = requireDriverProfile(driverProfile, uid);
    passengerId = order.data().passengerId;
    transaction.update(orderRef, {
      ...driver,
      status: "accepted",
      acceptedAt: FieldValue.serverTimestamp(),
    });
  });

  await grantTrackingAccess(orderId, passengerId, uid);

  return {orderId, status: "accepted"};
});

exports.transitionOrderStatus = functions.https.onCall(
    async (data, context) => {
      const orderId = requireOrderId(data);
      const uid = requireAuthenticated(context);
      const nextStatus = data && data.nextStatus;
      const validTransitions = {
        accepted: "arrived",
        arrived: "in_progress",
        in_progress: "completed",
      };

      if (typeof nextStatus !== "string" ||
          !Object.values(validTransitions).includes(nextStatus)) {
        throw new functions.https.HttpsError(
            "invalid-argument", "Invalid next order status.");
      }

      const orderRef = db.collection("orders").doc(orderId);
      const driverRef = db.collection("users").doc(uid);

      await db.runTransaction(async (transaction) => {
        const [order, driverProfile] = await Promise.all([
          transaction.get(orderRef),
          transaction.get(driverRef),
        ]);

        if (!order.exists) {
          throw new functions.https.HttpsError("not-found", "Order not found.");
        }
        requireDriverProfile(driverProfile, uid);

        const orderData = order.data();
        if (orderData.driverId !== uid ||
            validTransitions[orderData.status] !== nextStatus) {
          throw new functions.https.HttpsError(
              "failed-precondition", "This status transition is not allowed.");
        }

        const timestampField = {
          arrived: "arrivedAt",
          in_progress: "startedAt",
          completed: "completedAt",
        }[nextStatus];
        transaction.update(orderRef, {
          status: nextStatus,
          [timestampField]: FieldValue.serverTimestamp(),
        });
      });

      if (nextStatus === "completed") {
        await removeTrackingAccess(orderId, uid);
      }

      return {orderId, status: nextStatus};
    });

exports.cancelOrder = functions.https.onCall(async (data, context) => {
  const orderId = requireOrderId(data);
  const uid = requireAuthenticated(context);
  const orderRef = db.collection("orders").doc(orderId);
  let driverId;

  await db.runTransaction(async (transaction) => {
    const order = await transaction.get(orderRef);
    if (!order.exists) {
      throw new functions.https.HttpsError("not-found", "Order not found.");
    }

    const orderData = order.data();
    if (orderData.passengerId !== uid) {
      throw new functions.https.HttpsError(
          "permission-denied", "Only the passenger can cancel this order.");
    }
    if (!["searching", "accepted", "arrived"].includes(orderData.status)) {
      throw new functions.https.HttpsError(
          "failed-precondition", "The order can no longer be cancelled.");
    }

    driverId = orderData.driverId;

    transaction.update(orderRef, {
      status: "cancelled",
      cancelledAt: FieldValue.serverTimestamp(),
    });
  });

  if (driverId) {
    await removeTrackingAccess(orderId, driverId);
  }

  return {orderId, status: "cancelled"};
});

exports.setDriverOnline = functions.https.onCall(async (data, context) => {
  const uid = requireAuthenticated(context);
  const online = data && data.online;
  if (typeof online !== "boolean") {
    throw new functions.https.HttpsError(
        "invalid-argument", "online must be a boolean.");
  }

  const profile = await db.collection("users").doc(uid).get();
  requireDriverProfile(profile, uid);

  const updates = {
    [`driver_presence/${uid}`]: online ? {
      online: true,
      updatedAt: admin.database.ServerValue.TIMESTAMP,
    } : null,
  };
  if (!online) {
    const activeOrder = await rtdb.ref(
        `driver_active_order/${uid}`).once("value");
    if (activeOrder.exists()) {
      updates[`active_order_locations/${activeOrder.val()}/${uid}`] = null;
    }
  }
  await rtdb.ref().update(updates);
  return {online};
});

exports.sendChatNotification = functions.firestore
    .document("orders/{orderId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      const messageData = snap.data();
      const senderId = messageData.senderId;
      const text = messageData.text || "Новое сообщение";
      const orderId = context.params.orderId;

      try {
      // 1. Получаем заказ для определения passengerId и driverId
        const orderDoc = await db.collection("orders").doc(orderId).get();
        if (!orderDoc.exists) return null;

        const orderData = orderDoc.data();

        if (senderId !== orderData.driverId &&
            senderId !== orderData.passengerId) {
          console.error("Message sender is not an order participant.");
          return null;
        }

        // 2. Определяем второго участника заказа.
        const receiverId = (senderId === orderData.driverId) ?
        orderData.passengerId :
        orderData.driverId;

        if (!receiverId || receiverId === senderId) return null;

        // 3. Получаем все устройства второго участника, а не один токен.
        const tokenSnapshots = await db.collection("users").doc(receiverId)
            .collection("fcmTokens").limit(500).get();
        const tokens = tokenSnapshots.docs
            .map((doc) => doc.data().token)
            .filter((token) => typeof token === "string" && token.length > 0);
        if (tokens.length === 0) return null;

        // 4. Заголовок зависимости от роли отправителя
        const title = senderId === orderData.driverId ?
          "Водитель" : "Пассажир";

        // 5. Отправляем каждому устройству получателя и удаляем только
        // токены, которые FCM признал недействительными.
        const response = await admin.messaging().sendEachForMulticast({
          tokens: tokens,
          notification: {title: title, body: text},
          data: {orderId: orderId, type: "chat"},
          android: {priority: "high"},
        });
        const invalidTokens = [];
        response.responses.forEach((result, index) => {
          const code = result.error && result.error.code;
          if (code === "messaging/registration-token-not-registered" ||
              code === "messaging/invalid-registration-token") {
            invalidTokens.push(tokens[index]);
          } else if (!result.success) {
            console.error("Chat notification delivery failed:", result.error);
          }
        });
        await Promise.all(invalidTokens.map((token) => db.collection("users")
            .doc(receiverId).collection("fcmTokens").doc(token).delete()));
        return null;
      } catch (error) {
        console.error("Ошибка отправки push-уведомления:", error);
        return null;
      }
    });
