import 'tulpar_api_client.dart';

const activeOrderStatuses = {
  'searching',
  'queued',
  'accepted',
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

  Future<ActiveOrder?> findCurrentOrder() async {
    try {
      final order = await _apiClient.getActiveCurrentOrder().timeout(
        const Duration(seconds: 4),
      );

      if (order == null) {
        return null;
      }

      final id = order['id']?.toString();
      final role = order['role']?.toString();
      final rawStatus = order['status']?.toString();

      if (id == null || id.isEmpty) {
        return null;
      }

      if (role != 'passenger' && role != 'driver') {
        return null;
      }

      if (rawStatus == null ||
          !isActiveOrderStatusForRole(rawStatus, isDriver: role == 'driver')) {
        return null;
      }

      final status = rawStatus == 'driver_arrived' ? 'arrived' : rawStatus;

      final data = <String, dynamic>{
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
      };

      return ActiveOrder(orderId: id, isDriver: role == 'driver', data: data);
    } catch (_) {
      // ???? ???? ??? ?????? ?? ?????? ??????????? ?????? ??????????.
      return null;
    }
  }
}
