import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/models/intercity_ride.dart';
import 'package:taxi_esil/models/intercity_ride_booking.dart';
import 'package:taxi_esil/screens/driver/active_intercity_trip_screen.dart';
import 'package:taxi_esil/screens/driver_navigation_screen.dart';
import 'package:taxi_esil/services/active_intercity_trip_service.dart';
import 'package:taxi_esil/services/intercity_ride_service.dart';
import 'package:taxi_esil/widgets/app_drawer.dart';

void main() {
  setUp(ActiveIntercityTripResolver.resetMemoryForTest);

  test('departed ride resolves with ordered remaining pickups', () async {
    final cache = _Cache();
    final resolver = ActiveIntercityTripResolver(
      repository: _Repository(rides: [_ride], bookings: _bookings),
      cache: cache,
    );

    final result = await resolver.resolve();

    expect(result.kind, ActiveIntercityTripResolutionKind.found);
    expect(result.trip?.rideId, 'ride-active');
    expect(result.trip?.remainingPickups.map((point) => point.address), [
      'First pickup',
      'Second pickup',
    ]);
    expect(cache.rideId, 'ride-active');
  });

  test('network failure preserves the last trustworthy active trip', () async {
    final cache = _Cache();
    final first = ActiveIntercityTripResolver(
      repository: _Repository(rides: [_ride], bookings: _bookings),
      cache: cache,
    );
    await first.resolve();

    final failed = ActiveIntercityTripResolver(
      repository: _Repository(error: StateError('offline')),
      cache: cache,
    );
    final result = await failed.resolve();

    expect(result.kind, ActiveIntercityTripResolutionKind.unknown);
    expect(result.trip?.rideId, 'ride-active');
    expect(result.trip?.remainingPickups, hasLength(2));
    expect(cache.rideId, 'ride-active');
  });

  test('confirmed absence clears the cached active trip', () async {
    final cache = _Cache()..rideId = 'ride-active';
    final initial = ActiveIntercityTripResolver(
      repository: _Repository(rides: [_ride], bookings: _bookings),
      cache: cache,
    );
    await initial.resolve();

    final completed = ActiveIntercityTripResolver(
      repository: _Repository(rides: [_rideCompleted]),
      cache: cache,
    );
    final result = await completed.resolve();

    expect(result.kind, ActiveIntercityTripResolutionKind.confirmedNone);
    expect(result.trip, isNull);
    expect(cache.rideId, isNull);
  });

  test('reached pickup stays excluded after a full resolver restart', () async {
    final cache = _Cache();
    ActiveIntercityTripResolver.resetMemoryForTest();
    final resolver = ActiveIntercityTripResolver(
      repository: _Repository(rides: [_ride], bookings: _bookingsWithReachedA),
      cache: cache,
    );

    final result = await resolver.resolve();

    expect(result.kind, ActiveIntercityTripResolutionKind.found);
    expect(result.trip?.remainingPickups.map((point) => point.address), [
      'Second pickup',
    ]);
  });

  test(
    'network timeout keeps backend reached state from last snapshot',
    () async {
      final cache = _Cache();
      final online = ActiveIntercityTripResolver(
        repository: _Repository(
          rides: [_ride],
          bookings: _bookingsWithReachedA,
        ),
        cache: cache,
      );
      await online.resolve();

      final offline = ActiveIntercityTripResolver(
        repository: _Repository(error: TimeoutException('offline')),
        cache: cache,
      );
      final result = await offline.resolve();

      expect(result.kind, ActiveIntercityTripResolutionKind.unknown);
      expect(result.trip?.remainingPickups.map((point) => point.address), [
        'Second pickup',
      ]);
    },
  );

  test('all reached pickups leave only the final destination waypoint', () {
    final trip = ActiveIntercityTrip(
      ride: _ride,
      bookings: _bookingsAllReached,
    );

    expect(trip.remainingPickups, isEmpty);
    expect(trip.ride.destinationLat, 51.16);
    expect(trip.ride.destinationLng, 71.47);
  });

  test('cancelled and completed bookings never become waypoints', () {
    final inactive = [
      _bookingWithStatus('cancelled', IntercityRideBookingStatus.cancelled),
      _bookingWithStatus('completed', IntercityRideBookingStatus.completed),
    ];

    expect(intercityNavigationPickups(inactive), isEmpty);
  });

  testWidgets('Back from navigation keeps active trip details resumable', (
    tester,
  ) async {
    final repository = _Repository(rides: [_ride], bookings: _bookings);
    final trip = ActiveIntercityTrip(ride: _ride, bookings: _bookings);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActiveIntercityTripScreen(
          trip: trip,
          repository: repository,
          openNavigationInitially: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final continueButton = find.byKey(const Key('driver_ride_continue'));
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(DriverNavigationScreen).evaluate().isNotEmpty) break;
    }
    expect(find.byType(DriverNavigationScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(DriverNavigationScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver_ride_continue')), findsOneWidget);
    expect(find.byKey(const Key('driver_ride_complete')), findsOneWidget);
  });

  testWidgets('driver profile menu returns to the same active trip', (
    tester,
  ) async {
    final resolver = ActiveIntercityTripResolver(
      repository: _Repository(rides: [_ride], bookings: _bookings),
      cache: _Cache(),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          drawer: AppDrawer(
            mode: AppMode.driver,
            userLabel: 'driver',
            activeIntercityTripResolver: resolver,
          ),
          body: const Text('Profile'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    scaffold.openDrawer();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('drawer_continue_intercity_trip')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('drawer_continue_intercity_trip')));
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(DriverNavigationScreen).evaluate().isNotEmpty) break;
    }

    expect(find.byType(DriverNavigationScreen), findsOneWidget);
    final details = tester.widget<ActiveIntercityTripScreen>(
      find.byType(ActiveIntercityTripScreen),
    );
    expect(details.trip.rideId, 'ride-active');
  });

  testWidgets('navigation marks only the next pickup and refreshes route', (
    tester,
  ) async {
    final repository = _Repository(rides: [_ride], bookings: _bookings);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActiveIntercityTripScreen(
          trip: ActiveIntercityTrip(ride: _ride, bookings: _bookings),
          repository: repository,
        ),
      ),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(DriverNavigationScreen).evaluate().isNotEmpty) break;
    }
    final navigation = tester.widget<DriverNavigationScreen>(
      find.byType(DriverNavigationScreen),
    );

    final remaining = await navigation.onNextPickupReached!();

    expect(repository.markedBookingIds, ['booking-1']);
    expect(remaining.map((point) => point.address), ['Second pickup']);
  });
}

const _ride = IntercityRide(
  rideId: 'ride-active',
  originCity: 'Есиль',
  destinationCity: 'Астана',
  originLat: 51.95,
  originLng: 66.4,
  destinationLat: 51.16,
  destinationLng: 71.47,
  totalSeats: 4,
  availableSeats: 2,
  pricePerSeat: 5000,
  allowsLuggage: true,
  status: IntercityRideStatus.departed,
);

const _rideCompleted = IntercityRide(
  rideId: 'ride-active',
  originCity: 'Есиль',
  destinationCity: 'Астана',
  totalSeats: 4,
  availableSeats: 2,
  pricePerSeat: 5000,
  allowsLuggage: true,
  status: IntercityRideStatus.completed,
);

const _route = IntercityBookingRoute(
  originCity: 'Есиль',
  destinationCity: 'Астана',
);

const _bookings = [
  IntercityRideBooking(
    bookingId: 'booking-1',
    rideId: 'ride-active',
    seats: 1,
    pricePerSeat: 5000,
    totalPrice: 5000,
    status: IntercityRideBookingStatus.confirmed,
    route: _route,
    rideStatus: 'departed',
    pickupAddress: 'First pickup',
    pickupLat: 51.96,
    pickupLng: 66.41,
  ),
  IntercityRideBooking(
    bookingId: 'booking-2',
    rideId: 'ride-active',
    seats: 1,
    pricePerSeat: 5000,
    totalPrice: 5000,
    status: IntercityRideBookingStatus.confirmed,
    route: _route,
    rideStatus: 'departed',
    pickupAddress: 'Second pickup',
    pickupLat: 52.0,
    pickupLng: 67.0,
  ),
];

final _bookingsWithReachedA = [
  IntercityRideBooking(
    bookingId: 'booking-1',
    rideId: 'ride-active',
    seats: 1,
    pricePerSeat: 5000,
    totalPrice: 5000,
    status: IntercityRideBookingStatus.confirmed,
    route: _route,
    rideStatus: 'departed',
    pickupAddress: 'First pickup',
    pickupLat: 51.96,
    pickupLng: 66.41,
    pickupReachedAt: DateTime.utc(2026, 9, 21),
  ),
  IntercityRideBooking(
    bookingId: 'booking-2',
    rideId: 'ride-active',
    seats: 1,
    pricePerSeat: 5000,
    totalPrice: 5000,
    status: IntercityRideBookingStatus.confirmed,
    route: _route,
    rideStatus: 'departed',
    pickupAddress: 'Second pickup',
    pickupLat: 52.0,
    pickupLng: 67.0,
  ),
];

final _bookingsAllReached = [
  IntercityRideBooking(
    bookingId: 'booking-1',
    rideId: 'ride-active',
    seats: 1,
    pricePerSeat: 5000,
    totalPrice: 5000,
    status: IntercityRideBookingStatus.confirmed,
    route: _route,
    rideStatus: 'departed',
    pickupAddress: 'First pickup',
    pickupLat: 51.96,
    pickupLng: 66.41,
    pickupReachedAt: DateTime.utc(2026, 9, 21),
  ),
  IntercityRideBooking(
    bookingId: 'booking-2',
    rideId: 'ride-active',
    seats: 1,
    pricePerSeat: 5000,
    totalPrice: 5000,
    status: IntercityRideBookingStatus.confirmed,
    route: _route,
    rideStatus: 'departed',
    pickupAddress: 'Second pickup',
    pickupLat: 52.0,
    pickupLng: 67.0,
    pickupReachedAt: DateTime.utc(2026, 9, 21, 1),
  ),
];

class _Cache implements ActiveIntercityTripCache {
  String? rideId;

  @override
  Future<String?> readRideId() async => rideId;

  @override
  Future<void> writeRideId(String? rideId) async => this.rideId = rideId;
}

class _Repository extends IntercityRideService {
  _Repository({this.rides = const [], this.bookings = const [], this.error});

  final List<IntercityRide> rides;
  List<IntercityRideBooking> bookings;
  final Object? error;
  final markedBookingIds = <String>[];

  @override
  Future<List<IntercityRide>> getMyDriverRides() async {
    if (error != null) throw error!;
    return rides;
  }

  @override
  Future<IntercityRide> getDriverRide(String rideId) async {
    if (error != null) throw error!;
    return rides.firstWhere((ride) => ride.rideId == rideId);
  }

  @override
  Future<List<IntercityRideBooking>> getDriverRideBookings(
    String rideId,
  ) async {
    if (error != null) throw error!;
    return bookings;
  }

  @override
  Future<IntercityRideBooking> markPickupReached({
    required String rideId,
    required String bookingId,
  }) async {
    markedBookingIds.add(bookingId);
    final index = bookings.indexWhere((item) => item.bookingId == bookingId);
    final current = bookings[index];
    final updated = IntercityRideBooking(
      bookingId: current.bookingId,
      rideId: current.rideId,
      seats: current.seats,
      pricePerSeat: current.pricePerSeat,
      totalPrice: current.totalPrice,
      status: current.status,
      route: current.route,
      rideStatus: current.rideStatus,
      pickupAddress: current.pickupAddress,
      pickupLat: current.pickupLat,
      pickupLng: current.pickupLng,
      pickupReachedAt: DateTime.utc(2026, 9, 21),
    );
    bookings = [...bookings]..[index] = updated;
    return updated;
  }
}

IntercityRideBooking _bookingWithStatus(
  String id,
  IntercityRideBookingStatus status,
) => IntercityRideBooking(
  bookingId: id,
  rideId: 'ride-active',
  seats: 1,
  pricePerSeat: 5000,
  totalPrice: 5000,
  status: status,
  route: _route,
  rideStatus: 'departed',
  pickupAddress: 'Inactive pickup',
  pickupLat: 51.96,
  pickupLng: 66.41,
);
