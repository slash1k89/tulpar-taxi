import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/services/active_order_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

TulparApiClient clientFor(
  Future<http.Response> Function(http.Request request) handler,
) {
  return TulparApiClient(
    client: MockClient(handler),
    tokenProvider: () async => 'test-token',
  );
}

void main() {
  test('queued status and snake_case queued-after field normalize safely', () {
    final queued = normalizeOrderLifecycleData({
      'id': 'next-1',
      'status': 'queued',
      'queued_after_order_id': 'current-1',
    });
    expect(queued['status'], 'queued');
    expect(queued['queuedAfterOrderId'], 'current-1');
    expect(isTerminalOrderStatus(queued['status']), isFalse);
    expect(isActiveOrderStatusForRole('queued', isDriver: false), isTrue);
    expect(isActiveOrderStatusForRole('queued', isDriver: true), isFalse);
  });

  test('ordinary orders without queued-after remain backward compatible', () {
    for (final status in ['searching', 'accepted']) {
      final order = normalizeOrderLifecycleData({'id': '1', 'status': status});
      expect(order['status'], status);
      expect(order['queuedAfterOrderId'], isNull);
      expect(isTerminalOrderStatus(status), isFalse);
    }
    expect(isTerminalOrderStatus('completed'), isTrue);
    expect(isTerminalOrderStatus('cancelled'), isTrue);
  });

  test('GET next-candidates parses compact backend response', () async {
    final api = clientFor((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/orders/next-candidates');
      expect(request.headers['authorization'], 'Bearer test-token');
      return http.Response(
        jsonEncode([
          {
            'id': 'next-1',
            'pickupAddress': 'Абая, 1',
            'destinationAddress': 'Ауэзова, 2',
            'passengerPrice': 1500,
            'distanceToCurrentDestinationMeters': 250,
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final candidates = await api.getNextOrderCandidates();
    expect(candidates, hasLength(1));
    expect(candidates.single.orderId, 'next-1');
    expect(candidates.single.pickupAddress, 'Абая, 1');
    expect(candidates.single.destinationAddress, 'Ауэзова, 2');
    expect(candidates.single.passengerPrice, 1500);
    expect(candidates.single.distanceToCurrentDestinationMeters, 250);
  });

  test('empty next-candidates response becomes empty list', () async {
    final api = clientFor((_) async => http.Response('[]', 200));
    expect(await api.getNextOrderCandidates(), isEmpty);
  });

  test(
    'acceptNextOrder uses authenticated endpoint and parses queued result',
    () async {
      final api = clientFor((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/orders/next-42/accept-next');
        expect(request.headers['authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'id': 'next-42',
            'status': 'queued',
            'driverId': 'driver-1',
            'queuedAfterOrderId': 'current-1',
            'passengerPrice': 1200,
            'agreedPrice': 1200,
            'distanceToCurrentDestinationMeters': 180,
          }),
          200,
        );
      });

      final result = await api.acceptNextOrder('next-42');
      expect(result.orderId, 'next-42');
      expect(result.status, 'queued');
      expect(result.driverId, 'driver-1');
      expect(result.queuedAfterOrderId, 'current-1');
      expect(result.agreedPrice, 1200);
      expect(result.distanceToCurrentDestinationMeters, 180);
    },
  );

  test('complete response parses activated next order', () async {
    final api = clientFor((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/orders/current-1/complete');
      return http.Response(
        jsonEncode({
          'id': 'current-1',
          'status': 'completed',
          'nextOrderActivated': true,
          'nextOrderId': 'next-1',
        }),
        200,
      );
    });
    final result = await api.completeRide('current-1');
    expect(result.nextOrderActivated, isTrue);
    expect(result.nextOrderId, 'next-1');
  });

  test(
    'legacy complete response defaults next fields to false and null',
    () async {
      final api = clientFor(
        (_) async => http.Response(
          jsonEncode({'id': 'current-1', 'status': 'completed'}),
          200,
        ),
      );
      final result = await api.completeRide('current-1');
      expect(result.nextOrderActivated, isFalse);
      expect(result.nextOrderId, isNull);
    },
  );
}
