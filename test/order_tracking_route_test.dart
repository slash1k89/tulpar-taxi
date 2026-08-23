import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/screens/map/order_tracking_screen.dart';
import 'package:taxi_esil/widgets/order_route_polyline_layer.dart';

const _start = LatLng(51.9555, 66.4032);
const _middle = LatLng(51.96, 66.41);
const _destination = LatLng(51.97, 66.42);

Map<String, dynamic> _orderData({
  String status = 'searching',
  String? driverId,
}) {
  return {
    'status': status,
    'fromLat': _start.latitude,
    'fromLng': _start.longitude,
    'toLat': _destination.latitude,
    'toLng': _destination.longitude,
    'fromAddress': 'Р СћР С•РЎвЂЎР С”Р В° A',
    'toAddress': 'Р СћР С•РЎвЂЎР С”Р В° B',
    'price': 500,
    if (driverId != null) ...{
      'driverId': driverId,
      'driverName': 'Р вЂ™Р С•Р Т‘Р С‘РЎвЂљР ВµР В»РЎРЉ',
      'carModel': 'Toyota',
      'carNumber': '123 ABC',
    },
  };
}

class _RouteLoader {
  _RouteLoader({this.error});

  final Object? error;
  var calls = 0;

  Future<List<LatLng>> call({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  }) async {
    calls++;
    if (error != null) throw error!;
    return const [_start, _middle, _destination];
  }
}

Future<void> _pumpTrackingScreen(
  WidgetTester tester, {
  required Map<String, dynamic> initialOrderData,
  required Stream<Map<String, dynamic>?> orderStream,
  required _RouteLoader routeLoader,
  ValueNotifier<LatLng?>? driverLocation,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OrderTrackingScreen(
        orderId: 'order-1',
        initialOrderData: initialOrderData,
        orderDataStream: orderStream,
        routeLoader: routeLoader.call,
        driverLocationListenable: driverLocation,
        offersStream: const Stream.empty(),
        showMapTiles: false,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

PolylineLayer _routeLayer(WidgetTester tester) {
  return tester.widget<PolylineLayer>(find.byKey(orderRoutePolylineLayerKey));
}

void main() {
  testWidgets('route and endpoint markers are visible while searching', (
    tester,
  ) async {
    final orders = StreamController<Map<String, dynamic>?>.broadcast();
    final loader = _RouteLoader();
    addTearDown(orders.close);

    await _pumpTrackingScreen(
      tester,
      initialOrderData: _orderData(),
      orderStream: orders.stream,
      routeLoader: loader,
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byKey(orderRoutePolylineLayerKey), findsOneWidget);
    expect(find.byIcon(Icons.person_pin_circle), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsOneWidget);
    expect(_routeLayer(tester).polylines.single.points, [
      _start,
      _middle,
      _destination,
    ]);
    expect(loader.calls, 1);
  });

  testWidgets('order stream update keeps the loaded route', (tester) async {
    final orders = StreamController<Map<String, dynamic>?>.broadcast();
    final loader = _RouteLoader();
    addTearDown(orders.close);

    await _pumpTrackingScreen(
      tester,
      initialOrderData: _orderData(),
      orderStream: orders.stream,
      routeLoader: loader,
    );
    final routeElement = tester.element(find.byKey(orderRoutePolylineLayerKey));

    orders.add(_orderData(status: 'accepted'));
    await tester.pump();

    expect(find.byKey(orderRoutePolylineLayerKey), findsOneWidget);
    expect(
      identical(
        routeElement,
        tester.element(find.byKey(orderRoutePolylineLayerKey)),
      ),
      isTrue,
    );
    expect(loader.calls, 1);
  });

  testWidgets('driver position update does not rebuild the route', (
    tester,
  ) async {
    final orders = StreamController<Map<String, dynamic>?>.broadcast();
    final loader = _RouteLoader();
    final driverLocation = ValueNotifier<LatLng?>(null);
    addTearDown(orders.close);
    addTearDown(driverLocation.dispose);

    await _pumpTrackingScreen(
      tester,
      initialOrderData: _orderData(status: 'accepted', driverId: 'driver-1'),
      orderStream: orders.stream,
      routeLoader: loader,
      driverLocation: driverLocation,
    );
    final routeElement = tester.element(find.byKey(orderRoutePolylineLayerKey));

    driverLocation.value = const LatLng(51.958, 66.407);
    await tester.pump();

    expect(find.byIcon(Icons.local_taxi), findsOneWidget);
    expect(find.byKey(orderRoutePolylineLayerKey), findsOneWidget);
    expect(
      identical(
        routeElement,
        tester.element(find.byKey(orderRoutePolylineLayerKey)),
      ),
      isTrue,
    );
    expect(loader.calls, 1);
  });

  testWidgets(
    'driver coordinates from order updates move the passenger marker',
    (tester) async {
      final orders = StreamController<Map<String, dynamic>?>.broadcast();
      final loader = _RouteLoader();
      addTearDown(orders.close);

      await _pumpTrackingScreen(
        tester,
        initialOrderData: _orderData(status: 'accepted', driverId: 'driver-1'),
        orderStream: orders.stream,
        routeLoader: loader,
      );

      expect(find.byIcon(Icons.local_taxi), findsNothing);

      orders.add({
        ..._orderData(status: 'accepted', driverId: 'driver-1'),
        'driverLat': 51.958,
        'driverLng': 66.407,
      });
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.local_taxi), findsOneWidget);
      expect(loader.calls, 1);
    },
  );

  testWidgets('route service failure uses a direct endpoint line', (
    tester,
  ) async {
    final orders = StreamController<Map<String, dynamic>?>.broadcast();
    final loader = _RouteLoader(error: Exception('offline'));
    addTearDown(orders.close);

    await _pumpTrackingScreen(
      tester,
      initialOrderData: _orderData(),
      orderStream: orders.stream,
      routeLoader: loader,
    );

    expect(_routeLayer(tester).polylines.single.points, [_start, _destination]);
    expect(loader.calls, 1);
  });

  testWidgets('route is restored from active order data after reopening', (
    tester,
  ) async {
    final orders = StreamController<Map<String, dynamic>?>.broadcast();
    final loader = _RouteLoader();
    final activeOrderData = _orderData();
    addTearDown(orders.close);

    await _pumpTrackingScreen(
      tester,
      initialOrderData: activeOrderData,
      orderStream: orders.stream,
      routeLoader: loader,
    );
    expect(find.byKey(orderRoutePolylineLayerKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpTrackingScreen(
      tester,
      initialOrderData: activeOrderData,
      orderStream: orders.stream,
      routeLoader: loader,
    );

    expect(find.byKey(orderRoutePolylineLayerKey), findsOneWidget);
    expect(_routeLayer(tester).polylines.single.points, [
      _start,
      _middle,
      _destination,
    ]);
    expect(loader.calls, 2);
  });
}
