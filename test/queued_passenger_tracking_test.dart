import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/screens/map/order_tracking_screen.dart';
import 'package:taxi_esil/services/active_order_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

const pickup = LatLng(51.95, 66.40);
const destination = LatLng(51.97, 66.42);

Map<String, dynamic> queuedOrder({String status = 'queued'}) => {
  'id': 'queued-order',
  'role': 'passenger',
  'status': status,
  'serviceType': 'city',
  'fromLat': pickup.latitude,
  'fromLng': pickup.longitude,
  'toLat': destination.latitude,
  'toLng': destination.longitude,
  'fromAddress': 'Абая, 15',
  'toAddress': 'Ауэзова, 22',
  'passengerPrice': 1400,
  'agreedPrice': 1600,
  'driverId': 'driver-1',
  'driverName': 'Алексей',
  'carModel': 'Toyota Camry',
  'carNumber': '123 ABC',
  // A field with previous-order data must never affect queued rendering.
  'previousDestinationAddress': 'Секретный адрес',
  'previousDestinationLat': 10.0,
  'previousDestinationLng': 20.0,
};

class CapturingRouteLoader {
  double? startLat;
  double? startLng;
  double? destLat;
  double? destLng;

  Future<List<LatLng>> call({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  }) async {
    this.startLat = startLat;
    this.startLng = startLng;
    this.destLat = destLat;
    this.destLng = destLng;
    return [LatLng(startLat, startLng), LatLng(destLat, destLng)];
  }
}

class ActiveQueuedApi extends TulparApiClient {
  ActiveQueuedApi() : super(tokenProvider: () async => 'test');

  @override
  Future<Map<String, dynamic>?> getActiveCurrentOrder() async => queuedOrder();
}

Future<void> pumpTracking(
  WidgetTester tester, {
  required Stream<Map<String, dynamic>?> stream,
  required Map<String, dynamic> initialData,
  required CapturingRouteLoader routeLoader,
  ValueNotifier<LatLng?>? driverLocation,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OrderTrackingScreen(
        orderId: 'queued-order',
        initialOrderData: initialData,
        orderDataStream: stream,
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

void main() {
  testWidgets('queued CITY has separate state and own order information', (
    tester,
  ) async {
    await pumpTracking(
      tester,
      stream: const Stream.empty(),
      initialData: queuedOrder(),
      routeLoader: CapturingRouteLoader(),
    );
    expect(find.text('Водитель завершает предыдущую поездку'), findsOneWidget);
    expect(
      find.text('После завершения водитель сразу направится к вам.'),
      findsOneWidget,
    );
    expect(find.text('Откуда: Абая, 15'), findsOneWidget);
    expect(find.text('Куда: Ауэзова, 22'), findsOneWidget);
    expect(find.text('Стоимость: 1600 ₸'), findsOneWidget);
    expect(find.textContaining('Toyota Camry'), findsOneWidget);
    expect(find.textContaining('Ищем водителя'), findsNothing);
    expect(find.text('Водитель едет к вам'), findsNothing);
    expect(find.textContaining('Секретный адрес'), findsNothing);
    expect(find.text('Отменить заказ'), findsOneWidget);
    await tester.tap(find.text('Отменить заказ'));
    await tester.pump();
    expect(find.text('Отмена заказа'), findsOneWidget);
    expect(find.text('Вы уверены, что хотите отменить заказ?'), findsOneWidget);
    await tester.tap(find.text('Нет'));
    await tester.pump();
    expect(find.text('Водитель завершает предыдущую поездку'), findsOneWidget);
  });

  testWidgets('queued route uses only passenger own pickup and destination', (
    tester,
  ) async {
    final loader = CapturingRouteLoader();
    await pumpTracking(
      tester,
      stream: const Stream.empty(),
      initialData: queuedOrder(),
      routeLoader: loader,
    );
    expect(loader.startLat, pickup.latitude);
    expect(loader.startLng, pickup.longitude);
    expect(loader.destLat, destination.latitude);
    expect(loader.destLng, destination.longitude);
    expect(loader.destLat, isNot(10.0));
    expect(loader.destLng, isNot(20.0));
  });

  testWidgets('queued uses existing smooth driver marker mechanism', (
    tester,
  ) async {
    final driverLocation = ValueNotifier<LatLng?>(const LatLng(51.96, 66.41));
    addTearDown(driverLocation.dispose);
    await pumpTracking(
      tester,
      stream: const Stream.empty(),
      initialData: queuedOrder(),
      routeLoader: CapturingRouteLoader(),
      driverLocation: driverLocation,
    );
    expect(find.byKey(const Key('passenger_driver_marker')), findsOneWidget);
  });

  testWidgets('queued to accepted automatically uses existing accepted UI', (
    tester,
  ) async {
    final orders = StreamController<Map<String, dynamic>?>.broadcast();
    addTearDown(orders.close);
    await pumpTracking(
      tester,
      stream: orders.stream,
      initialData: queuedOrder(),
      routeLoader: CapturingRouteLoader(),
    );
    expect(find.text('Водитель завершает предыдущую поездку'), findsOneWidget);
    orders.add(queuedOrder(status: 'accepted'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Водитель завершает предыдущую поездку'), findsNothing);
    expect(find.text('Водитель едет к вам'), findsOneWidget);
  });

  test('ActiveOrderService accepts queued passenger but not driver', () async {
    final passenger = await ActiveOrderService(
      apiClient: ActiveQueuedApi(),
    ).findCurrentOrder();
    expect(passenger?.orderId, 'queued-order');
    expect(passenger?.isDriver, isFalse);
    expect(isActiveOrderStatusForRole('queued', isDriver: true), isFalse);
  });
}
