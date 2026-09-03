import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/models/address_suggestion.dart';
import 'package:taxi_esil/models/city.dart';
import 'package:taxi_esil/models/order_service_type.dart';
import 'package:taxi_esil/screens/map/destination_picker_screen.dart';
import 'package:taxi_esil/screens/map/map_screen.dart';
import 'package:taxi_esil/services/geocoding_service.dart';
import 'package:taxi_esil/services/map_point_address_resolver.dart';
import 'package:taxi_esil/services/order_creation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('selected Esil is the initial map center', (tester) async {
    await _pumpMap(tester, selectedCityId: 'esil');

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter.latitude, cityById('esil').latitude);
    expect(map.options.initialCenter.longitude, cityById('esil').longitude);
  });

  testWidgets('GPS outside selected city does not move the map', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      selectedCityId: 'esil',
      location: const LatLng(51.1694, 71.4491),
    );

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter.latitude, cityById('esil').latitude);
    expect(map.options.initialCenter.longitude, cityById('esil').longitude);
  });

  testWidgets('changing selected city changes map and city autocomplete', (
    tester,
  ) async {
    City? searchCity;
    await _pumpMap(
      tester,
      selectedCityId: 'astana',
      cityAddressSearch: (query, city) async {
        searchCity = city;
        return [
          AddressSuggestion(
            displayName: 'пр. Республики, 10, Астана',
            lat: 51.16,
            lng: 71.43,
          ),
        ];
      },
    );

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter.latitude, cityById('astana').latitude);

    await tester.tap(find.byKey(const Key('from_address_field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('intercity_address_search')),
      'Респ',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(searchCity?.id, 'astana');
    expect(find.text('пр. Республики, 10'), findsOneWidget);
  });

  testWidgets('delivery autocomplete receives only selected Esil context', (
    tester,
  ) async {
    City? searchCity;
    await _pumpMap(
      tester,
      selectedCityId: 'esil',
      serviceType: OrderServiceType.delivery,
      cityAddressSearch: (query, city) async {
        searchCity = city;
        return [
          AddressSuggestion(
            displayName: 'ул. Абая, 15, Есиль',
            lat: 51.96,
            lng: 66.40,
          ),
        ];
      },
    );

    await tester.tap(find.byKey(const Key('to_address_field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('intercity_address_search')),
      'Абая',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(searchCity?.id, 'esil');
    expect(find.text('ул. Абая, 15'), findsOneWidget);
  });

  testWidgets('map picker rejects a point outside selected city', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapPointPickerScreen(
          initialCenter: const LatLng(51.1694, 71.4491),
          initialAddress: 'Астана',
          purpose: MapPointPurpose.destination,
          restrictedCity: cityById('esil'),
          addressResolver: MapPointAddressResolver(
            reverseGeocode: (_, _) async => 'Астана',
          ),
          cityPointValidator: (_, _) async => false,
          showMapTiles: false,
        ),
      ),
    );

    await tester.tap(find.text('Выбрать эту точку'));
    await tester.pump();

    expect(find.byKey(const Key('map_point_city_error')), findsOneWidget);
    expect(find.text('Выберите точку в городе Есиль.'), findsOneWidget);
  });

  testWidgets('intercity defaults from city and allows another city', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      selectedCityId: 'esil',
      serviceType: OrderServiceType.intercity,
      settlementSearch: (_) async => const [
        KazakhstanSettlement(
          id: 'astana',
          name: 'Астана',
          region: 'город республиканского значения',
          lat: 51.1694,
          lng: 71.4491,
        ),
      ],
    );

    final fieldFinder = find.byKey(
      const Key('intercity_from_settlement_field'),
    );
    expect(find.textContaining('Есиль'), findsWidgets);

    await tester.tap(fieldFinder);
    await tester.pumpAndSettle();
    expect(find.text('Выберите город'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('intercity_city_search')),
      'Астана',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(ListTile, 'Астана'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Астана'), findsWidgets);
  });
}

Future<void> _pumpMap(
  WidgetTester tester, {
  required String selectedCityId,
  OrderServiceType serviceType = OrderServiceType.city,
  LatLng? location,
  Future<List<AddressSuggestion>> Function(String query, City city)?
  cityAddressSearch,
  Future<List<KazakhstanSettlement>> Function(String query)? settlementSearch,
}) async {
  SharedPreferences.setMockInitialValues({'selected_city_id': selectedCityId});
  await tester.pumpWidget(
    MaterialApp(
      home: MapScreen(
        serviceType: serviceType,
        orderCreationService: OrderCreationService(gateway: _NoopGateway()),
        locationProvider: () async => location,
        cityPointValidator: (_, _) async => true,
        cityAddressSearch: cityAddressSearch,
        settlementSearch: settlementSearch,
        showMapTiles: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _NoopGateway implements OrderCreationGateway {
  @override
  Future<String> create(OrderDraft draft) async => 'test-order';
}
