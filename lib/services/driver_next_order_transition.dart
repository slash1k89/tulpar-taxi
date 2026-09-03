import '../models/next_order.dart';
import 'tulpar_api_client.dart';

class NextOrderLoadException implements Exception {
  const NextOrderLoadException();
}

class DriverNextOrderTransition {
  DriverNextOrderTransition({required TulparApiClient apiClient})
    : _apiClient = apiClient;

  final TulparApiClient _apiClient;
  int _generation = 0;
  bool _started = false;

  bool shouldSwitch({
    required CompleteOrderResult result,
    required Object? serviceType,
  }) =>
      serviceType?.toString() == 'city' &&
      result.nextOrderActivated &&
      result.nextOrderId?.isNotEmpty == true;

  int? beginOnce() {
    if (_started) return null;
    _started = true;
    return ++_generation;
  }

  void invalidate() {
    _generation++;
  }

  Future<Map<String, dynamic>> loadAcceptedNext({
    required String nextOrderId,
    required int generation,
  }) async {
    Map<String, dynamic>? order;
    try {
      order = await _apiClient.getOrderDetails(nextOrderId);
    } catch (_) {
      order = await _apiClient.getActiveDriverOrder();
    }
    if (generation != _generation ||
        order == null ||
        order['id']?.toString() != nextOrderId ||
        order['status']?.toString() != 'accepted') {
      throw const NextOrderLoadException();
    }
    return order;
  }
}
