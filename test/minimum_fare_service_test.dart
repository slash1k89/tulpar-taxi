import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/services/minimum_fare_service.dart';
import 'package:taxi_esil/services/order_creation_service.dart';

void main() {
  group('Kazakhstan minimum fare boundaries', () {
    final service = MinimumFareService();

    int fareAt(int hour, int minute) => service.minimumFareForKazakhstanTime(
      DateTime(2026, 8, 17, hour, minute),
    );

    test('05:59 is night fare', () => expect(fareAt(5, 59), 700));
    test('06:00 starts day fare', () => expect(fareAt(6, 0), 600));
    test('12:00 is day fare', () => expect(fareAt(12, 0), 600));
    test('21:59 is day fare', () => expect(fareAt(21, 59), 600));
    test('22:00 starts night fare', () => expect(fareAt(22, 0), 700));
    test('23:59 is night fare', () => expect(fareAt(23, 59), 700));

    test('UTC instant is converted to Kazakhstan UTC+5', () {
      expect(service.minimumFareForInstant(DateTime.utc(2026, 8, 17, 17)), 700);
    });
  });

  group('proposed fare keeps only the lower bound', () {
    final service = MinimumFareService();
    final day = DateTime.utc(2026, 8, 17, 7); // 12:00 in Kazakhstan.
    final night = DateTime.utc(2026, 8, 17, 18); // 23:00 in Kazakhstan.

    test(
      'day 500 becomes 600',
      () => expect(service.priceWithMinimum(500, at: day), 600),
    );
    test(
      'day 800 stays 800',
      () => expect(service.priceWithMinimum(800, at: day), 800),
    );
    test(
      'night 600 becomes 700',
      () => expect(service.priceWithMinimum(600, at: night), 700),
    );
    test(
      'night 1000 stays 1000',
      () => expect(service.priceWithMinimum(1000, at: night), 1000),
    );
  });

  test('creation rechecks fare after crossing 22:00', () async {
    var utcNow = DateTime.utc(2026, 8, 17, 16, 59); // 21:59 Kazakhstan.
    final minimumFareService = MinimumFareService(utcNow: () => utcNow);
    final gateway = _RecordingGateway();
    final orderCreationService = OrderCreationService(
      gateway: gateway,
      minimumFareService: minimumFareService,
    );

    expect(orderCreationService.currentMinimumFare, 600);
    expect(orderCreationService.priceWithCurrentMinimum(600), 600);

    utcNow = DateTime.utc(2026, 8, 17, 17, 1); // 22:01 Kazakhstan.

    await expectLater(
      orderCreationService.createOrder(
        fromAddress: 'Точка А',
        toAddress: 'Точка Б',
        price: 600,
        fromPoint: const LatLng(51.957, 66.404),
        toPoint: const LatLng(51.969, 66.421),
        cityId: 'esil',
      ),
      throwsA(
        isA<OrderCreationException>()
            .having(
              (error) => error.failure,
              'failure',
              OrderCreationFailure.belowMinimumFare,
            )
            .having((error) => error.minimumFare, 'minimumFare', 700)
            .having(
              (error) => error.userMessage,
              'userMessage',
              'Минимальная стоимость поездки сейчас — 700 ₸.',
            ),
      ),
    );
    expect(gateway.calls, 0);
  });
}

class _RecordingGateway implements OrderCreationGateway {
  int calls = 0;

  @override
  Future<String> create(OrderDraft draft) async {
    calls++;
    return 'order-1';
  }
}
