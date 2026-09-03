import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/models/intercity_ride.dart';
import 'package:taxi_esil/models/intercity_ride_booking.dart';
import 'package:taxi_esil/models/intercity_pickup_draft.dart';
import 'package:taxi_esil/models/intercity_ride_request.dart';
import 'package:taxi_esil/models/intercity_ride_search_draft.dart';
import 'package:taxi_esil/screens/intercity/intercity_bookings_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_mode_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_request_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_ride_details_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_ride_results_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_ride_search_screen.dart';
import 'package:taxi_esil/services/geocoding_service.dart';
import 'package:taxi_esil/services/intercity_ride_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

void main() {
  testWidgets('mode keeps old intercity order and opens rideshare separately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityModeScreen(
          orderBuilder: (_) => const Scaffold(body: Text('old-intercity')),
          rideSearchBuilder: (_) => const Scaffold(body: Text('rideshare')),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('intercity_order_mode')));
    await tester.pumpAndSettle();
    expect(find.text('old-intercity'), findsOneWidget);
    Navigator.of(tester.element(find.text('old-intercity'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intercity_rideshare_mode')));
    await tester.pumpAndSettle();
    expect(find.text('rideshare'), findsOneWidget);
  });

  testWidgets('search validates cities and results send the exact draft', (
    tester,
  ) async {
    final repository = _FakeRepository(searchResult: [_ride]);
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityRideSearchScreen(
          repository: repository,
          initialOrigin: _origin,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('intercity_search_submit')));
    await tester.pump();
    expect(
      find.text('Выберите города отправления и назначения.'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IntercityRideResultsScreen(repository: repository, draft: _draft),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.lastSearch, ('Есиль', 'Астана', 2));
    expect(find.text('4 000 ₸ / место'), findsOneWidget);
    expect(find.text('Свободно: 3 мест'), findsOneWidget);
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(repository.searchCalls, 2);
  });

  testWidgets('results cover loading, empty and error retry', (tester) async {
    final pending = Completer<List<IntercityRide>>();
    final repository = _FakeRepository(searchFuture: pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityRideResultsScreen(repository: repository, draft: _draft),
      ),
    );
    expect(find.byKey(const Key('intercity_results_loading')), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intercity_results_empty')), findsOneWidget);

    final failed = Completer<List<IntercityRide>>();
    repository.searchFuture = failed.future;
    repository.searchResult = [_ride];
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityRideResultsScreen(
          key: const ValueKey('error-results'),
          repository: repository,
          draft: _draft,
        ),
      ),
    );
    await tester.pump();
    failed.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intercity_results_error')), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intercity_ride_ride-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('intercity_details_ride-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intercity_booking_total')), findsOneWidget);
  });

  testWidgets('booking retry keeps one clientRequestId', (tester) async {
    final repository = _FakeRepository(
      bookingErrors: [const TulparApiException(500, 'temporary')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityRideDetailsScreen(
          repository: repository,
          ride: _ride,
          initialSeats: 2,
          initialPickup: _pickup,
        ),
      ),
    );
    expect(find.text('Итого: 8 000 ₸'), findsOneWidget);

    await _confirmBooking(tester);
    expect(find.text('temporary'), findsOneWidget);
    await _confirmBooking(tester);
    expect(repository.bookingCalls, 2);
    expect(repository.bookingClientIds.toSet(), hasLength(1));
    expect(find.text('Место забронировано'), findsWidgets);
  });

  testWidgets('booking button prevents a second request while pending', (
    tester,
  ) async {
    final pending = Completer<IntercityRideBooking>();
    final repository = _FakeRepository(bookingFuture: pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityRideDetailsScreen(
          repository: repository,
          ride: _ride,
          initialPickup: _pickup,
        ),
      ),
    );

    final submit = find.byKey(const Key('intercity_booking_submit'));
    await tester.scrollUntilVisible(
      submit,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.tap(submit, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Подтвердить бронирование?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('intercity_booking_confirm')));
    await tester.pump();
    expect(repository.bookingCalls, 1);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('intercity_booking_submit')),
    );
    expect(button.onPressed, isNull);
    await tester.tap(
      find.byKey(const Key('intercity_booking_submit')),
      warnIfMissed: false,
    );
    expect(repository.bookingCalls, 1);

    pending.complete(_booking);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Место забронировано'), findsWidgets);
  });

  testWidgets('booking 409 has a clear conflict message', (tester) async {
    final repository = _FakeRepository(
      bookingErrors: [
        const TulparApiException(409, 'Not enough available seats'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityRideDetailsScreen(
          repository: repository,
          ride: _ride,
          initialPickup: _pickup,
        ),
      ),
    );

    await _confirmBooking(tester);
    expect(
      find.text('Поездка изменилась или свободных мест уже недостаточно.'),
      findsOneWidget,
    );
  });

  testWidgets('bookings group statuses and cancellation updates immediately', (
    tester,
  ) async {
    final repository = _FakeRepository(
      bookings: [
        _booking,
        _bookingWith('booking-2', IntercityRideBookingStatus.cancelled),
        _bookingWith('booking-3', IntercityRideBookingStatus.completed),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: IntercityBookingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Предстоящие'), findsOneWidget);
    expect(find.text('Отменённые'), findsOneWidget);
    expect(find.text('Завершённые'), findsOneWidget);
    expect(find.text('Телефон: +7 700 000 00 00'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('intercity_cancel_booking_booking-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intercity_cancel_booking_confirm')));
    await tester.pumpAndSettle();
    expect(repository.cancelBookingCalls, 1);
    expect(
      find.byKey(const Key('intercity_cancel_booking_booking-1')),
      findsNothing,
    );
  });

  testWidgets('active matched request stays active and can be cancelled', (
    tester,
  ) async {
    final repository = _FakeRepository(requests: [_request]);
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityRequestScreen(
          repository: repository,
          initialDraft: _draft,
          initialPickup: _pickup,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Активна'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Активна'), findsOneWidget);
    expect(
      find.byKey(const Key('intercity_matched_ride_ride-1')),
      findsOneWidget,
    );

    final cancelRequest = find.byKey(
      const Key('intercity_cancel_request_request-1'),
    );
    await tester.ensureVisible(cancelRequest);
    await tester.pumpAndSettle();
    await tester.tap(cancelRequest);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intercity_cancel_request_confirm')));
    await tester.pumpAndSettle();
    expect(repository.cancelRequestCalls, 1);
    expect(find.text('Отменена'), findsOneWidget);

    final createRequest = find.byKey(const Key('intercity_request_submit'));
    await tester.ensureVisible(createRequest);
    await tester.pumpAndSettle();
    await tester.tap(createRequest);
    await tester.pumpAndSettle();
    expect(repository.createRequestCalls, 1);
    expect(repository.requests.first.status, IntercityRideRequestStatus.active);
  });

  testWidgets('duplicate request 409 is explained to the passenger', (
    tester,
  ) async {
    final repository = _FakeRepository(
      createRequestError: const TulparApiException(409, 'duplicate'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityRequestScreen(
          repository: repository,
          initialDraft: _draft,
          initialPickup: _pickup,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('intercity_request_submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Такая активная заявка уже существует.'), findsOneWidget);
  });
}

Future<void> _confirmBooking(WidgetTester tester) async {
  final submit = find.byKey(const Key('intercity_booking_submit'));
  await tester.scrollUntilVisible(
    submit,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('intercity_booking_confirm')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final stay = find.text('Остаться');
  if (stay.evaluate().isNotEmpty) {
    await tester.tap(stay);
    await tester.pumpAndSettle();
  }
}

const _origin = KazakhstanSettlement(
  id: 'esil',
  name: 'Есиль',
  region: 'Акмолинская область',
  lat: 51.95,
  lng: 66.40,
);
const _destination = KazakhstanSettlement(
  id: 'astana',
  name: 'Астана',
  region: 'Астана',
  lat: 51.16,
  lng: 71.47,
);
final _draft = IntercityRideSearchDraft(
  origin: _origin,
  destination: _destination,
  travelDate: DateTime.now().add(const Duration(days: 2)),
  seats: 2,
);
final _ride = IntercityRide(
  rideId: 'ride-1',
  originCity: 'Есиль',
  destinationCity: 'Астана',
  departureAt: DateTime.now().add(const Duration(days: 2)),
  totalSeats: 4,
  availableSeats: 3,
  pricePerSeat: 4000,
  allowsLuggage: true,
  status: IntercityRideStatus.scheduled,
  driver: const IntercityRideDriver(
    name: 'Тестовый водитель',
    carModel: 'Sedan',
    carColor: 'Белый',
  ),
);
final _booking = IntercityRideBooking(
  bookingId: 'booking-1',
  rideId: 'ride-1',
  seats: 2,
  pricePerSeat: 4000,
  totalPrice: 8000,
  status: IntercityRideBookingStatus.confirmed,
  route: const IntercityBookingRoute(
    originCity: 'Есиль',
    destinationCity: 'Астана',
  ),
  departureAt: DateTime.now().add(const Duration(days: 2)),
  rideStatus: 'scheduled',
  driver: const IntercityBookingDriver(
    name: 'Тестовый водитель',
    carModel: 'Sedan',
    carColor: 'Белый',
    carNumber: 'TEST 001',
    phone: '+7 700 000 00 00',
  ),
);
const _pickup = IntercityPickupDraft(
  address: 'ул. Тестовая, 1',
  latitude: 51.95,
  longitude: 66.40,
);
final _request = IntercityRideRequest(
  requestId: 'request-1',
  originCity: 'Есиль',
  destinationCity: 'Астана',
  travelDate: DateTime.now().add(const Duration(days: 2)),
  seats: 2,
  status: IntercityRideRequestStatus.active,
  matchedRideIds: const ['ride-1'],
);

IntercityRideBooking _bookingWith(
  String id,
  IntercityRideBookingStatus status,
) => IntercityRideBooking(
  bookingId: id,
  rideId: 'ride-1',
  seats: 1,
  pricePerSeat: 4000,
  totalPrice: 4000,
  status: status,
  route: const IntercityBookingRoute(
    originCity: 'Есиль',
    destinationCity: 'Астана',
  ),
  departureAt: DateTime.now().add(const Duration(days: 2)),
  rideStatus: status.name,
);

class _FakeRepository implements IntercityRideRepository {
  _FakeRepository({
    this.searchResult = const [],
    this.searchFuture,
    this.bookingErrors = const [],
    this.bookingFuture,
    this.bookings = const [],
    this.requests = const [],
    this.createRequestError,
  });

  List<IntercityRide> searchResult;
  Future<List<IntercityRide>>? searchFuture;
  final List<Object> bookingErrors;
  final Future<IntercityRideBooking>? bookingFuture;
  List<IntercityRideBooking> bookings;
  List<IntercityRideRequest> requests;
  final Object? createRequestError;
  var searchCalls = 0;
  var bookingCalls = 0;
  var cancelBookingCalls = 0;
  var createRequestCalls = 0;
  var cancelRequestCalls = 0;
  final bookingClientIds = <String>[];
  (String, String, int)? lastSearch;

  @override
  String createClientRequestId() => 'stable-client-request-id';

  @override
  Future<List<IntercityRide>> searchRides({
    required String originCity,
    required String destinationCity,
    required DateTime travelDate,
    required int seats,
  }) {
    searchCalls += 1;
    lastSearch = (originCity, destinationCity, seats);
    final pending = searchFuture;
    searchFuture = null;
    return pending ?? Future.value(searchResult);
  }

  @override
  Future<IntercityRide> getRide(String rideId) async => _ride;

  @override
  Future<IntercityRideBooking> bookRide({
    required String rideId,
    required int seats,
    required String clientRequestId,
    IntercityPickupDraft? pickup,
  }) async {
    bookingClientIds.add(clientRequestId);
    final index = bookingCalls++;
    if (index < bookingErrors.length) throw bookingErrors[index];
    if (bookingFuture case final future?) return future;
    return _booking;
  }

  @override
  Future<List<IntercityRideBooking>> getMyBookings() async => bookings;

  @override
  Future<IntercityRideBooking> cancelBooking(String bookingId) async {
    cancelBookingCalls += 1;
    final current = bookings.firstWhere((item) => item.bookingId == bookingId);
    return _bookingWith(
      current.bookingId,
      IntercityRideBookingStatus.cancelled,
    );
  }

  @override
  Future<IntercityRideRequest> createRequest({
    required String originCity,
    required String destinationCity,
    required DateTime travelDate,
    required int seats,
    IntercityPickupDraft? pickup,
  }) async {
    createRequestCalls += 1;
    if (createRequestError case final error?) throw error;
    final created = IntercityRideRequest(
      requestId: 'request-created',
      originCity: originCity,
      destinationCity: destinationCity,
      travelDate: travelDate,
      seats: seats,
      status: IntercityRideRequestStatus.active,
      matchedRideIds: const ['ride-1'],
      pickupAddress: pickup?.address,
      pickupLat: pickup?.latitude,
      pickupLng: pickup?.longitude,
      passengerComment: pickup?.passengerComment,
    );
    requests = [created, ...requests];
    return created;
  }

  @override
  Future<List<IntercityRideRequest>> getMyRequests() async => requests;

  @override
  Future<IntercityRideRequest> cancelRequest(String requestId) async {
    cancelRequestCalls += 1;
    final current = requests.firstWhere((item) => item.requestId == requestId);
    return IntercityRideRequest(
      requestId: current.requestId,
      originCity: current.originCity,
      destinationCity: current.destinationCity,
      travelDate: current.travelDate,
      seats: current.seats,
      status: IntercityRideRequestStatus.cancelled,
      matchedRideIds: current.matchedRideIds,
      cancelledAt: DateTime.now(),
    );
  }
}
