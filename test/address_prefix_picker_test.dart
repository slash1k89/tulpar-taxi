import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/models/address_suggestion.dart';
import 'package:taxi_esil/screens/map/destination_picker_screen.dart';
import 'package:taxi_esil/screens/map/intercity_place_picker_screens.dart';
import 'package:taxi_esil/services/geocoding_service.dart';

const _esil = KazakhstanSettlement(
  id: 'esil',
  name: 'Есиль',
  region: '',
  lat: 51.95,
  lng: 66.4,
);

Widget _app(
  Future<List<AddressSuggestion>> Function(String, KazakhstanSettlement) search,
) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: IntercityAddressPickerScreen(
    settlement: _esil,
    purpose: MapPointPurpose.pickup,
    search: search,
    showMapTiles: false,
  ),
);

void main() {
  testWidgets('two letters start search; selecting street asks for house', (
    tester,
  ) async {
    final queries = <String>[];
    await tester.pumpWidget(
      _app((query, _) async {
        queries.add(query);
        if (query.trim() == 'Мы') {
          return [
            AddressSuggestion(
              displayName: 'улица Мырзашева, Есиль',
              lat: 51.95,
              lng: 66.4,
              road: 'улица Мырзашева',
              kind: 'street',
            ),
          ];
        }
        return [
          AddressSuggestion(
            displayName: 'улица Мырзашева, 66, Есиль',
            lat: 51.95,
            lng: 66.4,
            road: 'улица Мырзашева',
            houseNumber: '66',
            kind: 'address',
          ),
        ];
      }),
    );
    final search = find.byKey(const Key('intercity_address_search'));
    await tester.enterText(search, 'М');
    await tester.pump(const Duration(milliseconds: 310));
    expect(queries, isEmpty);
    await tester.enterText(search, 'Мы');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.pump();
    expect(queries, ['Мы']);
    await tester.tap(find.text('улица Мырзашева'));
    await tester.pump();
    expect(find.byType(IntercityAddressPickerScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(search).controller!.text,
      'улица Мырзашева ',
    );
    await tester.enterText(search, 'улица Мырзашева 66');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.pump();
    expect(find.text('улица Мырзашева, 66'), findsOneWidget);
  });

  testWidgets('late stale response cannot replace fresh address results', (
    tester,
  ) async {
    final old = Completer<List<AddressSuggestion>>();
    await tester.pumpWidget(
      _app((query, _) {
        if (query == 'Мы') return old.future;
        return Future.value([
          AddressSuggestion(
            displayName: 'улица Тын Игерушилер, Есиль',
            lat: 51.95,
            lng: 66.4,
            road: 'улица Тын Игерушилер',
            kind: 'street',
          ),
        ]);
      }),
    );
    final search = find.byKey(const Key('intercity_address_search'));
    await tester.enterText(search, 'Мы');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.enterText(search, 'Иге');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.pump();
    expect(find.text('улица Тын Игерушилер'), findsOneWidget);
    old.complete([
      AddressSuggestion(
        displayName: 'улица Мырзашева, Есиль',
        lat: 51.95,
        lng: 66.4,
        road: 'улица Мырзашева',
        kind: 'street',
      ),
    ]);
    await tester.pump();
    expect(find.text('улица Тын Игерушилер'), findsOneWidget);
    expect(find.text('улица Мырзашева'), findsNothing);
  });

  testWidgets('street then house returns coordinates of the house result', (
    tester,
  ) async {
    const housePoint = LatLng(51.95968734, 66.40240018);
    MapPointSelection? selected;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.push<MapPointSelection>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IntercityAddressPickerScreen(
                      settlement: _esil,
                      purpose: MapPointPurpose.destination,
                      showMapTiles: false,
                      search: (query, _) async => query.trim() == 'Мыр'
                          ? [
                              AddressSuggestion(
                                displayName: 'улица Мырзашева, Есиль',
                                lat: 51.96023166,
                                lng: 66.39944266,
                                road: 'улица Мырзашева',
                                kind: 'street',
                              ),
                            ]
                          : [
                              AddressSuggestion(
                                displayName: 'улица Мырзашева, 66, Есиль',
                                lat: housePoint.latitude,
                                lng: housePoint.longitude,
                                road: 'улица Мырзашева',
                                houseNumber: '66',
                                kind: 'address',
                              ),
                            ],
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('intercity_address_search'));
    await tester.enterText(field, 'Мыр');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.pump();
    await tester.tap(find.text('улица Мырзашева'));
    await tester.pump();
    await tester.enterText(field, 'улица Мырзашева 66');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.pump();
    await tester.tap(find.text('улица Мырзашева, 66'));
    await tester.pumpAndSettle();

    expect(selected?.point, housePoint);
    expect(selected?.address, 'улица Мырзашева, 66');
  });
}
