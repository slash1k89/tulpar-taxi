import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/models/intercity_ride.dart';
import 'package:taxi_esil/models/intercity_ride_request.dart';
import 'package:taxi_esil/models/intercity_ride_search_draft.dart';
import 'package:taxi_esil/models/order_service_type.dart';
import 'package:taxi_esil/screens/driver/intercity_create_ride_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_request_screen.dart';
import 'package:taxi_esil/screens/intercity/intercity_ride_search_screen.dart';
import 'package:taxi_esil/screens/map/map_screen.dart';
import 'package:taxi_esil/services/geocoding_service.dart';
import 'package:taxi_esil/services/intercity_ride_service.dart';
import 'package:taxi_esil/widgets/tulpar_date_picker.dart';

void main() {
  testWidgets('opens without localization and shows Russian month names', (
    tester,
  ) async {
    await _pumpLauncher(tester, initialDate: DateTime(2028, 2, 10));
    await _open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Февраль 2028'), findsOneWidget);
    expect(find.text('Пн'), findsOneWidget);
    expect(find.text('Вс'), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);
  });

  testWidgets('selects a leap day and confirms a date-only value', (
    tester,
  ) async {
    DateTime? result;
    await _pumpLauncher(
      tester,
      initialDate: DateTime(2028, 2, 10, 15),
      onResult: (value) => result = value,
    );
    await _open(tester);
    await tester.tap(find.byKey(const Key('tulpar_date_day_2028_02_29')));
    await tester.tap(find.byKey(const Key('tulpar_date_done')));
    await tester.pumpAndSettle();

    expect(result, DateTime(2028, 2, 29));
  });

  testWidgets('cancel and system dismiss keep the previous value', (
    tester,
  ) async {
    var result = DateTime(2028, 3, 3);
    await _pumpLauncher(
      tester,
      initialDate: result,
      onResult: (value) => result = value,
    );
    await _open(tester);
    await tester.tap(find.byKey(const Key('tulpar_date_day_2028_03_12')));
    await tester.tap(find.byKey(const Key('tulpar_date_cancel')));
    await tester.pumpAndSettle();
    expect(result, DateTime(2028, 3, 3));

    await _open(tester);
    await tester.tap(find.byKey(const Key('tulpar_date_day_2028_03_12')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, DateTime(2028, 3, 3));
  });

  testWidgets('moves across December and January year boundary', (
    tester,
  ) async {
    await _pumpLauncher(
      tester,
      initialDate: DateTime(2028, 12, 15),
      firstDate: DateTime(2028, 1, 1),
      lastDate: DateTime(2029, 12, 31),
    );
    await _open(tester);
    await tester.tap(find.byKey(const Key('tulpar_date_next_month')));
    await tester.pump();
    expect(find.text('Январь 2029'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tulpar_date_previous_month')));
    await tester.pump();
    expect(find.text('Декабрь 2028'), findsOneWidget);
  });

  testWidgets('clamps initial date and disables dates outside predicate', (
    tester,
  ) async {
    DateTime? result;
    await _pumpLauncher(
      tester,
      initialDate: DateTime(2027, 12, 1),
      firstDate: DateTime(2028, 1, 10),
      lastDate: DateTime(2028, 1, 31),
      predicate: (date) => date.day >= 12,
      onResult: (value) => result = value,
    );
    await _open(tester);

    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('tulpar_date_day_2028_01_10')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('tulpar_date_done')));
    await tester.pumpAndSettle();
    expect(result, DateTime(2028, 1, 12));
  });

  testWidgets('supports a month with no selectable days', (tester) async {
    await _pumpLauncher(
      tester,
      initialDate: DateTime(2028, 2, 10),
      firstDate: DateTime(2028, 1, 1),
      lastDate: DateTime(2028, 3, 31),
      predicate: (date) => date.month != 2,
    );
    await _open(tester);
    await tester.tap(find.byKey(const Key('tulpar_date_next_month')));
    await tester.pump();

    expect(find.text('Февраль 2028'), findsOneWidget);
    for (var day = 1; day <= 29; day++) {
      expect(
        tester
            .widget<TextButton>(
              find.byKey(
                Key(
                  'tulpar_date_day_2028_02_${day.toString().padLeft(2, '0')}',
                ),
              ),
            )
            .onPressed,
        isNull,
      );
    }
  });

  testWidgets('marks today and permits the last allowed day', (tester) async {
    await _pumpLauncher(
      tester,
      initialDate: DateTime(2028, 5, 21),
      firstDate: DateTime(2028, 5, 1),
      lastDate: DateTime(2028, 5, 31),
      today: DateTime(2028, 5, 20, 23),
    );
    await _open(tester);

    final todayButton = tester.widget<TextButton>(
      find.byKey(const Key('tulpar_date_day_2028_05_20')),
    );
    expect(
      (todayButton.style?.shape?.resolve({}) as CircleBorder).side,
      isNot(BorderSide.none),
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('tulpar_date_day_2028_05_31')),
          )
          .onPressed,
      isNotNull,
    );
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('renders in ${brightness.name} theme on a small screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpLauncher(
        tester,
        initialDate: DateTime(2028, 8, 10),
        theme: ThemeData(brightness: brightness),
      );
      await _open(tester);
      expect(find.byKey(const Key('tulpar_date_picker')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ordinary INTERCITY order opens Tulpar date picker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_city_id': 'esil'});
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          serviceType: OrderServiceType.intercity,
          locationProvider: () async => null,
          showMapTiles: false,
        ),
      ),
    );
    await tester.pump();
    await _openFromScreen(tester, const Key('intercity_date_field'));
  });

  testWidgets('rideshare search opens Tulpar date picker', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IntercityRideSearchScreen(initialOrigin: _origin),
      ),
    );
    await _openFromScreen(tester, const Key('intercity_travel_date'));
  });

  testWidgets('ride request opens Tulpar date picker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityRequestScreen(
          repository: _RequestRepository(),
          initialDraft: IntercityRideSearchDraft(
            origin: _origin,
            destination: _destination,
            travelDate: DateTime.now().add(const Duration(days: 2)),
            seats: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openFromScreen(tester, const Key('intercity_request_date'));
  });

  testWidgets('driver create opens picker and confirmed edit stays locked', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityCreateRideScreen(
          initialOrigin: _origin,
          initialDestination: _destination,
          initialDepartureAt: _departure,
        ),
      ),
    );
    await _openFromScreen(tester, const Key('driver_ride_date'));
    await tester.tap(find.byKey(const Key('tulpar_date_cancel')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: IntercityCreateRideScreen(ride: _ride, hasConfirmedBooking: true),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('driver_ride_date'));
    await tester.ensureVisible(field);
    expect(tester.widget<InkWell>(field).onTap, isNull);
    expect(find.byKey(const Key('tulpar_date_picker')), findsNothing);
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  DateTime? today,
  SelectableDayPredicate? predicate,
  ValueChanged<DateTime>? onResult,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_tulpar_date_picker'),
            onPressed: () async {
              final value = await showTulparDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: firstDate ?? DateTime(2027, 1, 1),
                lastDate: lastDate ?? DateTime(2030, 12, 31),
                today: today,
                selectableDayPredicate: predicate,
              );
              if (value != null) onResult?.call(value);
            },
            child: const Text('Открыть'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_tulpar_date_picker')));
  await tester.pumpAndSettle();
}

Future<void> _openFromScreen(WidgetTester tester, Key key) async {
  final field = find.byKey(key);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('tulpar_date_picker')), findsOneWidget);
  expect(tester.takeException(), isNull);
}

class _RequestRepository implements IntercityRideRepository {
  @override
  Future<List<IntercityRideRequest>> getMyRequests() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

final _departure = DateTime.utc(2030, 9, 3, 7, 30);

final _ride = IntercityRide(
  rideId: 'ride-date-picker',
  originCity: _origin.name,
  originLat: _origin.lat,
  originLng: _origin.lng,
  destinationCity: _destination.name,
  destinationLat: _destination.lat,
  destinationLng: _destination.lng,
  departureAt: _departure,
  totalSeats: 4,
  availableSeats: 4,
  pricePerSeat: 4000,
  allowsLuggage: true,
  status: IntercityRideStatus.scheduled,
);
