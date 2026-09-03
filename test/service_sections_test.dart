import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/app_routes.dart';
import 'package:taxi_esil/models/order_service_type.dart';
import 'package:taxi_esil/screens/driver/driver_screen.dart';
import 'package:taxi_esil/screens/map/map_screen.dart';
import 'package:taxi_esil/services/order_creation_service.dart';
import 'package:taxi_esil/services/push_notification_service.dart';
import 'package:taxi_esil/widgets/app_drawer.dart';

void main() {
  testWidgets('passenger services are separate map sections', (tester) async {
    await _pumpMap(tester, OrderServiceType.city);

    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('order_form_service_title')))
          .data,
      'Такси',
    );
    expect(find.text('Заказать такси'), findsOneWidget);
    expect(
      find.byKey(const Key('delivery_item_description_field')),
      findsNothing,
    );

    await _pumpMap(tester, OrderServiceType.delivery);

    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.byKey(const Key('order_form_service_title')), findsOneWidget);
    expect(find.text('Доставка'), findsOneWidget);
    expect(find.text('Заказать доставку'), findsOneWidget);
    expect(
      find.byKey(const Key('delivery_item_description_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('delivery_recipient_name_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('delivery_recipient_phone_field')),
      findsOneWidget,
    );

    await _pumpMap(tester, OrderServiceType.intercity);

    expect(find.text('Заказать межгород'), findsOneWidget);
    expect(find.byKey(const Key('order_form_service_title')), findsOneWidget);
    expect(find.text('Межгород'), findsWidgets);
    expect(
      find.byKey(const Key('intercity_passenger_count_field')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('intercity_luggage_field')), findsOneWidget);
    expect(
      find.byKey(const Key('delivery_item_description_field')),
      findsNothing,
    );
  });

  testWidgets('passenger drawer opens intercity as its own route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => Scaffold(
            appBar: AppBar(),
            drawer: const AppDrawer(
              mode: AppMode.passenger,
              userLabel: 'passenger',
            ),
          ),
          AppRoutes.delivery: (_) =>
              const Scaffold(body: Text('delivery-section')),
          AppRoutes.intercity: (_) =>
              const Scaffold(body: Text('intercity-section')),
        },
      ),
    );

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Заказать такси'), findsOneWidget);
    expect(find.text('Доставка'), findsOneWidget);
    expect(find.text('Межгород'), findsOneWidget);

    await tester.tap(find.byKey(const Key('drawer_service_intercity')));
    await tester.pumpAndSettle();
    expect(find.text('intercity-section'), findsOneWidget);
  });

  testWidgets('driver drawer exposes combined local work and intercity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          drawer: const AppDrawer(mode: AppMode.driver, userLabel: 'driver'),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('drawer_service_city')), findsOneWidget);
    expect(find.byKey(const Key('drawer_service_delivery')), findsNothing);
    expect(find.text('Такси и доставка'), findsOneWidget);
    expect(find.byKey(const Key('drawer_service_intercity')), findsOneWidget);
    expect(find.text('Скоро'), findsNothing);
  });

  testWidgets('online switch exists only while waiting for orders', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DriverScreen(
          key: const ValueKey('active-driver-order'),
          userId: 'driver-1',
          activeOrdersStream: Stream.value(null),
          availableOrdersStream: Stream.value(const []),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('driver_online_switch')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: DriverScreen(
          key: const ValueKey('accepted-driver-order'),
          userId: 'driver-1',
          activeOrdersStream: Stream.value({
            'id': 'order-1',
            'status': 'accepted',
            'serviceType': 'delivery',
          }),
          availableOrdersStream: Stream.value(const []),
          activeOrderBuilder: (_) => const Scaffold(body: Text('active-order')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('active-order'), findsOneWidget);
    expect(find.byKey(const Key('driver_online_switch')), findsNothing);
  });

  test(
    'driver local lists combine city and delivery, intercity stays separate',
    () {
      final orders = [
        <String, dynamic>{'id': 'city-1', 'serviceType': 'city'},
        <String, dynamic>{'id': 'delivery-1', 'serviceType': 'delivery'},
        <String, dynamic>{'id': 'intercity-1', 'serviceType': 'intercity'},
        <String, dynamic>{'id': 'legacy-city'},
      ];

      expect(
        filterAvailableOrdersForService(
          orders,
          OrderServiceType.city,
        ).map((order) => order['id']),
        ['city-1', 'delivery-1', 'legacy-city'],
      );
      expect(
        filterAvailableOrdersForService(
          orders,
          OrderServiceType.delivery,
        ).map((order) => order['id']),
        ['city-1', 'delivery-1', 'legacy-city'],
      );
      expect(
        filterAvailableOrdersForService(
          orders,
          OrderServiceType.intercity,
        ).map((order) => order['id']),
        ['intercity-1'],
      );
    },
  );

  test('delivery status and push copy uses courier terminology', () {
    expect(
      OrderServiceType.delivery.passengerAcceptedText,
      'Курьер едет за посылкой',
    );
    expect(
      OrderServiceType.delivery.passengerArrivedText,
      'Курьер прибыл за посылкой',
    );
    expect(
      OrderServiceType.delivery.passengerArrivedHint,
      'Передайте посылку курьеру',
    );
    expect(OrderServiceType.delivery.passengerInProgressText, 'Посылка в пути');
    expect(
      OrderServiceType.delivery.passengerCompletedText,
      'Доставка завершена',
    );
    expect(
      passengerPushBody(eventType: 'driver_arrived', serviceType: 'delivery'),
      'Курьер прибыл за посылкой',
    );
    expect(
      passengerPushBody(eventType: 'driver_arrived', serviceType: 'city'),
      'Водитель на месте и ожидает вас!',
    );
  });

  test('intercity status and push copy uses trip terminology', () {
    expect(OrderServiceType.intercity.passengerArrivedText, 'Водитель прибыл');
    expect(
      OrderServiceType.intercity.passengerInProgressText,
      'Поездка началась',
    );
    expect(
      passengerPushBody(eventType: 'completed', serviceType: 'intercity'),
      'Междугородняя поездка завершена',
    );
  });

  test('foreground arrival banner is suppressed', () {
    expect(shouldShowForegroundPushBanner('driver_arrived'), isFalse);
    expect(shouldShowForegroundPushBanner('arrived'), isFalse);
    expect(shouldShowForegroundPushBanner('in_progress'), isTrue);
  });

  test('stale arrival event is rejected after trip advances', () {
    expect(
      shouldAcceptOrderStatusEvent(
        previousRank: orderStatusRank('in_progress'),
        eventType: 'driver_arrived',
      ),
      isFalse,
    );
    expect(
      shouldAcceptOrderStatusEvent(
        previousRank: orderStatusRank('completed'),
        eventType: 'driver_arrived',
      ),
      isFalse,
    );
  });
}

Future<void> _pumpMap(WidgetTester tester, OrderServiceType serviceType) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MapScreen(
        key: ValueKey(serviceType),
        serviceType: serviceType,
        orderCreationService: OrderCreationService(gateway: _NoopGateway()),
        locationProvider: () async => null,
        showMapTiles: false,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

class _NoopGateway implements OrderCreationGateway {
  @override
  Future<String> create(OrderDraft draft) async => 'test-order';
}
