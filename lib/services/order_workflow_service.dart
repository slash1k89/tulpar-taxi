import 'package:firebase_auth/firebase_auth.dart';

import '../models/next_order.dart';
import 'tulpar_api_client.dart';
import 'app_identity_service.dart';

class OrderWorkflowException implements Exception {
  const OrderWorkflowException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OrderWorkflowService {
  OrderWorkflowService({FirebaseAuth? auth, TulparApiClient? apiClient})
    : _identity = AppIdentityService(firebaseAuth: auth),
      _apiClient = apiClient ?? TulparApiClient();

  final AppIdentityService _identity;
  final TulparApiClient _apiClient;

  Future<void> acceptOrder(String orderId) async {
    _requireUser();

    try {
      await _apiClient.acceptOrder(orderId);
    } on TulparApiException catch (error) {
      throw OrderWorkflowException(_messageForApiError(error));
    }
  }

  Future<NextOrderAcceptanceResult> acceptNextOrder(String orderId) async {
    _requireUser();

    try {
      return await _apiClient.acceptNextOrder(orderId);
    } on TulparApiException catch (error) {
      throw OrderWorkflowException(_messageForApiError(error));
    }
  }

  Future<void> transitionOrderStatus({
    required String orderId,
    required String nextStatus,
  }) async {
    _requireUser();

    try {
      switch (nextStatus) {
        case 'arrived':
        case 'driver_arrived':
          await _apiClient.driverArrived(orderId);
          break;

        case 'in_progress':
          await _apiClient.startRide(orderId);
          break;

        case 'completed':
          await _apiClient.completeRide(orderId);
          break;

        default:
          throw const OrderWorkflowException('едопустимый статус заказа.');
      }
    } on OrderWorkflowException {
      rethrow;
    } on TulparApiException catch (error) {
      throw OrderWorkflowException(_messageForApiError(error));
    }
  }

  Future<CompleteOrderResult> completeOrder(String orderId) async {
    _requireUser();
    try {
      return await _apiClient.completeRide(orderId);
    } on TulparApiException catch (error) {
      throw OrderWorkflowException(_messageForApiError(error));
    }
  }

  Future<List<Map<String, dynamic>>> advanceOrderStop(String orderId) async {
    _requireUser();
    try {
      return await _apiClient.advanceOrderStop(orderId);
    } on TulparApiException catch (error) {
      throw OrderWorkflowException(_messageForApiError(error));
    }
  }

  Future<void> cancelOrder(
    String orderId, {
    String? reasonCode,
    String? reasonText,
  }) async {
    _requireUser();

    try {
      await _apiClient.cancelOrder(
        orderId,
        reasonCode: reasonCode,
        reasonText: reasonText,
      );
    } on TulparApiException catch (error) {
      throw OrderWorkflowException(_messageForApiError(error));
    }
  }

  Future<void> setDriverOnline(bool online) async {
    _requireUser();

    if (!online) {
      return;
    }

    try {
      // ока отдельный online-флаг на VPS не нужен.
      // тот запрос одновременно проверяет водительский доступ.
      await _apiClient.getAvailableOrders();
    } on TulparApiException catch (error) {
      throw OrderWorkflowException(_messageForApiError(error));
    }
  }

  String _requireUser() {
    final userId = _identity.currentUserId;
    if (userId == null) {
      throw const OrderWorkflowException('ойдите в аккаунт, чтобы продолжить.');
    }
    return userId;
  }

  String _messageForApiError(TulparApiException error) {
    switch (error.statusCode) {
      case 400:
        return error.message;
      case 401:
        return 'ойдите в аккаунт, чтобы продолжить.';
      case 403:
        return 'едостаточно прав для этого действия.';
      case 404:
        return 'аказ не найден.';
      case 409:
        return error.message;
      default:
        return 'е удалось обновить заказ. опробуйте ещё раз.';
    }
  }
}
