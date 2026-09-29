import 'tulpar_api_client.dart';
import '../models/order_stops.dart';

const activeOrderStatuses = {
  'searching',
  'queued',
  'accepted',
  'driver_arriving',
  'arrived',
  'driver_arrived',
  'in_progress',
};

const terminalOrderStatuses = {'completed', 'cancelled', 'expired'};

bool isTerminalOrderStatus(Object? status) =>
    terminalOrderStatuses.contains(status?.toString());

bool isActiveOrderStatusForRole(Object? status, {required bool isDriver}) {
  final value = status?.toString();
  if (!activeOrderStatuses.contains(value)) return false;
  return !(isDriver && value == 'queued');
}

class ActiveOrder {
  const ActiveOrder({
    required this.orderId,
    required this.isDriver,
    required this.data,
  });

  final String orderId;
  final bool isDriver;
  final Map<String, dynamic> data;
}

class ActiveOrderService {
  ActiveOrderService({TulparApiClient? apiClient})
    : _apiClient = apiClient ?? TulparApiClient();

  final TulparApiClient _apiClient;
  static ActiveOrder? _lastKnownActiveOrder;

  static ActiveOrder? get lastKnownActiveOrder => _lastKnownActiveOrder;

  static void rememberForCurrentSession(ActiveOrder order) {
    _lastKnownActiveOrder = order;
  }

  static void clearRememberedOrder() {
    _lastKnownActiveOrder = null;
  }

  Future<ActiveOrder?> findCurrentOrder() async {
    try {
      return await findCurrentOrderOrThrow();
    } catch (_) {
      // Startup recovery remains best-effort when the API is unavailable.
      return null;
    }
  }

  Future<ActiveOrder?> findCurrentOrderOrThrow() async {
    final order = await _apiClient.getActiveCurrentOrder().timeout(
      const Duration(seconds: 4),
    );

    if (order == null) {
      clearRememberedOrder();
      return null;
    }

    final id = order['id']?.toString();
    final role = order['role']?.toString();
    final rawStatus = order['status']?.toString();

    if (id == null || id.isEmpty) {
      throw const FormatException('Active order id is missing');
    }

    if (role != 'passenger' && role != 'driver') {
      throw const FormatException('Active order role is invalid');
    }

    if (isTerminalOrderStatus(rawStatus)) {
      clearRememberedOrder();
      return null;
    }

    if (rawStatus == null ||
        !isActiveOrderStatusForRole(rawStatus, isDriver: role == 'driver')) {
      throw const FormatException('Active order status is invalid');
    }

    final status = rawStatus == 'driver_arrived' ? 'arrived' : rawStatus;

    final data = normalizeOrderStops(<String, dynamic>{
      ...order,

      // ????????????? ?? ?????? Flutter UI.
      'status': status,

      'price': order['agreedPrice'] ?? order['passengerPrice'],

      'fromAddress': order['pickupAddress'],

      'toAddress': order['destinationAddress'],

      'fromLat': order['pickupLat'],

      'fromLng': order['pickupLng'],

      'toLat': order['destinationLat'],

      'toLng': order['destinationLng'],

      'stops': order['stops'],
    });

    final active = ActiveOrder(
      orderId: id,
      isDriver: role == 'driver',
      data: data,
    );
    rememberForCurrentSession(active);
    return active;
  }
}
