import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/active_order_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

Map<String, dynamic> _order({String status = 'accepted'}) => {
  'id': 'order-1',
  'role': 'passenger',
  'status': status,
  'serviceType': 'city',
  'pickupAddress': 'Pickup',
  'destinationAddress': 'Destination',
  'pickupLat': 51.9,
  'pickupLng': 66.4,
  'destinationLat': 52.0,
  'destinationLng': 66.5,
};

class _SequenceApi extends TulparApiClient {
  _SequenceApi(this.responses) : super(tokenProvider: () async => 'test');

  final List<Object?> responses;
  var index = 0;

  @override
  Future<Map<String, dynamic>?> getActiveCurrentOrder() async {
    final value = responses[index++];
    if (value is Error) throw value;
    if (value is Exception) throw value;
    return value as Map<String, dynamic>?;
  }
}

void main() {
  setUp(ActiveOrderService.clearRememberedOrder);
  tearDown(ActiveOrderService.clearRememberedOrder);

  test(
    'active order is returned and remembered for the current session',
    () async {
      final service = ActiveOrderService(apiClient: _SequenceApi([_order()]));

      final active = await service.findCurrentOrderOrThrow();

      expect(active?.orderId, 'order-1');
      expect(active?.isDriver, isFalse);
      expect(ActiveOrderService.lastKnownActiveOrder, same(active));
    },
  );

  test(
    'server-confirmed absence returns null and clears the known order',
    () async {
      ActiveOrderService.rememberForCurrentSession(
        ActiveOrder(orderId: 'order-1', isDriver: false, data: _order()),
      );
      final service = ActiveOrderService(apiClient: _SequenceApi([null]));

      expect(await service.findCurrentOrderOrThrow(), isNull);
      expect(ActiveOrderService.lastKnownActiveOrder, isNull);
    },
  );

  for (final status in ['completed', 'cancelled', 'expired']) {
    test('$status is confirmed inactive and clears the known order', () async {
      ActiveOrderService.rememberForCurrentSession(
        ActiveOrder(orderId: 'order-1', isDriver: false, data: _order()),
      );
      final service = ActiveOrderService(
        apiClient: _SequenceApi([_order(status: status)]),
      );

      expect(await service.findCurrentOrderOrThrow(), isNull);
      expect(ActiveOrderService.lastKnownActiveOrder, isNull);
    });
  }

  test('network error remains unknown and preserves the known order', () async {
    final known = ActiveOrder(
      orderId: 'order-1',
      isDriver: false,
      data: _order(),
    );
    ActiveOrderService.rememberForCurrentSession(known);
    final service = ActiveOrderService(
      apiClient: _SequenceApi([
        const TulparApiException(503, 'temporarily unavailable'),
      ]),
    );

    await expectLater(
      service.findCurrentOrderOrThrow(),
      throwsA(isA<TulparApiException>()),
    );
    expect(ActiveOrderService.lastKnownActiveOrder, same(known));
  });

  test(
    'timeout remains unknown and is not converted to confirmed none',
    () async {
      final service = ActiveOrderService(
        apiClient: _SequenceApi([TimeoutException('active order timeout')]),
      );

      await expectLater(
        service.findCurrentOrderOrThrow(),
        throwsA(isA<TimeoutException>()),
      );
      expect(ActiveOrderService.lastKnownActiveOrder, isNull);
    },
  );

  test(
    'best-effort lookup hides errors without clearing known state',
    () async {
      final known = ActiveOrder(
        orderId: 'order-1',
        isDriver: false,
        data: _order(),
      );
      ActiveOrderService.rememberForCurrentSession(known);
      final service = ActiveOrderService(
        apiClient: _SequenceApi([const TulparApiException(500, 'temporary')]),
      );

      expect(await service.findCurrentOrder(), isNull);
      expect(ActiveOrderService.lastKnownActiveOrder, same(known));
    },
  );
}
