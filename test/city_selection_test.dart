import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/models/city.dart';
import 'package:taxi_esil/services/city_service.dart';
import 'package:taxi_esil/widgets/city_selection_modal.dart';

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
    }
  });

  test('selected city is persisted', () async {
    expect(await CityService.getSelectedCity(), 'esil');

    await CityService.setSelectedCity('arkalyk');

    expect(await CityService.getSelectedCity(), 'arkalyk');
  });

  testWidgets('city selector returns the chosen city', (tester) async {
    City? selectedCity;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                selectedCity = await showCitySelectionModal(
                  context,
                  currentCityId: 'esil',
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
    await tester.tap(find.text('Астана'));
    await tester.pumpAndSettle();

    expect(selectedCity?.id, 'astana');
    expect(selectedCity?.mapZoom, 11.5);
  });
}
