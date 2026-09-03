import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/models/navigation_step.dart';
import 'package:taxi_esil/models/next_order.dart';
import 'package:taxi_esil/screens/driver/driver_map_screen.dart';
import 'package:taxi_esil/services/driver_next_order_transition.dart';
import 'package:taxi_esil/services/route_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

const nextPickup = LatLng(51.95, 66.40);
const nextDestination = LatLng(51.97, 66.42);

CompleteOrderResult completion({
  bool activated = true,
  String? nextId = 'next',
}) => CompleteOrderResult(
  orderId: 'current',
  status: 'completed',
  nextOrderActivated: activated,
  nextOrderId: nextId,
);

Map<String, dynamic> nextOrder({String status = 'accepted'}) => {
  'id': 'next',
  'serviceType': 'city',
  'status': status,
  'fromLat': nextPickup.latitude,
  'fromLng': nextPickup.longitude,
  'toLat': nextDestination.latitude,
  'toLng': nextDestination.longitude,
};

class FakeTransitionApi extends TulparApiClient {
  FakeTransitionApi() : super(tokenProvider: () async => 'test');

  Map<String, dynamic>? details = nextOrder();
  Map<String, dynamic>? active;
  Object? detailsError;
  int detailsCalls = 0;
  int activeCalls = 0;
  int acceptNextCalls = 0;

  @override
  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    detailsCalls++;
    if (detailsError != null) throw detailsError!;
    return details!;
  }

  @override
  Future<Map<String, dynamic>?> getActiveDriverOrder() async {
    activeCalls++;
    return active;
  }

  @override
  Future<NextOrderAcceptanceResult> acceptNextOrder(String orderId) async {
    acceptNextCalls++;
    throw StateError('accept-next must not be called during activation switch');
  }
}

void main() {
  test('no-next completion and non-CITY completion preserve existing flow', () {
    final transition = DriverNextOrderTransition(
      apiClient: FakeTransitionApi(),
    );
    expect(
      transition.shouldSwitch(
        result: completion(activated: false, nextId: null),
        serviceType: 'city',
      ),
      isFalse,
    );
    for (final type in ['delivery', 'intercity']) {
      expect(
        transition.shouldSwitch(result: completion(), serviceType: type),
        isFalse,
      );
    }
  });

  test('activated next is loaded once from authoritative details', () async {
    final api = FakeTransitionApi();
    final transition = DriverNextOrderTransition(apiClient: api);
    final generation = transition.beginOnce()!;
    final loaded = await transition.loadAcceptedNext(
      nextOrderId: 'next',
      generation: generation,
    );
    expect(loaded['status'], 'accepted');
    expect(api.detailsCalls, 1);
    expect(api.acceptNextCalls, 0);
    expect(transition.beginOnce(), isNull);
  });

  test('accepted next navigation target is pickup, never destination', () {
    final loaded = nextOrder();
    expect(driverRouteDestination(loaded), nextPickup);
    expect(driverRouteDestination(loaded), isNot(nextDestination));
    expect(driverStatusSupportsNavigation(loaded['status']), isTrue);
    expect(driverStatusSupportsNavigation('queued'), isFalse);
  });

  test('old route and steps can be invalidated before next load', () {
    final state = DriverRouteRequestState();
    final generation = state.begin();
    state.complete(
      generation,
      RouteResult(
        geometry: const [LatLng(1, 1), LatLng(2, 2)],
        steps: const [
          NavigationStep(
            modifier: 'right',
            type: 'turn',
            targetLat: 2,
            targetLng: 2,
            streetName: 'Old route',
          ),
        ],
        distanceMeters: 100,
        durationSeconds: 10,
      ),
    );
    state.invalidate();
    expect(state.geometry, isEmpty);
    expect(state.steps, isEmpty);
    expect(state.routeDistanceMeters, 0);
    expect(state.routeDurationSeconds, 0);
  });

  test('details failure recovers once through active-driver lookup', () async {
    final api = FakeTransitionApi()
      ..detailsError = const TulparApiException(503, 'offline')
      ..active = nextOrder();
    final transition = DriverNextOrderTransition(apiClient: api);
    final loaded = await transition.loadAcceptedNext(
      nextOrderId: 'next',
      generation: transition.beginOnce()!,
    );
    expect(loaded['id'], 'next');
    expect(api.activeCalls, 1);
    expect(api.acceptNextCalls, 0);
  });

  test('failed recovery does not accept again or invent next order', () async {
    final api = FakeTransitionApi()
      ..detailsError = const TulparApiException(503, 'offline')
      ..active = null;
    final transition = DriverNextOrderTransition(apiClient: api);
    await expectLater(
      transition.loadAcceptedNext(
        nextOrderId: 'next',
        generation: transition.beginOnce()!,
      ),
      throwsA(isA<NextOrderLoadException>()),
    );
    expect(api.acceptNextCalls, 0);
  });

  test('dispose invalidation rejects late async result', () async {
    final api = FakeTransitionApi();
    final transition = DriverNextOrderTransition(apiClient: api);
    final generation = transition.beginOnce()!;
    transition.invalidate();
    await expectLater(
      transition.loadAcceptedNext(nextOrderId: 'next', generation: generation),
      throwsA(isA<NextOrderLoadException>()),
    );
  });

  test(
    'queued or mismatched backend result is never opened as navigation',
    () async {
      for (final data in [
        nextOrder(status: 'queued'),
        {...nextOrder(), 'id': 'other'},
      ]) {
        final api = FakeTransitionApi()..details = data;
        final transition = DriverNextOrderTransition(apiClient: api);
        await expectLater(
          transition.loadAcceptedNext(
            nextOrderId: 'next',
            generation: transition.beginOnce()!,
          ),
          throwsA(isA<NextOrderLoadException>()),
        );
      }
    },
  );
}
