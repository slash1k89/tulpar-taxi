import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/models/address_suggestion.dart';
import 'package:taxi_esil/screens/map/destination_picker_screen.dart';
import 'package:taxi_esil/screens/map/intercity_place_picker_screens.dart';
import 'package:taxi_esil/services/geocoding_service.dart';

const _esil = KazakhstanSettlement(
  id: 'esil',
  name: 'Есиль',
  region: 'Акмолинская область',
  lat: 51.9555,
  lng: 66.4032,
);

void main() {
  testWidgets('city picker shows Kazakhstan settlement and returns it', (
    tester,
  ) async {
    KazakhstanSettlement? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async => selected = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IntercityCityPickerScreen(
                    search: (_) async => const [_esil],
                  ),
                ),
              ),
              child: const Text('Город отправления'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Город отправления'));
    await tester.pumpAndSettle();
    expect(find.text('Выберите город'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('intercity_city_search')),
      'Есиль',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.widgetWithText(ListTile, 'Есиль'));
    await tester.pumpAndSettle();
    expect(selected?.name, 'Есиль');
  });

  testWidgets('address autocomplete receives selected settlement', (
    tester,
  ) async {
    KazakhstanSettlement? searchedIn;
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityAddressPickerScreen(
          settlement: _esil,
          purpose: MapPointPurpose.pickup,
          showMapTiles: false,
          search: (_, settlement) async {
            searchedIn = settlement;
            return [
              AddressSuggestion(
                displayName: 'ул. Абая, 15, Есиль',
                lat: 51.95,
                lng: 66.4,
              ),
            ];
          },
        ),
      ),
    );
    expect(find.textContaining('Есиль'), findsOneWidget);
    expect(
      find.byKey(const Key('intercity_address_map_button')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('intercity_address_search')),
      'Абая',
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(searchedIn?.id, _esil.id);
    expect(find.text('ул. Абая, 15'), findsOneWidget);
  });

  testWidgets('stale address search result cannot replace newer query', (
    tester,
  ) async {
    final oldResult = Completer<List<AddressSuggestion>>();
    await tester.pumpWidget(
      MaterialApp(
        home: IntercityAddressPickerScreen(
          settlement: _esil,
          purpose: MapPointPurpose.pickup,
          showMapTiles: false,
          search: (query, _) {
            if (query == 'старый') return oldResult.future;
            return Future.value([
              AddressSuggestion(
                displayName: 'Новый адрес, 2, Есиль',
                lat: 51.96,
                lng: 66.4,
              ),
            ]);
          },
        ),
      ),
    );
    final field = find.byKey(const Key('intercity_address_search'));
    await tester.enterText(field, 'старый');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(field, 'новый');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Новый адрес, 2'), findsOneWidget);
    oldResult.complete([
      AddressSuggestion(
        displayName: 'Старый адрес, 1, Есиль',
        lat: 51.95,
        lng: 66.4,
      ),
    ]);
    await tester.pump();
    expect(find.text('Старый адрес, 1'), findsNothing);
    expect(find.text('Новый адрес, 2'), findsOneWidget);
  });

  testWidgets('intercity map return reuses a usable selected address', (
    tester,
  ) async {
    MapPointSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<MapPointSelection>(
                context,
                MaterialPageRoute(
                  builder: (_) => IntercityAddressPickerScreen(
                    settlement: _esil,
                    purpose: MapPointPurpose.pickup,
                    showMapTiles: false,
                    initialSelection: const MapPointSelection(
                      point: LatLng(51.95, 66.4),
                      address: 'ул. Абая, 15, Есиль',
                    ),
                  ),
                ),
              );
            },
            child: const Text('Открыть'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intercity_address_map_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать эту точку'));
    await tester.pumpAndSettle();
    expect(result?.point, const LatLng(51.95, 66.4));
    expect(result?.address, contains('Есиль'));
  });
}
