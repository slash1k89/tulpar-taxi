import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/models/city.dart';
import 'package:taxi_esil/models/order_service_type.dart';
import 'package:taxi_esil/screens/map/destination_picker_screen.dart';
import 'package:taxi_esil/screens/map/map_screen.dart';
import 'package:taxi_esil/services/map_point_address_resolver.dart';
import 'package:taxi_esil/services/order_creation_service.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('GPS coordinates resolve to the pickup address field', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_city_id': 'esil'});
    const gpsPoint = LatLng(51.96, 66.4);
    final resolver = MapPointAddressResolver(
      reverseGeocode: (lat, lng) async => 'Проспект Республики, 10/1',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapScreen(
          orderCreationService: OrderCreationService(gateway: _NoopGateway()),
          addressResolver: resolver,
          locationProvider: () async => gpsPoint,
          cityPointValidator: (_, _) async => true,
          showMapTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Проспект Республики, 10/1'), findsOneWidget);
  });

  testWidgets('manual pickup selection returns a resolved address', (
    tester,
  ) async {
    await _pumpMap(tester, resolvedAddress: 'Улица отправления, 1');

    await tester.tap(find.byKey(const Key('from_address_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Выбрать на карте'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать эту точку'));
    await tester.pumpAndSettle();

    expect(find.text('Улица отправления, 1'), findsOneWidget);
  });

  testWidgets('manual destination selection returns a resolved address', (
    tester,
  ) async {
    await _pumpMap(tester, resolvedAddress: 'Улица назначения, 2');

    await tester.tap(find.byKey(const Key('to_address_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Выбрать на карте'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выбрать эту точку'));
    await tester.pumpAndSettle();

    expect(find.text('Улица назначения, 2'), findsOneWidget);
  });

  test(
    'coordinate fallback is used only after reverse geocoding fails',
    () async {
      const point = LatLng(51.1605, 71.4305);
      final resolver = MapPointAddressResolver(
        reverseGeocode: (lat, lng) async => throw Exception('offline'),
      );

      final resolved = await resolver.resolve(point);

      expect(resolved.address, 'Точка на карте (51.160, 71.430)');
    },
  );

  test('successful reverse geocoding returns the resolved address', () async {
    const point = LatLng(51.1605, 71.4305);
    final resolver = MapPointAddressResolver(
      reverseGeocode: (lat, lng) async => 'Абая, 15',
    );

    final resolved = await resolver.resolve(point);

    expect(resolved.address, 'Абая, 15');
    expect(resolved.address, isNot(startsWith('Точка на карте')));
  });

  testWidgets('pickup and destination are selectors without keyboard input', (
    tester,
  ) async {
    await _pumpMap(tester, resolvedAddress: 'Адрес');

    final pickup = tester.widget<TextField>(
      find.byKey(const Key('from_address_field')),
    );
    final destination = tester.widget<TextField>(
      find.byKey(const Key('to_address_field')),
    );
    expect(pickup.readOnly, isTrue);
    expect(destination.readOnly, isTrue);
    expect(pickup.decoration?.hintText, 'Выберите адрес');
    expect(destination.decoration?.hintText, 'Выберите адрес');
    expect(find.text('Город отправления'), findsNothing);
    expect(find.text('Город назначения'), findsNothing);
  });

  testWidgets('delivery shows the global city for pickup and destination', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      resolvedAddress: 'Адрес',
      serviceType: OrderServiceType.delivery,
    );

    expect(find.byKey(const Key('from_city_selector')), findsNothing);
    expect(find.byKey(const Key('to_city_selector')), findsNothing);
    expect(find.text('Город отправления'), findsNothing);
    expect(find.text('Город назначения'), findsNothing);
    expect(find.text('Точный адрес отправления'), findsOneWidget);
    expect(find.text('Точный адрес доставки'), findsOneWidget);
    expect(
      find.byKey(const Key('delivery_destination_apartment_field')),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(const Key('delivery_additional_toggle')),
    );
    await tester.tap(find.byKey(const Key('delivery_additional_toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('delivery_destination_apartment_field')),
      findsOneWidget,
    );
  });

  testWidgets('creation map hides GPS button and map picker shows it', (
    tester,
  ) async {
    await _pumpMap(tester, resolvedAddress: 'Адрес');
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.byKey(const Key('from_address_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Выбрать на карте'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map_picker_gps_button')), findsOneWidget);
  });

  testWidgets('map picker GPS rejects a point outside selected city', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapPointPickerScreen(
          initialCenter: const LatLng(51.9570, 66.4040),
          initialAddress: 'Есиль',
          purpose: MapPointPurpose.pickup,
          restrictedCity: cityById('esil'),
          cityPointValidator: (_, _) async => false,
          locationProvider: () async => const LatLng(51.1694, 71.4491),
          showMapTiles: false,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('map_picker_gps_button')));
    await tester.pump();
    expect(find.text('Выберите точку в городе Есиль.'), findsOneWidget);
  });

  testWidgets('city validation error resets checking and retry succeeds', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapPointPickerScreen(
          initialCenter: const LatLng(51.957, 66.404),
          initialAddress: 'ул. Абая, 1',
          purpose: MapPointPurpose.pickup,
          restrictedCity: cityById('esil'),
          cityPointValidator: (_, _) async {
            calls++;
            if (calls == 1) throw Exception('offline');
            return true;
          },
          showMapTiles: false,
        ),
      ),
    );

    await tester.tap(find.text('Выбрать эту точку'));
    await tester.pump();
    expect(
      find.text('Не удалось проверить точку. Попробуйте ещё раз.'),
      findsOneWidget,
    );
    expect(find.text('Проверка...'), findsNothing);

    await tester.tap(find.text('Выбрать эту точку'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('hung reverse lookup ends with coordinate fallback', (
    tester,
  ) async {
    final never = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapPointPickerScreen(
          initialCenter: const LatLng(51.957, 66.404),
          purpose: MapPointPurpose.pickup,
          addressResolver: MapPointAddressResolver(
            reverseGeocode: (_, _) => never.future,
          ),
          showMapTiles: false,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 11));
    expect(
      find.textContaining('Точка на карте (51.957, 66.404)'),
      findsOneWidget,
    );
    expect(find.text('Определение адреса...'), findsNothing);
    expect(find.text('Выбрать эту точку'), findsOneWidget);
  });

  testWidgets('GPS timeout does not block manual map selection', (
    tester,
  ) async {
    final never = Completer<LatLng?>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapPointPickerScreen(
          initialCenter: const LatLng(51.957, 66.404),
          initialAddress: 'Есиль',
          purpose: MapPointPurpose.pickup,
          locationProvider: () => never.future,
          showMapTiles: false,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('map_picker_gps_button')));
    await tester.pump(const Duration(seconds: 13));
    expect(find.textContaining('Выберите точку вручную'), findsOneWidget);
    expect(find.text('Выбрать эту точку'), findsOneWidget);
  });

  testWidgets('GPS permission denial keeps manual map selection available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapPointPickerScreen(
          initialCenter: const LatLng(51.957, 66.404),
          initialAddress: 'Есиль',
          purpose: MapPointPurpose.pickup,
          locationProvider: () async => null,
          showMapTiles: false,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('map_picker_gps_button')));
    await tester.pump();
    expect(find.textContaining('Выберите точку вручную'), findsOneWidget);
    expect(find.text('Выбрать эту точку'), findsOneWidget);
  });

  testWidgets('dispose during reverse request is safe', (tester) async {
    final never = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapPointPickerScreen(
          initialCenter: const LatLng(51.957, 66.404),
          purpose: MapPointPurpose.pickup,
          addressResolver: MapPointAddressResolver(
            reverseGeocode: (_, _) => never.future,
          ),
          showMapTiles: false,
        ),
      ),
    );
    expect(find.byType(FlutterMap), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    never.complete('Поздний адрес');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpMap(
  WidgetTester tester, {
  required String resolvedAddress,
  OrderServiceType serviceType = OrderServiceType.city,
}) async {
  final resolver = MapPointAddressResolver(
    reverseGeocode: (lat, lng) async => resolvedAddress,
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MapScreen(
        serviceType: serviceType,
        orderCreationService: OrderCreationService(gateway: _NoopGateway()),
        addressResolver: resolver,
        locationProvider: () async => null,
        cityPointValidator: (_, _) async => true,
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
