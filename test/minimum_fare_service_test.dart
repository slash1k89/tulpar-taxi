import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/services/order_creation_service.dart';

void main() {
  group('passenger price has no minimum fare', () {
    for (final price in [1, 100, 599]) {
      test('accepts positive price $price', () async {
        final gateway = _RecordingGateway();
        final service = OrderCreationService(gateway: gateway);
        await service.createOrder(
          fromAddress: 'Точка А',
          toAddress: 'Точка Б',
          price: price,
          fromPoint: const LatLng(51.957, 66.404),
          toPoint: const LatLng(51.969, 66.421),
          cityId: 'esil',
        );
        expect(gateway.lastDraft?.price, price);
      });
    }

    for (final price in [0, -1]) {
      test('rejects non-positive price $price', () async {
        final gateway = _RecordingGateway();
        final service = OrderCreationService(gateway: gateway);
        await expectLater(
          service.createOrder(
            fromAddress: 'Точка А',
            toAddress: 'Точка Б',
            price: price,
            fromPoint: const LatLng(51.957, 66.404),
            toPoint: const LatLng(51.969, 66.421),
            cityId: 'esil',
          ),
          throwsA(isA<OrderCreationException>()),
        );
        expect(gateway.lastDraft, isNull);
      });
    }
  });
}

class _RecordingGateway implements OrderCreationGateway {
  OrderDraft? lastDraft;

  @override
  Future<String> create(OrderDraft draft) async {
    lastDraft = draft;
    return 'order-1';
  }
}
