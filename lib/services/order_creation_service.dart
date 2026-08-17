import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

enum OrderCreationFailure {
  notAuthenticated,
  activeOrderExists,
  invalidData,
  permissionDenied,
  unavailable,
  unknown,
}

class OrderCreationException implements Exception {
  const OrderCreationException(this.failure, this.userMessage, {this.cause});

  final OrderCreationFailure failure;
  final String userMessage;
  final Object? cause;

  @override
  String toString() => 'OrderCreationException($failure, cause: $cause)';
}

class OrderDraft {
  const OrderDraft({
    required this.fromAddress,
    required this.toAddress,
    required this.price,
    required this.fromPoint,
    required this.toPoint,
    required this.cityId,
  });

  final String fromAddress;
  final String toAddress;
  final int price;
  final LatLng fromPoint;
  final LatLng toPoint;

  /// Used for validation and diagnostics. The current Firestore schema does
  /// not store a city field, so it is intentionally not serialized.
  final String cityId;

  void validate() {
    final from = fromAddress.trim();
    final to = toAddress.trim();
    final coordinates = [
      fromPoint.latitude,
      fromPoint.longitude,
      toPoint.latitude,
      toPoint.longitude,
    ];

    final coordinatesAreValid =
        coordinates.every((coordinate) => coordinate.isFinite) &&
        fromPoint.latitude >= -90 &&
        fromPoint.latitude <= 90 &&
        toPoint.latitude >= -90 &&
        toPoint.latitude <= 90 &&
        fromPoint.longitude >= -180 &&
        fromPoint.longitude <= 180 &&
        toPoint.longitude >= -180 &&
        toPoint.longitude <= 180;

    if (from.isEmpty ||
        from.length > 300 ||
        to.isEmpty ||
        to.length > 300 ||
        price <= 0 ||
        price > 1000000 ||
        cityId.trim().isEmpty ||
        !coordinatesAreValid) {
      throw const OrderCreationException(
        OrderCreationFailure.invalidData,
        'Проверьте адреса, цену и точки маршрута.',
      );
    }
  }

  Map<String, Object> toFirestore({
    required String passengerId,
    required Object createdAt,
  }) {
    return {
      'passengerId': passengerId,
      'fromAddress': fromAddress.trim(),
      'toAddress': toAddress.trim(),
      'price': price,
      'fromLat': fromPoint.latitude,
      'fromLng': fromPoint.longitude,
      'toLat': toPoint.latitude,
      'toLng': toPoint.longitude,
      'status': 'searching',
      'createdAt': createdAt,
    };
  }
}

abstract interface class OrderCreationGateway {
  Future<String> create(OrderDraft draft);
}

class FirebaseOrderCreationGateway implements OrderCreationGateway {
  FirebaseOrderCreationGateway({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<String> create(OrderDraft draft) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw const OrderCreationException(
        OrderCreationFailure.notAuthenticated,
        'Войдите в аккаунт и повторите попытку.',
      );
    }

    draft.validate();
    final orderRef = _firestore.collection('orders').doc();
    final activeOrderRef = _firestore.collection('active_orders').doc(userId);

    debugPrint(
      '[OrderCreation] start uid=$userId orderId=${orderRef.id} '
      'city=${draft.cityId} from=${draft.fromPoint} to=${draft.toPoint}',
    );

    try {
      final wasCreated = await _firestore.runTransaction<bool>((
        transaction,
      ) async {
        final activeOrder = await transaction.get(activeOrderRef);
        if (activeOrder.exists) {
          // Do not throw a Dart exception from this callback. On Flutter Web
          // it crosses a JS Promise boundary and is boxed as a converted Future.
          return false;
        }

        final createdAt = FieldValue.serverTimestamp();
        transaction.set(
          orderRef,
          draft.toFirestore(passengerId: userId, createdAt: createdAt),
        );
        transaction.set(activeOrderRef, {
          'orderId': orderRef.id,
          'role': 'passenger',
          'status': 'searching',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      });

      if (!wasCreated) {
        throw const OrderCreationException(
          OrderCreationFailure.activeOrderExists,
          'У вас уже есть активный заказ.',
        );
      }

      debugPrint('[OrderCreation] success uid=$userId orderId=${orderRef.id}');
      return orderRef.id;
    } on OrderCreationException catch (error, stackTrace) {
      _logFailure(error, stackTrace, userId: userId, orderId: orderRef.id);
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      _logFailure(error, stackTrace, userId: userId, orderId: orderRef.id);
      final mapped = switch (error.code) {
        'permission-denied' => OrderCreationException(
          OrderCreationFailure.permissionDenied,
          'Не удалось создать заказ. Проверьте вход в аккаунт.',
          cause: error,
        ),
        'unavailable' || 'deadline-exceeded' => OrderCreationException(
          OrderCreationFailure.unavailable,
          'Нет связи с сервером. Попробуйте ещё раз.',
          cause: error,
        ),
        _ => OrderCreationException(
          OrderCreationFailure.unknown,
          'Не удалось создать заказ. Попробуйте ещё раз.',
          cause: error,
        ),
      };
      Error.throwWithStackTrace(mapped, stackTrace);
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace, userId: userId, orderId: orderRef.id);
      Error.throwWithStackTrace(
        OrderCreationException(
          OrderCreationFailure.unknown,
          'Не удалось создать заказ. Попробуйте ещё раз.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  void _logFailure(
    Object error,
    StackTrace stackTrace, {
    required String userId,
    required String orderId,
  }) {
    debugPrint(
      '[OrderCreation] failed uid=$userId orderId=$orderId '
      'type=${error.runtimeType} error=$error',
    );
    debugPrintStack(stackTrace: stackTrace);
  }
}

class OrderCreationService {
  OrderCreationService({OrderCreationGateway? gateway})
    : _gateway = gateway ?? FirebaseOrderCreationGateway();

  final OrderCreationGateway _gateway;
  Future<String>? _inFlight;

  Future<String> createOrder({
    required String fromAddress,
    required String toAddress,
    required int price,
    required LatLng fromPoint,
    required LatLng toPoint,
    required String cityId,
  }) {
    final current = _inFlight;
    if (current != null) return current;

    final draft = OrderDraft(
      fromAddress: fromAddress,
      toAddress: toAddress,
      price: price,
      fromPoint: fromPoint,
      toPoint: toPoint,
      cityId: cityId,
    );
    final operation = _create(draft);
    _inFlight = operation;
    return operation;
  }

  Future<String> _create(OrderDraft draft) async {
    try {
      draft.validate();
      return await _gateway.create(draft);
    } finally {
      _inFlight = null;
    }
  }
}

String orderCreationUserMessage(Object error) {
  return error is OrderCreationException
      ? error.userMessage
      : 'Не удалось создать заказ. Попробуйте ещё раз.';
}
