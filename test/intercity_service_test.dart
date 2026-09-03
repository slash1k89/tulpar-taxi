import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/services/order_creation_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/screens/map/map_screen.dart';
import 'package:taxi_esil/models/order_service_type.dart';
import 'package:taxi_esil/widgets/intercity_details_view.dart';

void main() {
  const from = LatLng(51.957, 66.404);
  const to = LatLng(53.214, 63.624);

  test('intercity draft keeps schedule and trip details', () async {
    final gateway = _RecordingGateway();
    final service = OrderCreationService(gateway: gateway);
    final scheduledAt = DateTime.now().toUtc().add(const Duration(days: 1));

    await service.createOrder(
      fromAddress: 'Есиль',
      toAddress: 'Костанай',
      price: 100,
      fromPoint: from,
      toPoint: to,
      cityId: 'esil',
      serviceType: 'intercity',
      intercity: IntercityOrderDetails(
        scheduledAt: scheduledAt,
        passengerCount: 3,
        hasLuggage: true,
        comment: 'Два чемодана',
      ),
    );

    expect(gateway.lastDraft?.serviceType, 'intercity');
    expect(gateway.lastDraft?.intercity?.scheduledAt, scheduledAt);
    expect(gateway.lastDraft?.intercity?.passengerCount, 3);
    expect(gateway.lastDraft?.intercity?.hasLuggage, isTrue);
    expect(gateway.lastDraft?.intercity?.comment, 'Два чемодана');
  });

  test('intercity API payload contains server-backed fields', () {
    final payload = buildOrderCreationPayload(
      serviceType: 'intercity',
      passengerPrice: 5000,
      pickupAddress: 'Есиль',
      destinationAddress: 'Астана',
      pickupLat: from.latitude,
      pickupLng: from.longitude,
      destinationLat: to.latitude,
      destinationLng: to.longitude,
      departureAt: '2026-09-02T09:30:00.000Z',
      passengerCount: 2,
      hasLuggage: true,
      comment: ' Детское кресло ',
    );

    expect(payload['serviceType'], 'intercity');
    expect(payload['departureAt'], '2026-09-02T09:30:00.000Z');
    expect(payload.containsKey('scheduledAt'), isFalse);
    expect(payload['passengerCount'], 2);
    expect(payload['hasLuggage'], isTrue);
    expect(payload['comment'], 'Детское кресло');
    expect(payload.containsKey('itemDescription'), isFalse);
  });

  test('intercity response normalization supports PostgreSQL snake case', () {
    final details = normalizeIntercityData({
      'departure_at': '2026-09-02T09:30:00.000Z',
      'passenger_count': 4,
      'has_luggage': true,
      'comment': 'Багаж',
    });

    expect(details?['scheduledAt'], '2026-09-02T09:30:00.000Z');
    expect(details?['departureAt'], '2026-09-02T09:30:00.000Z');
    expect(details?['passengerCount'], 4);
    expect(details?['hasLuggage'], isTrue);
    expect(details?['comment'], 'Багаж');
  });

  testWidgets('intercity order card shows all passenger trip details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IntercityDetailsView(
            orderData: {
              'serviceType': 'intercity',
              'fromAddress': 'Есиль',
              'toAddress': 'Астана',
              'passengerPrice': 5000,
              'intercity': {
                'scheduledAt': '2026-09-02T09:30:00.000Z',
                'passengerCount': 3,
                'hasLuggage': true,
                'comment': 'Два чемодана',
              },
            },
          ),
        ),
      ),
    );

    expect(find.text('Межгород'), findsOneWidget);
    expect(find.text('Есиль'), findsOneWidget);
    expect(find.text('Астана'), findsOneWidget);
    expect(find.text('Пассажиров: 3'), findsOneWidget);
    expect(find.text('Есть багаж'), findsOneWidget);
    expect(find.text('Комментарий: Два чемодана'), findsOneWidget);
    expect(find.text('Цена: 5000 ₸'), findsOneWidget);
  });

  test('Kazakhstan departure is serialized as the correct UTC instant', () {
    final departure = kazakhstanDepartureUtc(
      year: 2026,
      month: 9,
      day: 2,
      hour: 14,
      minute: 45,
    );

    expect(departure.toIso8601String(), '2026-09-02T09:45:00.000Z');
    expect(formatHourMinute24(8, 5), '08:05');
    expect(formatHourMinute24(21, 10), '21:10');
  });

  test('past departure on the Kazakhstan calendar is rejected', () {
    final details = IntercityOrderDetails(
      scheduledAt: DateTime.utc(2026, 9, 2, 9, 30),
      passengerCount: 1,
      hasLuggage: false,
    );

    expect(
      () => details.validate(now: DateTime.utc(2026, 9, 2, 9, 31)),
      throwsA(isA<OrderCreationException>()),
    );
  });

  test('past departure is rejected before the API gateway', () async {
    final gateway = _RecordingGateway();
    final service = OrderCreationService(gateway: gateway);

    await expectLater(
      service.createOrder(
        fromAddress: 'Есиль',
        toAddress: 'Астана',
        price: 5000,
        fromPoint: from,
        toPoint: to,
        cityId: 'esil',
        serviceType: 'intercity',
        intercity: IntercityOrderDetails(
          scheduledAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
          passengerCount: 1,
          hasLuggage: false,
        ),
      ),
      throwsA(isA<OrderCreationException>()),
    );
    expect(gateway.lastDraft, isNull);
  });

  testWidgets('intercity time is rendered without AM or PM', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          serviceType: OrderServiceType.intercity,
          orderCreationService: OrderCreationService(
            gateway: _RecordingGateway(),
          ),
          locationProvider: () async => null,
          showMapTiles: false,
        ),
      ),
    );
    await tester.pump();

    final timeButton = find.byKey(const Key('intercity_time_field'));
    expect(timeButton, findsOneWidget);
    expect(
      find.descendant(
        of: timeButton,
        matching: find.textContaining(RegExp(r'^\d{2}:\d{2}$')),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp(r'AM|PM', caseSensitive: false)),
      findsNothing,
    );
  });
}

class _RecordingGateway implements OrderCreationGateway {
  OrderDraft? lastDraft;

  @override
  Future<String> create(OrderDraft draft) async {
    lastDraft = draft;
    return 'intercity-order';
  }
}
