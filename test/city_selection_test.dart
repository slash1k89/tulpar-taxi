import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/models/city.dart';
import 'package:taxi_esil/services/city_service.dart';
import 'package:taxi_esil/widgets/city_selection_modal.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('every available city has its own valid map view', () {
    final centers = availableCities
        .map((city) => '${city.latitude}:${city.longitude}')
        .toSet();

    expect(centers, hasLength(availableCities.length));
    for (final city in availableCities) {
      expect(city.latitude, inInclusiveRange(-90, 90));
      expect(city.longitude, inInclusiveRange(-180, 180));
      expect(city.mapZoom, inInclusiveRange(10, 16));
      expect(city.contains(city.center), isTrue);
    }
    expect(availableCities, hasLength(13));
    expect(availableCities.map((city) => city.id), isNot(contains('astana')));
  });

  test('selected city is persisted', () async {
    expect(await CityService.getSelectedCity(), 'esil');

    await CityService.setSelectedCity('arkalyk');

    expect(await CityService.getSelectedCity(), 'arkalyk');
    expect((await CityService.getSelectedCityDetails()).id, 'arkalyk');
  });

  testWidgets('city selector returns the chosen city', (tester) async {
    City? selectedCity;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                selectedCity = await showCitySelectionModal(
                  context,
                  currentCityId: 'esil',
                  citiesLoader: () async => availableCities,
                );
              },
              child: const Text('Выбрать город'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Выбрать город'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Атбасар'));
    await tester.pumpAndSettle();

    expect(selectedCity?.id, 'atbasar');
    expect(selectedCity?.mapZoom, 13.5);
  });
}
