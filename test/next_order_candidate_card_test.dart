import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/models/next_order.dart';
import 'package:taxi_esil/services/next_order_candidate_controller.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/widgets/next_order_candidate_card.dart';

NextOrderCandidate candidate(
  String id, {
  int distance = 200,
  int price = 1500,
}) => NextOrderCandidate(
  orderId: id,
  pickupAddress: 'Абая, 15',
  destinationAddress: 'Ауэзова, 22',
  passengerPrice: price,
  distanceToCurrentDestinationMeters: distance,
);

class FakeNextOrderApi extends TulparApiClient {
  FakeNextOrderApi() : super(tokenProvider: () async => 'test');

  List<NextOrderCandidate> candidates = [];
  Object? candidatesError;
  Object? acceptError;
  int candidateCalls = 0;
  int acceptCalls = 0;
  String? acceptedOrderId;

  @override
  Future<List<NextOrderCandidate>> getNextOrderCandidates() async {
    candidateCalls++;
    if (candidatesError != null) throw candidatesError!;
    return [...candidates];
  }

  @override
  Future<NextOrderAcceptanceResult> acceptNextOrder(String orderId) async {
    acceptCalls++;
    acceptedOrderId = orderId;
    if (acceptError != null) throw acceptError!;
    return NextOrderAcceptanceResult(
      orderId: orderId,
      status: 'queued',
      driverId: 'driver',
      queuedAfterOrderId: 'current',
      passengerPrice: 1500,
      agreedPrice: 1500,
      distanceToCurrentDestinationMeters: 200,
    );
  }
}

Map<String, dynamic> order(String serviceType, String status) => {
  'id': 'current',
  'serviceType': serviceType,
  'status': status,
};

void main() {
  test('only CITY in_progress is eligible for next-order card', () {
    expect(
      NextOrderCandidateController.isEligibleOrder(
        order('city', 'in_progress'),
      ),
      isTrue,
    );
    for (final value in [
      order('delivery', 'in_progress'),
      order('intercity', 'in_progress'),
      order('city', 'accepted'),
      order('city', 'driver_arrived'),
      order('city', 'queued'),
      order('city', 'completed'),
    ]) {
      expect(NextOrderCandidateController.isEligibleOrder(value), isFalse);
    }
  });

  testWidgets('card shows pickup, destination, price and distance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextOrderCandidateCard(
            candidate: candidate('next'),
            isAccepting: false,
            onAccept: () {},
            onOffer: () {},
          ),
        ),
      ),
    );
    expect(find.text('Следующий заказ рядом'), findsOneWidget);
    expect(find.text('Откуда: Абая, 15'), findsOneWidget);
    expect(find.text('Куда: Ауэзова, 22'), findsOneWidget);
    expect(find.text('1 500 ₸'), findsOneWidget);
    expect(find.text('Подача в 200 м'), findsOneWidget);
  });

  test('empty candidates leaves card state empty', () async {
    final api = FakeNextOrderApi();
    final controller = NextOrderCandidateController(apiClient: api);
    controller.updateOrder(order('city', 'in_progress'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.candidate, isNull);
    controller.dispose();
  });

  test('closest candidate is the only selected candidate', () async {
    final api = FakeNextOrderApi()
      ..candidates = [
        candidate('far', distance: 280),
        candidate('near', distance: 90),
      ];
    final controller = NextOrderCandidateController(apiClient: api);
    controller.updateOrder(order('city', 'in_progress'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.candidate?.orderId, 'near');
    controller.dispose();
  });

  test('accept uses candidate id, hides card and stops polling', () async {
    final api = FakeNextOrderApi()..candidates = [candidate('next-42')];
    final controller = NextOrderCandidateController(
      apiClient: api,
      pollInterval: const Duration(milliseconds: 20),
    );
    controller.updateOrder(order('city', 'in_progress'));
    await Future<void>.delayed(Duration.zero);
    expect(await controller.accept(), isTrue);
    expect(api.acceptedOrderId, 'next-42');
    expect(controller.candidate, isNull);
    expect(controller.isPolling, isFalse);
    controller.dispose();
  });

  test(
    'accept failure keeps polling lifecycle and exposes safe error',
    () async {
      final api = FakeNextOrderApi()
        ..candidates = [candidate('next')]
        ..acceptError = const TulparApiException(409, 'Already accepted');
      final controller = NextOrderCandidateController(
        apiClient: api,
        pollInterval: const Duration(seconds: 1),
      );
      controller.updateOrder(order('city', 'in_progress'));
      await Future<void>.delayed(Duration.zero);
      expect(await controller.accept(), isFalse);
      expect(controller.lastError, 'Заказ уже недоступен');
      expect(controller.isPolling, isTrue);
      controller.dispose();
    },
  );

  test('queued backend conflict stops polling', () async {
    final api = FakeNextOrderApi()
      ..candidates = [candidate('next')]
      ..acceptError = const TulparApiException(
        409,
        'Driver already has a queued order',
      );
    final controller = NextOrderCandidateController(apiClient: api);
    controller.updateOrder(order('city', 'in_progress'));
    await Future<void>.delayed(Duration.zero);
    expect(await controller.accept(), isFalse);
    expect(controller.isPolling, isFalse);
    expect(controller.candidate, isNull);
    controller.dispose();
  });

  test('leaving CITY in_progress clears candidate and stops polling', () async {
    final api = FakeNextOrderApi()..candidates = [candidate('next')];
    final controller = NextOrderCandidateController(apiClient: api);
    controller.updateOrder(order('city', 'in_progress'));
    await Future<void>.delayed(Duration.zero);
    controller.updateOrder(order('city', 'completed'));
    expect(controller.candidate, isNull);
    expect(controller.isPolling, isFalse);
    controller.dispose();
  });

  test(
    'sent offer hides that candidate without changing current order',
    () async {
      final api = FakeNextOrderApi()..candidates = [candidate('offered')];
      final controller = NextOrderCandidateController(apiClient: api);
      controller.updateOrder(order('city', 'in_progress'));
      await Future<void>.delayed(Duration.zero);
      controller.markOfferSent('offered');
      await controller.refresh();
      expect(controller.candidate, isNull);
      expect(controller.isPolling, isTrue);
      controller.dispose();
    },
  );

  test('dispose cancels timer and prevents further API polling', () async {
    final api = FakeNextOrderApi();
    final controller = NextOrderCandidateController(
      apiClient: api,
      pollInterval: const Duration(milliseconds: 15),
    );
    controller.updateOrder(order('city', 'in_progress'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    controller.dispose();
    final callsAtDispose = api.candidateCalls;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(api.candidateCalls, callsAtDispose);
  });

  testWidgets('card actions call accept and existing offer entry points', (
    tester,
  ) async {
    var accepts = 0;
    var offers = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NextOrderCandidateCard(
            candidate: candidate('next'),
            isAccepting: false,
            onAccept: () => accepts++,
            onOffer: () => offers++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('next_order_accept_button')));
    await tester.tap(find.byKey(const Key('next_order_offer_button')));
    expect(accepts, 1);
    expect(offers, 1);
  });
}
