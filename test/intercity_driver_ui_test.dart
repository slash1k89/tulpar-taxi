import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/models/intercity_driver_ride_draft.dart';
import 'package:taxi_esil/models/intercity_ride.dart';
import 'package:taxi_esil/models/intercity_ride_booking.dart';
import 'package:taxi_esil/screens/driver/driver_intercity_mode_screen.dart';
import 'package:taxi_esil/screens/driver/intercity_create_ride_screen.dart';
import 'package:taxi_esil/screens/driver/intercity_driver_ride_details_screen.dart';
import 'package:taxi_esil/screens/driver/intercity_driver_rides_screen.dart';
import 'package:taxi_esil/services/geocoding_service.dart';
import 'package:taxi_esil/services/intercity_ride_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/widgets/intercity_ride_fields.dart';

void main() {
  testWidgets(
    'driver intercity selector preserves orders and opens new flows',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DriverIntercityModeScreen(
            ordersBuilder: (_) => const Scaffold(body: Text('old-orders')),
            ridesBuilder: (_) => const Scaffold(body: Text('driver-rides')),
            createBuilder: (_) => const Scaffold(body: Text('create-ride')),
          ),
        ),
      );

      await _openAndBack(tester, 'driver_intercity_orders', 'old-orders');
      await _openAndBack(tester, 'driver_intercity_rides', 'driver-rides');
      await tester.tap(find.byKey(const Key('driver_intercity_create')));
      await tester.pumpAndSettle();
      expect(find.text('create-ride'), findsOneWidget);
    },
  );

  testWidgets('create validates required cities, price and future time', (
    tester,
  ) async {
    final repository = _DriverRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityCreateRideScreen(
          repository: repository,
          initialOrigin: _origin,
          initialDepartureAt: _departure,
        ),
      ),
    );
    await _tapVisible(tester, find.byKey(const Key('driver_ride_submit')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('driver_ride_error')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Выберите города отправления и назначения.'),
      findsOneWidget,
    );
    expect(repository.createCalls, 0);
  });

  testWidgets('create shows price per seat, enforces max seats and succeeds', (
    tester,
  ) async {
    final pending = Completer<IntercityRide>();
    final repository = _DriverRepository(createFuture: pending.future);
    IntercityRide? saved;
    await _pumpCreate(tester, repository, onSaved: (ride) => saved = ride);

    expect(find.text('Цена за место'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('driver_ride_price_per_seat')),
      '4000',
    );
    for (var index = 0; index < 8; index += 1) {
      await tester.tap(find.byKey(const Key('intercity_seats_increase')));
      await tester.pump();
    }
    expect(find.text('7'), findsOneWidget);

    final submit = find.byKey(const Key('driver_ride_submit'));
    await _tapVisible(tester, submit);
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();
    expect(repository.createCalls, 1);
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
    pending.complete(_ride(totalSeats: 7));
    await tester.pumpAndSettle();
    expect(saved?.totalSeats, 7);
    expect(repository.lastDraft?.pricePerSeat, 4000);
    expect(repository.lastDraft?.totalSeats, 7);
    expect(find.text('Поездка опубликована'), findsOneWidget);
  });

  for (final errorCase in <(Object, String)>[
    (
      const TulparApiException(400, 'invalid payload'),
      'Проверьте данные поездки.',
    ),
    (
      const TulparApiException(403, 'Active driver access is required'),
      'Доступ водителя не активен.',
    ),
    (
      const TulparApiException(409, 'conflict'),
      'Поездка уже изменилась. Обновите данные.',
    ),
    (TimeoutException('offline'), 'Сервер не ответил. Повторите позже.'),
  ]) {
    testWidgets('create handles ${errorCase.$1.runtimeType}', (tester) async {
      final repository = _DriverRepository(createError: errorCase.$1);
      await _pumpCreate(tester, repository);
      await tester.enterText(
        find.byKey(const Key('driver_ride_price_per_seat')),
        '4000',
      );
      await _tapVisible(tester, find.byKey(const Key('driver_ride_submit')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('driver_ride_error')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(errorCase.$2), findsOneWidget);
    });
  }

  testWidgets('my rides covers loading empty results statuses and retry', (
    tester,
  ) async {
    final pending = Completer<List<IntercityRide>>();
    final repository = _DriverRepository(ridesFuture: pending.future);
    await tester.pumpWidget(
      MaterialApp(home: IntercityDriverRidesScreen(repository: repository)),
    );
    expect(find.byKey(const Key('driver_rides_loading')), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver_rides_empty')), findsOneWidget);

    final failed = Completer<List<IntercityRide>>();
    repository.ridesFuture = failed.future;
    repository.rides = [
      _ride(),
      _ride(id: 'ride-2', status: IntercityRideStatus.departed),
      _ride(id: 'ride-3', status: IntercityRideStatus.completed),
      _ride(id: 'ride-4', status: IntercityRideStatus.cancelled),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityDriverRidesScreen(
          key: const ValueKey('retry-rides'),
          repository: repository,
        ),
      ),
    );
    await tester.pump();
    failed.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver_rides_error')), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Предстоящие'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('В пути'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('В пути'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Завершённые'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Завершённые'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Отменённые'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Отменённые'), findsOneWidget);
    expect(find.text('4 000 ₸ / место'), findsWidgets);
  });

  testWidgets('details show inventory bookings and safe passenger contacts', (
    tester,
  ) async {
    final repository = _DriverRepository(
      rideState: _ride(),
      bookings: [_confirmedBooking],
    );
    await _pumpDetails(tester, repository);

    expect(find.text('Мест всего'), findsOneWidget);
    expect(find.text('Свободно мест'), findsOneWidget);
    expect(find.text('Забронировано мест'), findsOneWidget);
    expect(find.text('Цена за место'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Пассажир: Тестовый пассажир'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Пассажир: Тестовый пассажир'), findsOneWidget);
    expect(find.text('Телефон: +7 700 000 00 00'), findsOneWidget);
  });

  testWidgets('edit locks route time seats after confirmed booking', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityCreateRideScreen(
          repository: _DriverRepository(),
          ride: _ride(),
          hasConfirmedBooking: true,
        ),
      ),
    );

    expect(
      find.byKey(const Key('driver_ride_protected_notice')),
      findsOneWidget,
    );
    expect(find.byType(IntercityCitySelectionField), findsNothing);
    expect(find.byType(IntercitySeatsSelector), findsNothing);
    expect(find.byKey(const Key('driver_ride_price_per_seat')), findsOneWidget);
    expect(
      find.text('Новая цена не изменит сумму уже созданных бронирований.'),
      findsOneWidget,
    );
  });

  testWidgets('cancel warns about bookings and is submitted once', (
    tester,
  ) async {
    final repository = _DriverRepository(
      rideState: _ride(),
      bookings: [_confirmedBooking],
    );
    await _pumpDetails(tester, repository);
    final cancel = find.byKey(const Key('driver_ride_cancel'));
    await _tapVisible(tester, cancel);
    await tester.tap(cancel, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(
      find.text('Все бронирования пассажиров будут отменены.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('driver_ride_cancel_confirm')));
    await tester.pumpAndSettle();
    expect(repository.cancelCalls, 1);
    expect(find.text('Отменена'), findsOneWidget);
    expect(find.byKey(const Key('driver_ride_cancel')), findsNothing);
  });

  testWidgets('depart then complete follow the allowed lifecycle', (
    tester,
  ) async {
    final repository = _DriverRepository(rideState: _ride());
    await _pumpDetails(tester, repository);
    await _confirmAction(tester, 'depart');
    expect(repository.departCalls, 1);
    expect(find.text('В пути'), findsOneWidget);
    expect(find.byKey(const Key('driver_ride_complete')), findsOneWidget);
    await _confirmAction(tester, 'complete');
    expect(repository.completeCalls, 1);
    expect(find.text('Завершена'), findsOneWidget);
    expect(find.byKey(const Key('driver_ride_complete')), findsNothing);
  });

  for (final status in [403, 404]) {
    testWidgets('details handles owner API $status gracefully', (tester) async {
      final repository = _DriverRepository(
        detailError: TulparApiException(status, 'private detail'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: IntercityDriverRideDetailsScreen(
            repository: repository,
            rideId: 'ride-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('driver_ride_details_error')),
        findsOneWidget,
      );
      expect(find.textContaining('private detail'), findsNothing);
    });
  }
}

Future<void> _openAndBack(
  WidgetTester tester,
  String key,
  String expected,
) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  expect(find.text(expected), findsOneWidget);
  Navigator.of(tester.element(find.text(expected))).pop();
  await tester.pumpAndSettle();
}

Future<void> _pumpCreate(
  WidgetTester tester,
  _DriverRepository repository, {
  ValueChanged<IntercityRide>? onSaved,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: IntercityCreateRideScreen(
        repository: repository,
        initialOrigin: _origin,
        initialDestination: _destination,
        initialDepartureAt: _departure,
        onSaved: onSaved ?? (_) {},
      ),
    ),
  );
}

Future<void> _pumpDetails(
  WidgetTester tester,
  _DriverRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: IntercityDriverRideDetailsScreen(
        repository: repository,
        rideId: 'ride-1',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _confirmAction(WidgetTester tester, String action) async {
  final button = find.byKey(Key('driver_ride_$action'));
  await _tapVisible(tester, button);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('driver_ride_${action}_confirm')));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
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
final _departure = DateTime.utc(2030, 9, 3, 7);

IntercityRide _ride({
  String id = 'ride-1',
  IntercityRideStatus status = IntercityRideStatus.scheduled,
  int totalSeats = 4,
  int availableSeats = 2,
}) => IntercityRide(
  rideId: id,
  originCity: 'Есиль',
  originLat: 51.95,
  originLng: 66.40,
  destinationCity: 'Астана',
  destinationLat: 51.16,
  destinationLng: 71.47,
  departureAt: _departure,
  totalSeats: totalSeats,
  availableSeats: availableSeats,
  pricePerSeat: 4000,
  allowsLuggage: true,
  comment: 'Тестовая поездка',
  status: status,
  driver: const IntercityRideDriver(carModel: 'Sedan', carColor: 'Белый'),
);

final _confirmedBooking = IntercityRideBooking(
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
  departureAt: _departure,
  rideStatus: 'scheduled',
  passenger: const IntercityBookingPassenger(
    name: 'Тестовый пассажир',
    phone: '+7 700 000 00 00',
  ),
);

class _DriverRepository implements IntercityDriverRideRepository {
  _DriverRepository({
    this.ridesFuture,
    IntercityRide? rideState,
    this.bookings = const [],
    this.createFuture,
    this.createError,
    this.detailError,
  }) : rideState = rideState ?? _ride();

  List<IntercityRide> rides = const [];
  Future<List<IntercityRide>>? ridesFuture;
  IntercityRide rideState;
  List<IntercityRideBooking> bookings;
  final Future<IntercityRide>? createFuture;
  final Object? createError;
  final Object? detailError;
  int createCalls = 0;
  int cancelCalls = 0;
  int departCalls = 0;
  int completeCalls = 0;
  IntercityDriverRideDraft? lastDraft;

  @override
  Future<IntercityRide> createDriverRide(IntercityDriverRideDraft draft) async {
    createCalls += 1;
    lastDraft = draft;
    if (createError case final error?) throw error;
    return createFuture ?? _ride(totalSeats: draft.totalSeats);
  }

  @override
  Future<List<IntercityRide>> getMyDriverRides() {
    final pending = ridesFuture;
    ridesFuture = null;
    return pending ?? Future.value(rides);
  }

  @override
  Future<IntercityRide> getDriverRide(String rideId) async {
    if (detailError case final error?) throw error;
    return rideState;
  }

  @override
  Future<List<IntercityRideBooking>> getDriverRideBookings(
    String rideId,
  ) async {
    if (detailError case final error?) throw error;
    return bookings;
  }

  @override
  Future<IntercityRide> updateDriverRide({
    required String rideId,
    required IntercityDriverRideDraft draft,
    required bool hasConfirmedBooking,
  }) async {
    lastDraft = draft;
    return rideState;
  }

  @override
  Future<IntercityRide> cancelDriverRide(String rideId) async {
    cancelCalls += 1;
    rideState = _ride(status: IntercityRideStatus.cancelled, availableSeats: 4);
    bookings = bookings
        .map(
          (booking) => IntercityRideBooking(
            bookingId: booking.bookingId,
            rideId: booking.rideId,
            seats: booking.seats,
            pricePerSeat: booking.pricePerSeat,
            totalPrice: booking.totalPrice,
            status: IntercityRideBookingStatus.cancelled,
            route: booking.route,
            departureAt: booking.departureAt,
            rideStatus: 'cancelled',
            passenger: booking.passenger,
          ),
        )
        .toList();
    return rideState;
  }

  @override
  Future<IntercityRide> departDriverRide(String rideId) async {
    departCalls += 1;
    rideState = _ride(status: IntercityRideStatus.departed);
    return rideState;
  }

  @override
  Future<IntercityRide> completeDriverRide(String rideId) async {
    completeCalls += 1;
    rideState = _ride(status: IntercityRideStatus.completed);
    return rideState;
  }
}
