import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/models/intercity_pickup_draft.dart';
import 'package:taxi_esil/models/intercity_ride.dart';
import 'package:taxi_esil/models/intercity_ride_booking.dart';
import 'package:taxi_esil/models/intercity_ride_request.dart';
import 'package:taxi_esil/models/intercity_ride_search_draft.dart';
import 'package:taxi_esil/screens/driver/intercity_driver_ride_details_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_bookings_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_pickup_viewer_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_request_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_ride_details_screen.dart';
import 'package:taxi_esil/services/geocoding_service.dart';
import 'package:taxi_esil/services/intercity_ride_service.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';

void main() {
  test('pickup DTO fields are nullable and backward compatible', () {
    final legacyBooking = IntercityRideBooking.fromJson(_bookingJson());
    final legacyRequest = IntercityRideRequest.fromJson(_requestJson());
    expect(legacyBooking.pickup, isNull);
    expect(legacyRequest.pickup, isNull);

    final booking = IntercityRideBooking.fromJson(
      _bookingJson()..addAll({
        'pickupAddress': _pickup1.address,
        'pickupLat': _pickup1.latitude,
        'pickupLng': _pickup1.longitude,
        'passengerComment': 'Главный вход',
      }),
    );
    final request = IntercityRideRequest.fromJson(
      _requestJson()..addAll({
        'pickupAddress': _pickup1.address,
        'pickupLat': _pickup1.latitude,
        'pickupLng': _pickup1.longitude,
        'passengerComment': 'Главный вход',
      }),
    );
    expect(booking.pickup?.address, _pickup1.address);
    expect(request.pickup?.passengerComment, 'Главный вход');
  });

  testWidgets('booking requires pickup and a cancelled picker keeps it', (
    tester,
  ) async {
    final repository = _PassengerRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityRideDetailsScreen(
          ride: _ride,
          repository: repository,
          pickupPicker: (_, _, _) async => null,
        ),
      ),
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('intercity_booking_submit')),
    );
    await tester.pump();
    expect(find.text('Выберите точку посадки.'), findsOneWidget);
    expect(repository.bookingCalls, 0);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityRideDetailsScreen(
          key: const ValueKey('with-pickup'),
          ride: _ride,
          repository: repository,
          initialPickup: _pickup1,
          pickupPicker: (_, _, current) async {
            expect(current?.address, _pickup1.address);
            return null;
          },
        ),
      ),
    );
    await _tapVisible(tester, find.byKey(const Key('intercity_pickup_field')));
    expect(find.text(_pickup1.address), findsOneWidget);
  });

  testWidgets('retry keeps payload ID and changed pickup creates a new ID', (
    tester,
  ) async {
    final repository = _PassengerRepository(
      bookingOutcomes: Queue<Object?>.from([
        TimeoutException('one'),
        TimeoutException('two'),
        null,
      ]),
    );
    var pickerCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityRideDetailsScreen(
          ride: _ride,
          repository: repository,
          pickupPicker: (_, _, current) async {
            pickerCalls += 1;
            return pickerCalls == 1 ? _pickup1 : _pickup2;
          },
        ),
      ),
    );

    await _tapVisible(tester, find.byKey(const Key('intercity_pickup_field')));
    await tester.enterText(
      find.byKey(const Key('intercity_booking_passenger_comment')),
      '  Главный вход  ',
    );
    await _confirmBooking(tester);
    await _confirmBooking(tester);
    expect(repository.bookingClientIds[0], repository.bookingClientIds[1]);
    expect(repository.bookingPickups[0].address, _pickup1.address);
    expect(repository.bookingPickups[0].passengerComment, 'Главный вход');
    expect(
      repository.bookingPickups[0].logicalPayloadKey,
      repository.bookingPickups[1].logicalPayloadKey,
    );

    await _tapVisible(tester, find.byKey(const Key('intercity_pickup_field')));
    await _confirmBooking(tester);
    expect(repository.bookingCalls, 3);
    expect(
      repository.bookingClientIds[2],
      isNot(repository.bookingClientIds[1]),
    );
    expect(repository.bookingPickups[2].address, _pickup2.address);
  });

  testWidgets('request requires pickup and changing origin clears it', (
    tester,
  ) async {
    final repository = _PassengerRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityRequestScreen(
          repository: repository,
          initialDraft: _draft,
          initialPickup: _pickup1,
          originCityPickerBuilder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('choose_other_origin'),
                onPressed: () => Navigator.pop(context, _otherOrigin),
                child: const Text('Кокшетау'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_pickup1.address), findsOneWidget);
    await tester.tap(find.byKey(const Key('intercity_city_field_откуда')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose_other_origin')));
    await tester.pumpAndSettle();
    expect(find.text(_pickup1.address), findsNothing);

    await _tapVisible(
      tester,
      find.byKey(const Key('intercity_request_submit')),
    );
    await tester.pump();
    expect(find.text('Выберите точку посадки.'), findsOneWidget);
    expect(repository.createRequestCalls, 0);
  });

  testWidgets('request sends pickup and matched ride prefills editable data', (
    tester,
  ) async {
    final request = _request(
      pickup: _pickup1.copyWith(passengerComment: 'У ворот'),
    );
    final repository = _PassengerRepository(requests: [request]);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityRequestScreen(
          repository: repository,
          initialDraft: _draft,
          initialPickup: _pickup1,
          pickupPicker: (_, _, _) async => _pickup2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('intercity_request_passenger_comment')),
      '  У ворот  ',
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('intercity_request_submit')),
    );
    await tester.pumpAndSettle();
    expect(repository.requestPickup?.address, _pickup1.address);
    expect(repository.requestPickup?.passengerComment, 'У ворот');

    final matched = find
        .byKey(const Key('intercity_matched_ride_ride-1'))
        .first;
    await _tapVisible(tester, matched);
    await tester.pumpAndSettle();
    expect(find.text(_pickup1.address), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('intercity_booking_passenger_comment')),
          )
          .controller
          ?.text,
      'У ворот',
    );
    await _tapVisible(tester, find.byKey(const Key('intercity_pickup_field')));
    expect(find.text(_pickup2.address), findsOneWidget);
  });

  testWidgets('own lists show pickup but legacy data remains clean', (
    tester,
  ) async {
    final repository = _PassengerRepository(
      bookings: [
        _booking(pickup: _pickup1.copyWith(passengerComment: 'У входа')),
        _booking(id: 'legacy-booking'),
      ],
      requests: [
        _request(pickup: _pickup1.copyWith(passengerComment: 'У входа')),
        _request(id: 'legacy-request'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityBookingsScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Точка посадки: ${_pickup1.address}'), findsOneWidget);
    expect(find.text('Комментарий водителю: У входа'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityRequestScreen(
          repository: repository,
          initialDraft: _draft,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Точка посадки: ${_pickup1.address}'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Комментарий водителю: У входа'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('normal ride has no fake pickup and driver map is read-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityRideDetailsScreen(ride: _ride),
      ),
    );
    expect(find.text('Откуда вас забрать?'), findsOneWidget);

    final booking = _booking(
      pickup: _pickup1.copyWith(passengerComment: 'У входа'),
      passenger: const IntercityBookingPassenger(
        name: 'Тестовый пассажир',
        phone: '+7 700 000 00 00',
      ),
    );
    final driverRepository = _DriverRepository(booking);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityDriverRideDetailsScreen(
          rideId: _ride.rideId,
          repository: driverRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('driver_booking_map_booking-1')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Пассажир: Тестовый пассажир'), findsOneWidget);
    expect(find.text('Телефон: +7 700 000 00 00'), findsOneWidget);
    expect(find.text('Точка посадки: ${_pickup1.address}'), findsOneWidget);
    expect(find.text('Комментарий пассажира: У входа'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityPickupViewerScreen(
          pickup: _pickup1,
          showMapTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('intercity_pickup_readonly_map')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('intercity_pickup_marker')), findsOneWidget);
    expect(find.text(_pickup1.address), findsOneWidget);
    expect(find.text('Выбрать эту точку'), findsNothing);
    expect(find.byKey(const Key('map_picker_gps_button')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: IntercityDriverRideDetailsScreen(
          rideId: _ride.rideId,
          repository: _DriverRepository(
            _booking(
              passenger: const IntercityBookingPassenger(
                name: 'Legacy passenger',
                phone: '+7 700 000 00 01',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver_booking_map_booking-1')), findsNothing);
    expect(find.textContaining('null'), findsNothing);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _confirmBooking(WidgetTester tester) async {
  await _tapVisible(tester, find.byKey(const Key('intercity_booking_submit')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('intercity_booking_confirm')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
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
const _otherOrigin = KazakhstanSettlement(
  id: 'kokshetau',
  name: 'Кокшетау',
  region: 'Акмолинская область',
  lat: 53.28,
  lng: 69.38,
);
const _pickup1 = IntercityPickupDraft(
  address: 'ул. Абая, 15',
  latitude: 51.95,
  longitude: 66.40,
);
const _pickup2 = IntercityPickupDraft(
  address: 'ул. Ауэзова, 2',
  latitude: 51.96,
  longitude: 66.41,
);
final _draft = IntercityRideSearchDraft(
  origin: _origin,
  destination: _destination,
  travelDate: DateTime.now().add(const Duration(days: 2)),
  seats: 2,
);
final _ride = IntercityRide(
  rideId: 'ride-1',
  originCity: _origin.name,
  originLat: _origin.lat,
  originLng: _origin.lng,
  destinationCity: _destination.name,
  destinationLat: _destination.lat,
  destinationLng: _destination.lng,
  departureAt: DateTime.now().add(const Duration(days: 2)),
  totalSeats: 4,
  availableSeats: 3,
  pricePerSeat: 4000,
  allowsLuggage: true,
  status: IntercityRideStatus.scheduled,
);

IntercityRideBooking _booking({
  String id = 'booking-1',
  IntercityPickupDraft? pickup,
  IntercityBookingPassenger? passenger,
}) => IntercityRideBooking(
  bookingId: id,
  rideId: _ride.rideId,
  seats: 2,
  pricePerSeat: 4000,
  totalPrice: 8000,
  status: IntercityRideBookingStatus.confirmed,
  route: const IntercityBookingRoute(
    originCity: 'Есиль',
    destinationCity: 'Астана',
  ),
  departureAt: _ride.departureAt,
  rideStatus: 'scheduled',
  passenger: passenger,
  pickupAddress: pickup?.address,
  pickupLat: pickup?.latitude,
  pickupLng: pickup?.longitude,
  passengerComment: pickup?.passengerComment,
);

IntercityRideRequest _request({
  String id = 'request-1',
  IntercityPickupDraft? pickup,
}) => IntercityRideRequest(
  requestId: id,
  originCity: _origin.name,
  destinationCity: _destination.name,
  travelDate: _draft.travelDate,
  seats: 2,
  status: IntercityRideRequestStatus.active,
  matchedRideIds: const ['ride-1'],
  pickupAddress: pickup?.address,
  pickupLat: pickup?.latitude,
  pickupLng: pickup?.longitude,
  passengerComment: pickup?.passengerComment,
);

Map<String, dynamic> _bookingJson() => {
  'bookingId': 'booking-1',
  'rideId': 'ride-1',
  'seats': 1,
  'pricePerSeat': 4000,
  'totalPrice': 4000,
  'status': 'confirmed',
  'route': {'originCity': 'Есиль', 'destinationCity': 'Астана'},
  'rideStatus': 'scheduled',
};

Map<String, dynamic> _requestJson() => {
  'requestId': 'request-1',
  'originCity': 'Есиль',
  'destinationCity': 'Астана',
  'travelDate': '2030-09-04',
  'seats': 1,
  'status': 'active',
  'matchedRideIds': <String>[],
};

class _PassengerRepository implements IntercityRideRepository {
  _PassengerRepository({
    this.bookings = const [],
    this.requests = const [],
    Queue<Object?>? bookingOutcomes,
  }) : bookingOutcomes = bookingOutcomes ?? Queue<Object?>();

  final List<IntercityRideBooking> bookings;
  List<IntercityRideRequest> requests;
  final Queue<Object?> bookingOutcomes;
  final List<String> bookingClientIds = [];
  final List<IntercityPickupDraft> bookingPickups = [];
  int bookingCalls = 0;
  int createRequestCalls = 0;
  int _requestId = 0;
  IntercityPickupDraft? requestPickup;

  @override
  String createClientRequestId() => 'request-${++_requestId}';

  @override
  Future<IntercityRide> getRide(String rideId) async => _ride;

  @override
  Future<IntercityRideBooking> bookRide({
    required String rideId,
    required int seats,
    required String clientRequestId,
    IntercityPickupDraft? pickup,
  }) async {
    bookingCalls += 1;
    bookingClientIds.add(clientRequestId);
    bookingPickups.add(pickup!);
    if (bookingOutcomes.isNotEmpty) {
      final outcome = bookingOutcomes.removeFirst();
      if (outcome != null) throw outcome;
    }
    return _booking(pickup: pickup);
  }

  @override
  Future<List<IntercityRideBooking>> getMyBookings() async => bookings;

  @override
  Future<IntercityRideRequest> createRequest({
    required String originCity,
    required String destinationCity,
    required DateTime travelDate,
    required int seats,
    IntercityPickupDraft? pickup,
  }) async {
    createRequestCalls += 1;
    requestPickup = pickup;
    final created = _request(id: 'created-request', pickup: pickup);
    requests = [created, ...requests];
    return created;
  }

  @override
  Future<List<IntercityRideRequest>> getMyRequests() async => requests;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DriverRepository implements IntercityDriverRideRepository {
  _DriverRepository(this.booking);

  final IntercityRideBooking booking;

  @override
  Future<IntercityRide> getDriverRide(String rideId) async => _ride;

  @override
  Future<List<IntercityRideBooking>> getDriverRideBookings(
    String rideId,
  ) async => [booking];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
