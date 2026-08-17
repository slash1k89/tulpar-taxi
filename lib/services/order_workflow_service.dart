import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const _useCloudFunctions = bool.fromEnvironment('USE_CLOUD_FUNCTIONS');

class OrderWorkflowException implements Exception {
  const OrderWorkflowException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Executes order state changes through Firestore transactions in Spark mode.
///
/// Passing `--dart-define=USE_CLOUD_FUNCTIONS=true` preserves the existing
/// callable path for a future Blaze deployment.
class OrderWorkflowService {
  OrderWorkflowService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> acceptOrder(String orderId) {
    if (_useCloudFunctions) return _call('acceptOrder', {'orderId': orderId});
    return _acceptOrderInFirestore(orderId);
  }

  Future<void> transitionOrderStatus({
    required String orderId,
    required String nextStatus,
  }) {
    if (_useCloudFunctions) {
      return _call('transitionOrderStatus', {
        'orderId': orderId,
        'nextStatus': nextStatus,
      });
    }
    return _transitionInFirestore(orderId: orderId, nextStatus: nextStatus);
  }

  Future<void> cancelOrder(String orderId) {
    if (_useCloudFunctions) return _call('cancelOrder', {'orderId': orderId});
    return _cancelInFirestore(orderId);
  }

  Future<void> setDriverOnline(bool online) {
    if (_useCloudFunctions) return _call('setDriverOnline', {'online': online});
    return online ? _verifyDriverRole() : Future<void>.value();
  }

  Future<void> _acceptOrderInFirestore(String orderId) async {
    final user = _requireUser();
    final orderRef = _firestore.collection('orders').doc(orderId);
    final profileRef = _firestore.collection('users').doc(user.uid);
    final driverActiveRef = _firestore.collection('active_orders').doc(user.uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final order = await transaction.get(orderRef);
        final profile = await transaction.get(profileRef);
        final driverActive = await transaction.get(driverActiveRef);
        if (!order.exists) throw const OrderWorkflowException('Заказ не найден.');
        if (!profile.exists || profile.data()?['role'] != 'driver') {
          throw const OrderWorkflowException('Только водитель может принять заказ.');
        }
        if (driverActive.exists) {
          throw const OrderWorkflowException('Сначала завершите текущий заказ.');
        }
        final data = order.data()!;
        if (data['status'] != 'searching') {
          throw const OrderWorkflowException('Этот заказ уже принят другим водителем.');
        }
        if (data['passengerId'] is! String) {
          throw const OrderWorkflowException('Заказ содержит некорректные данные.');
        }
        final passengerActiveRef =
            _firestore.collection('active_orders').doc(data['passengerId'] as String);
        final passengerActive = await transaction.get(passengerActiveRef);
        final driver = profile.data()!;
        transaction.update(orderRef, {
          'driverId': user.uid,
          'driverName': (driver['name'] ?? '').toString(),
          'driverPhone': (driver['phone'] ?? '').toString(),
          'carModel': (driver['carModel'] ?? '').toString(),
          'carColor': (driver['carColor'] ?? '').toString(),
          'carNumber': (driver['carNumber'] ?? '').toString(),
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(driverActiveRef, {
          'orderId': orderId,
          'role': 'driver',
          'status': 'accepted',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (passengerActive.data()?['orderId'] == orderId) {
          transaction.update(passengerActiveRef, {'status': 'accepted'});
        }
      });
    } on OrderWorkflowException {
      rethrow;
    } on FirebaseException catch (_) {
      throw const OrderWorkflowException('Не удалось принять заказ. Попробуйте ещё раз.');
    }
  }

  Future<void> _transitionInFirestore({
    required String orderId,
    required String nextStatus,
  }) async {
    const allowed = {
      'accepted': 'arrived',
      'arrived': 'in_progress',
      'in_progress': 'completed',
    };
    final user = _requireUser();
    final orderRef = _firestore.collection('orders').doc(orderId);
    final trackingRef = orderRef.collection('tracking').doc('current');

    try {
      await _firestore.runTransaction((transaction) async {
        final order = await transaction.get(orderRef);
        if (!order.exists) throw const OrderWorkflowException('Заказ не найден.');
        final data = order.data()!;
        if (data['driverId'] != user.uid ||
            data['passengerId'] is! String ||
            allowed[data['status']] != nextStatus) {
          throw const OrderWorkflowException('Этот переход статуса недоступен.');
        }
        final passengerActiveRef =
            _firestore.collection('active_orders').doc(data['passengerId'] as String);
        final driverActiveRef = _firestore.collection('active_orders').doc(user.uid);
        final passengerActive = nextStatus == 'completed'
            ? await transaction.get(passengerActiveRef)
            : null;
        final driverActive = nextStatus == 'completed'
            ? await transaction.get(driverActiveRef)
            : null;
        final activePassengerForProgress = nextStatus == 'completed'
            ? null
            : await transaction.get(passengerActiveRef);
        final activeDriverForProgress = nextStatus == 'completed'
            ? null
            : await transaction.get(driverActiveRef);
        final timestampField = switch (nextStatus) {
          'arrived' => 'arrivedAt',
          'in_progress' => 'startedAt',
          'completed' => 'completedAt',
          _ => throw const OrderWorkflowException('Неизвестный статус заказа.'),
        };
        transaction.update(orderRef, {
          'status': nextStatus,
          timestampField: FieldValue.serverTimestamp(),
        });
        if (nextStatus == 'completed') {
          transaction.delete(trackingRef);
          if (passengerActive?.data()?['orderId'] == orderId) {
            transaction.delete(passengerActiveRef);
          }
          if (driverActive?.data()?['orderId'] == orderId) {
            transaction.delete(driverActiveRef);
          }
        } else {
          if (activePassengerForProgress?.data()?['orderId'] == orderId) {
            transaction.update(passengerActiveRef, {'status': nextStatus});
          }
          if (activeDriverForProgress?.data()?['orderId'] == orderId) {
            transaction.update(driverActiveRef, {'status': nextStatus});
          }
        }
      });
    } on OrderWorkflowException {
      rethrow;
    } on FirebaseException catch (_) {
      throw const OrderWorkflowException('Не удалось обновить статус заказа.');
    }
  }

  Future<void> _cancelInFirestore(String orderId) async {
    final user = _requireUser();
    final orderRef = _firestore.collection('orders').doc(orderId);
    final trackingRef = orderRef.collection('tracking').doc('current');
    try {
      await _firestore.runTransaction((transaction) async {
        final order = await transaction.get(orderRef);
        if (!order.exists) throw const OrderWorkflowException('Заказ не найден.');
        final data = order.data()!;
        const cancellable = {'searching', 'accepted', 'arrived'};
        if (data['passengerId'] != user.uid || !cancellable.contains(data['status'])) {
          throw const OrderWorkflowException('Отмена этого заказа уже недоступна.');
        }
        final passengerActiveRef = _firestore.collection('active_orders').doc(user.uid);
        final driverId = data['driverId'];
        final driverActiveRef = driverId is String
            ? _firestore.collection('active_orders').doc(driverId)
            : null;
        final passengerActive = await transaction.get(passengerActiveRef);
        final driverActive = driverActiveRef == null ? null : await transaction.get(driverActiveRef);
        transaction.update(orderRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        transaction.delete(trackingRef);
        if (passengerActive.data()?['orderId'] == orderId) {
          transaction.delete(passengerActiveRef);
        }
        if (driverActiveRef != null && driverActive?.data()?['orderId'] == orderId) {
          transaction.delete(driverActiveRef);
        }
      });
    } on OrderWorkflowException {
      rethrow;
    } on FirebaseException catch (_) {
      throw const OrderWorkflowException('Не удалось отменить заказ.');
    }
  }

  Future<void> _verifyDriverRole() async {
    final user = _requireUser();
    final profile = await _firestore.collection('users').doc(user.uid).get();
    if (!profile.exists || profile.data()?['role'] != 'driver') {
      throw const OrderWorkflowException('Только водитель может выйти на линию.');
    }
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw const OrderWorkflowException('Войдите в аккаунт, чтобы продолжить.');
    return user;
  }

  Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(name).call<Map<String, dynamic>>(data);
    } on FirebaseFunctionsException catch (error) {
      throw OrderWorkflowException(_messageFor(error));
    }
  }

  String _messageFor(FirebaseFunctionsException error) {
    String message;
    switch (error.code) {
      case 'unauthenticated':
        message = 'Войдите в аккаунт, чтобы продолжить.';
        break;
      case 'permission-denied':
        message = 'Недостаточно прав для этого действия.';
        break;
      case 'not-found':
        message = 'Заказ не найден.';
        break;
      case 'failed-precondition':
        message = 'Заказ уже изменён или это действие сейчас недоступно.';
        break;
      case 'unavailable':
        message = 'Сервис временно недоступен. Попробуйте ещё раз.';
        break;
      default:
        message = 'Не удалось обновить заказ. Попробуйте ещё раз.';
    }
    return kDebugMode ? '$message [Functions: ${error.code}]' : message;
  }
}
