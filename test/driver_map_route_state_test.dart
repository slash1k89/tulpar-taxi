import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/models/navigation_step.dart';
import 'package:taxi_esil/screens/driver/driver_map_screen.dart';
import 'package:taxi_esil/services/route_service.dart';

const pickup = LatLng(51.95, 66.40);
const destination = LatLng(51.97, 66.42);

Map<String, dynamic> order(String id, String status) => {
  'id': id,
  'status': status,
  'fromLat': pickup.latitude,
  'fromLng': pickup.longitude,
  'toLat': destination.latitude,
  'toLng': destination.longitude,
};

RouteResult result(LatLng target, String street) => RouteResult(
  geometry: [const LatLng(51.94, 66.39), target],
  steps: [
    NavigationStep(
      modifier: 'right',
      type: 'turn',
      targetLat: target.latitude,
      targetLng: target.longitude,
      streetName: street,
    ),
  ],
  distanceMeters: 1000,
  durationSeconds: 120,
);

void main() {
  test('accepted routes to pickup', () {
    expect(driverRouteDestination(order('A', 'accepted')), pickup);
  });

  test('driver_arrived routes to pickup', () {
    expect(driverRouteDestination(order('A', 'driver_arrived')), pickup);
  });

  test('only active navigation statuses can build or reroute', () {
    for (final status in [
      'accepted',
      'driver_arrived',
      'arrived',
      'in_progress',
    ]) {
      expect(driverStatusSupportsNavigation(status), isTrue);
    }
    for (final status in ['completed', 'cancelled', 'expired', null]) {
      expect(driverStatusSupportsNavigation(status), isFalse);
    }
  });

  test('CITY, DELIVERY and old INTERCITY share route destination logic', () {
    for (final serviceType in ['city', 'delivery', 'intercity']) {
      final accepted = {
        ...order(serviceType, 'accepted'),
        'serviceType': serviceType,
      };
      final inProgress = {
        ...order(serviceType, 'in_progress'),
        'serviceType': serviceType,
      };
      expect(driverRouteDestination(accepted), pickup);
      expect(driverRouteDestination(inProgress), destination);
    }
  });

  test('in_progress invalidates pickup and applies destination route', () {
    final state = DriverRouteRequestState();
    final pickupGeneration = state.begin();
    state.complete(pickupGeneration, result(pickup, 'Pickup'));

    final destinationGeneration = state.begin();
    expect(state.geometry, isEmpty);
    expect(state.steps, isEmpty);
    state.complete(destinationGeneration, result(destination, 'Destination'));

    expect(state.geometry.last, destination);
    expect(state.steps.single.streetName, 'Destination');
    expect(state.routeDistanceMeters, 1000);
    expect(state.routeDurationSeconds, 120);
  });

  test('failed in_progress request cannot leave the pickup route visible', () {
    final state = DriverRouteRequestState();
    final pickupGeneration = state.begin();
    state.complete(pickupGeneration, result(pickup, 'Pickup'));

    final destinationGeneration = state.begin();
    state.fail(destinationGeneration);

    expect(state.geometry, isEmpty);
    expect(state.steps, isEmpty);
    expect(state.isLoading, isFalse);
    expect(state.routeDistanceMeters, 0);
    expect(state.routeDurationSeconds, 0);
  });

  test('same status with a new order invalidates and rebuilds its route', () {
    final state = DriverRouteRequestState();
    final orderAGeneration = state.begin();
    state.complete(orderAGeneration, result(pickup, 'Order A'));

    expect(
      driverRouteContextChanged(
        oldOrderId: 'A',
        newOrderId: 'B',
        oldOrderData: order('A', 'accepted'),
        newOrderData: order('B', 'accepted'),
      ),
      isTrue,
    );
    final orderBGeneration = state.begin();
    expect(state.geometry, isEmpty);
    state.complete(orderBGeneration, result(destination, 'Order B'));

    expect(state.steps.single.streetName, 'Order B');
  });

  test('late result from request A cannot overwrite request B', () async {
    final state = DriverRouteRequestState();
    final requestA = Completer<RouteResult>();
    final requestB = Completer<RouteResult>();

    Future<void> load(Completer<RouteResult> source) async {
      final generation = state.begin();
      try {
        state.complete(generation, await source.future);
      } catch (_) {
        state.fail(generation);
      }
    }

    final loadA = load(requestA);
    final loadB = load(requestB);
    requestB.complete(result(destination, 'Order B'));
    await loadB;
    requestA.complete(result(pickup, 'Order A'));
    await loadA;

    expect(state.geometry.last, destination);
    expect(state.steps.single.streetName, 'Order B');
  });

  test('reroute preserves reference route and exposes request state', () {
    final state = DriverRouteRequestState();
    final initial = state.begin();
    state.complete(initial, result(pickup, 'Pickup'));

    final reroute = state.begin(preserveRoute: true, rerouting: true);
    expect(state.geometry.last, pickup);
    expect(state.isRerouting, isTrue);
    state.complete(reroute, result(destination, 'New route'));
    expect(state.geometry.last, destination);
    expect(state.isRerouting, isFalse);
  });

  test(
    'reroute failure keeps reference route and leaves recoverable error',
    () {
      final state = DriverRouteRequestState();
      final initial = state.begin();
      state.complete(initial, result(pickup, 'Pickup'));

      final reroute = state.begin(preserveRoute: true, rerouting: true);
      state.fail(reroute, rerouting: true);
      expect(state.geometry.last, pickup);
      expect(state.isRerouting, isFalse);
      expect(state.rerouteErrorMessage, isNotNull);
    },
  );

  test('late request cannot clear a newer reroute request state', () {
    final state = DriverRouteRequestState();
    final oldRequest = state.begin();
    final reroute = state.begin(preserveRoute: true, rerouting: true);
    expect(state.fail(oldRequest), isFalse);
    expect(state.isRerouting, isTrue);
    expect(state.complete(reroute, result(destination, 'Current')), isTrue);
    expect(state.geometry.last, destination);
  });
}
