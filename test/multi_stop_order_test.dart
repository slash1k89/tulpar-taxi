import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/screens/driver/driver_map_screen.dart';
import 'package:taxi_esil/screens/driver/driver_order_screen.dart';
import 'package:taxi_esil/screens/map/map_screen.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/services/active_order_service.dart';
import 'package:taxi_esil/services/order_creation_service.dart';
import 'package:taxi_esil/services/order_route_geometry_cache.dart';
import 'package:taxi_esil/services/route_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/widgets/order_stops_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({'selected_city_id': 'esil'}),
  );
  OrderDraft draft(int count) {
    final stops = List.generate(
      count,
      (index) => OrderDestination(
        address: 'Point ${index + 1}',
        point: LatLng(51.96 + index / 1000, 66.41 + index / 1000),
      ),
    );
    return OrderDraft(
      fromAddress: 'Pickup',
      toAddress: stops.last.address,
      price: 1,
      fromPoint: const LatLng(51.95, 66.40),
      toPoint: stops.last.point,
      cityId: 'esil',
      stops: stops,
    );
  }

  for (final count in [1, 2, 4]) {
    test('$count destination points preserve their order', () {
      final value = draft(count);
      expect(value.validate, returnsNormally);
      expect(
        value.stops.map((stop) => stop.address),
        List.generate(count, (index) => 'Point ${index + 1}'),
      );
    });
  }

  test('fifth destination is rejected', () {
    expect(draft(5).validate, throwsA(isA<OrderCreationException>()));
  });

  test(
    'OSRM request keeps intermediate waypoints in passenger order',
    () async {
      late Uri uri;
      RouteService.apiClient = TulparApiClient(
        tokenProvider: () async => 'token',
        client: MockClient((request) async {
          uri = request.url;
          return http.Response(
            jsonEncode({
              'geometry': [
                {'lat': 51.95, 'lng': 66.40},
                {'lat': 51.98, 'lng': 66.44},
              ],
              'steps': [],
              'distanceMeters': 1,
              'durationSeconds': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await RouteService.fetchRouteGeometry(
        startLat: 51.95,
        startLng: 66.40,
        destLat: 51.98,
        destLng: 66.44,
        intermediatePoints: const [LatLng(51.96, 66.41), LatLng(51.97, 66.42)],
      );
      expect(uri.queryParameters['waypoints'], '66.41,51.96;66.42,51.97');
    },
  );

  testWidgets('passenger can add up to four destinations and remove a stop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapScreen(
          orderCreationService: OrderCreationService(gateway: _NoopGateway()),
          locationProvider: () async => null,
          cityPointValidator: (_, _) async => true,
          showMapTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      final add = find.text('Добавить адрес');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
    }
    expect(find.text('Остановка 1'), findsOneWidget);
    expect(find.text('Остановка 2'), findsOneWidget);
    expect(find.text('Остановка 3'), findsOneWidget);
    expect(find.text('Добавить адрес'), findsNothing);

    final remove = find.byTooltip('Удалить остановку').first;
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump();
    expect(find.text('Остановка 3'), findsNothing);
    expect(find.text('Добавить адрес'), findsOneWidget);
  });

  test('active order restore preserves every stop in sequence', () async {
    final stops = <Map<String, dynamic>>[
      {
        'sequence': 0,
        'address': 'Stop 1',
        'latitude': 51.96,
        'longitude': 66.41,
      },
      {
        'sequence': 1,
        'address': 'Final',
        'latitude': 51.97,
        'longitude': 66.42,
      },
    ];
    final active = await ActiveOrderService(
      apiClient: _ActiveOrderApi(stops),
    ).findCurrentOrderOrThrow();
    expect(active?.orderId, 'order-active');
    final restored = active?.data['stops'] as List<dynamic>?;
    expect(restored?.length, 2);
    expect(restored?.map((stop) => stop['sequence']), [0, 1]);
    expect(restored?.map((stop) => stop['address']), ['Stop 1', 'Final']);
    expect(restored?.map((stop) => stop['latitude']), [51.96, 51.97]);
  });

  for (final count in [1, 2, 4]) {
    testWidgets('driver card displays $count destinations in order', (
      tester,
    ) async {
      final stops = List.generate(
        count,
        (index) => {
          'sequence': index,
          'address': 'Point ${index + 1}',
          'latitude': 51.96 + index / 1000,
          'longitude': 66.41 + index / 1000,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DriverOrderScreen(
            orderId: 'order-1',
            enableTracking: false,
            orderDetailsStream: Stream.value({
              'status': 'accepted',
              'fromAddress': 'Pickup',
              'toAddress': 'Point $count',
              'stops': stops,
            }),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(OrderStopsView), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);
      for (var index = 0; index < count; index++) {
        expect(find.byKey(Key('order_stop_$index')), findsOneWidget);
      }
    });
  }

  testWidgets('legacy order still shows pickup and final destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OrderStopsView(
            orderData: {'fromAddress': 'Pickup', 'toAddress': 'Final'},
          ),
        ),
      ),
    );
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
  });

  test('passenger tracking route keeps intermediate stops in order', () {
    final endpoints = OrderRouteEndpoints.fromOrderData({
      'fromLat': 51.95,
      'fromLng': 66.40,
      'toLat': 51.98,
      'toLng': 66.44,
      'stops': [
        {'latitude': 51.96, 'longitude': 66.41},
        {'latitude': 51.97, 'longitude': 66.42},
        {'latitude': 51.98, 'longitude': 66.44},
      ],
    });
    expect(endpoints?.intermediatePoints, const [
      LatLng(51.96, 66.41),
      LatLng(51.97, 66.42),
    ]);
  });

  test(
    'driver targets each unreached stop and only then final destination',
    () {
      final order = <String, dynamic>{
        'status': 'in_progress',
        'fromLat': 51.95,
        'fromLng': 66.40,
        'toLat': 51.98,
        'toLng': 66.44,
        'stops': <Map<String, dynamic>>[
          {'latitude': 51.96, 'longitude': 66.41, 'reachedAt': null},
          {'latitude': 51.97, 'longitude': 66.42, 'reachedAt': null},
          {'latitude': 51.98, 'longitude': 66.44, 'reachedAt': null},
        ],
      };
      expect(driverRouteDestination(order), const LatLng(51.96, 66.41));
      expect(driverRoutePlan(order).intermediatePoints, const [
        LatLng(51.96, 66.41),
        LatLng(51.97, 66.42),
      ]);
      expect(driverRoutePlan(order).destination, const LatLng(51.98, 66.44));
      expect(hasPendingIntermediateStop(order), isTrue);
      (order['stops'] as List).first['reachedAt'] = 'now';
      expect(driverRouteDestination(order), const LatLng(51.97, 66.42));
      expect(driverRoutePlan(order).intermediatePoints, const [
        LatLng(51.97, 66.42),
      ]);
      (order['stops'] as List)[1]['reachedAt'] = 'now';
      expect(hasPendingIntermediateStop(order), isFalse);
      expect(driverRouteDestination(order), const LatLng(51.98, 66.44));
      expect(driverRoutePlan(order).intermediatePoints, isEmpty);
    },
  );

  test('remaining stops are sorted and reached stops never return', () {
    final plan = driverRoutePlan({
      'status': 'in_progress',
      'fromLat': 51.95,
      'fromLng': 66.40,
      'toLat': 51.99,
      'toLng': 66.45,
      'stops': [
        {'sequence': 3, 'latitude': 51.99, 'longitude': 66.45},
        {
          'sequence': 0,
          'latitude': 51.96,
          'longitude': 66.41,
          'reachedAt': 'now',
        },
        {'sequence': 2, 'latitude': 51.98, 'longitude': 66.44},
        {'sequence': 1, 'latitude': 51.97, 'longitude': 66.42},
      ],
    });
    expect(plan.orderedRemainingPoints, const [
      LatLng(51.97, 66.42),
      LatLng(51.98, 66.44),
      LatLng(51.99, 66.45),
    ]);
  });
}

class _NoopGateway implements OrderCreationGateway {
  @override
  Future<String> create(OrderDraft draft) async => 'order-test';
}

class _ActiveOrderApi extends TulparApiClient {
  _ActiveOrderApi(this.stops);
  final List<Map<String, dynamic>> stops;

  @override
  Future<Map<String, dynamic>?> getActiveCurrentOrder() async => {
    'id': 'order-active',
    'role': 'passenger',
    'status': 'in_progress',
    'pickupAddress': 'Pickup',
    'destinationAddress': 'Final',
    'pickupLat': 51.95,
    'pickupLng': 66.40,
    'destinationLat': 51.97,
    'destinationLng': 66.42,
    'stops': stops,
  };
}
