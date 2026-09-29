import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/models/order_service_type.dart';
import 'package:taxi_esil/screens/map/map_screen.dart';
import 'package:taxi_esil/services/order_creation_service.dart';

class _NoopGateway implements OrderCreationGateway {
  @override
  Future<String> create(OrderDraft draft) async => 'test-order';
}

void main() {
  for (final (code, pickup, button) in [
    ('ru', 'Точный адрес отправления', 'Заказать такси'),
    ('kk', 'Жөнелтудің нақты мекенжайы', 'Таксиге тапсырыс беру'),
    ('en', 'Exact pickup address', 'Request a taxi'),
  ]) {
    testWidgets('passenger order form uses $code', (tester) async {
      SharedPreferences.setMockInitialValues({'selected_city_id': 'astana'});
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MapScreen(
            orderCreationService: OrderCreationService(gateway: _NoopGateway()),
            locationProvider: () async => null,
            showMapTiles: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('from_address_field')))
            .decoration
            ?.labelText,
        pickup,
      );
      expect(find.text(button), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('delivery fields and button use English', (tester) async {
    SharedPreferences.setMockInitialValues({'selected_city_id': 'astana'});
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapScreen(
          serviceType: OrderServiceType.delivery,
          orderCreationService: OrderCreationService(gateway: _NoopGateway()),
          locationProvider: () async => null,
          showMapTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Request delivery'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('delivery_item_description_field')),
          )
          .decoration
          ?.labelText,
      'Package description',
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final (code, route, parcel, contacts, additional, price) in [
    (
      'ru',
      'Маршрут',
      'Что доставляем',
      'Контакты',
      'Дополнительные детали',
      'Стоимость доставки',
    ),
    (
      'kk',
      'Бағыт',
      'Не жеткіземіз',
      'Байланыс деректері',
      'Қосымша мәліметтер',
      'Жеткізу құны',
    ),
    (
      'en',
      'Route',
      'Delivery item',
      'Contacts',
      'Additional details',
      'Delivery price',
    ),
  ]) {
    testWidgets('delivery sections and optional details use $code', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'selected_city_id': 'astana'});
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MapScreen(
            serviceType: OrderServiceType.delivery,
            orderCreationService: OrderCreationService(gateway: _NoopGateway()),
            locationProvider: () async => null,
            showMapTiles: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(route), findsOneWidget);
      expect(find.text(parcel), findsOneWidget);
      expect(find.text(contacts), findsOneWidget);
      expect(find.text(additional), findsOneWidget);
      expect(find.text(price), findsOneWidget);
      expect(
        find.byKey(const Key('delivery_destination_apartment_field')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const Key('delivery_additional_toggle')),
      );
      await tester.tap(find.byKey(const Key('delivery_additional_toggle')));
      await tester.pumpAndSettle();
      final apartment = find.byKey(
        const Key('delivery_destination_apartment_field'),
      );
      await tester.enterText(apartment, '12');
      await tester.tap(find.byKey(const Key('delivery_additional_toggle')));
      await tester.pumpAndSettle();
      expect(apartment, findsNothing);
      await tester.tap(find.byKey(const Key('delivery_additional_toggle')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(apartment).controller?.text, '12');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('delivery remains scrollable with keyboard on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'selected_city_id': 'astana'});
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MapScreen(
          serviceType: OrderServiceType.delivery,
          orderCreationService: OrderCreationService(gateway: _NoopGateway()),
          locationProvider: () async => null,
          showMapTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final recipient = find.byKey(const Key('delivery_recipient_name_field'));
    await tester.ensureVisible(recipient);
    await tester.enterText(recipient, 'Sam');
    await tester.ensureVisible(find.byKey(const Key('delivery_price_section')));
    expect(find.byKey(const Key('order_price_field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopening delivery after city starts a fresh form', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_city_id': 'astana'});
    Widget screen(OrderServiceType type) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MapScreen(
        key: ValueKey(type),
        serviceType: type,
        orderCreationService: OrderCreationService(gateway: _NoopGateway()),
        locationProvider: () async => null,
        showMapTiles: false,
      ),
    );
    await tester.pumpWidget(screen(OrderServiceType.delivery));
    await tester.pumpAndSettle();
    final parcel = find.byKey(const Key('delivery_item_description_field'));
    await tester.enterText(parcel, 'Документы');
    await tester.pump();
    expect(tester.widget<TextField>(parcel).controller?.text, 'Документы');

    await tester.pumpWidget(screen(OrderServiceType.city));
    await tester.pumpAndSettle();
    expect(parcel, findsNothing);
    expect(find.byKey(const Key('order_price_field')), findsOneWidget);

    await tester.pumpWidget(screen(OrderServiceType.delivery));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(parcel).controller?.text, isEmpty);
  });
}
