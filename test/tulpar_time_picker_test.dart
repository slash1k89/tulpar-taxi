import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/models/intercity_ride.dart';
import 'package:taxi_esil/models/order_service_type.dart';
import 'package:taxi_esil/screens/driver/intercity_create_ride_screen.dart';
import 'package:taxi_esil/screens/map/map_screen.dart';
import 'package:taxi_esil/services/geocoding_service.dart';
import 'package:taxi_esil/widgets/tulpar_time_picker.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';

void main() {
  test('rounding never changes the selected calendar day', () {
    expect(
      roundTulparTime(const TimeOfDay(hour: 23, minute: 58)),
      const TimeOfDay(hour: 23, minute: 55),
    );
  });

  testWidgets('picker is digital with 24 hours and five-minute steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TulparTimePicker(initialTime: TimeOfDay(hour: 8, minute: 37)),
        ),
      ),
    );

    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byKey(const Key('tulpar_time_picker')), findsOneWidget);
    for (var hour = 0; hour < 24; hour += 1) {
      expect(
        find.byKey(Key('tulpar_time_hour_${_twoDigits(hour)}')),
        findsOneWidget,
      );
    }
    for (var minute = 0; minute < 60; minute += 5) {
      expect(
        find.byKey(Key('tulpar_time_minute_${_twoDigits(minute)}')),
        findsOneWidget,
      );
    }
    expect(find.text('08:35'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('tulpar_time_minute_35')))
          .selected,
      isTrue,
    );
  });

  testWidgets('selecting 08:30 returns the chosen digital time', (
    tester,
  ) async {
    TimeOfDay? selected;
    await _pumpLauncher(
      tester,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      onSelected: (value) => selected = value,
    );

    await tester.tap(find.byKey(const Key('open_tulpar_time_picker')));
    await tester.pumpAndSettle();
    await _tapVisible(tester, const Key('tulpar_time_hour_08'));
    await _tapVisible(tester, const Key('tulpar_time_minute_30'));
    await _tapVisible(tester, const Key('tulpar_time_done'));
    await tester.pumpAndSettle();

    expect(selected, const TimeOfDay(hour: 8, minute: 30));
  });

  testWidgets('cancel keeps the previously selected time', (tester) async {
    var selected = const TimeOfDay(hour: 14, minute: 45);
    await _pumpLauncher(
      tester,
      initialTime: selected,
      onSelected: (value) => selected = value,
    );

    await tester.tap(find.byKey(const Key('open_tulpar_time_picker')));
    await tester.pumpAndSettle();
    await _tapVisible(tester, const Key('tulpar_time_hour_08'));
    await _tapVisible(tester, const Key('tulpar_time_minute_30'));
    await _tapVisible(tester, const Key('tulpar_time_cancel'));
    await tester.pumpAndSettle();

    expect(selected, const TimeOfDay(hour: 14, minute: 45));
  });

  testWidgets('ordinary intercity opens the Tulpar digital picker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_city_id': 'esil'});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapScreen(
          serviceType: OrderServiceType.intercity,
          locationProvider: () async => null,
          showMapTiles: false,
        ),
      ),
    );
    await tester.pump();

    await _openFromScreen(tester, const Key('intercity_time_field'));
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byKey(const Key('tulpar_time_picker')), findsOneWidget);
  });

  for (final editing in [false, true]) {
    testWidgets(
      'driver ${editing ? 'edit' : 'create'} ride opens Tulpar picker',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: IntercityCreateRideScreen(
              initialOrigin: _origin,
              initialDestination: _destination,
              initialDepartureAt: _departure,
              ride: editing ? _ride : null,
            ),
          ),
        );

        await _openFromScreen(tester, const Key('driver_ride_time'));
        expect(find.byType(TimePickerDialog), findsNothing);
        expect(find.byKey(const Key('tulpar_time_picker')), findsOneWidget);
      },
    );
  }
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required TimeOfDay initialTime,
  required ValueChanged<TimeOfDay> onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_tulpar_time_picker'),
            onPressed: () async {
              final selected = await showTulparTimePicker(
                context: context,
                initialTime: initialTime,
              );
              if (selected != null) onSelected(selected);
            },
            child: const Text('Открыть'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openFromScreen(WidgetTester tester, Key fieldKey) async {
  final field = find.byKey(fieldKey);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

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
  rideId: 'ride-time-picker',
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
