import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/screens/driver/driver_screen.dart';
import 'package:taxi_esil/screens/map/destination_picker_screen.dart';

Widget localized(Locale locale, Widget home) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  for (final (code, online, empty, pickup, choose) in [
    ('ru', 'На линии', 'Пока нет доступных заказов', 'Точка отправления', 'Выбрать эту точку'),
    ('kk', 'Желіде', 'Әзірге қолжетімді тапсырыс жоқ', 'Жөнелту нүктесі', 'Осы нүктені таңдау'),
    ('en', 'Online', 'No available orders yet', 'Pickup point', 'Choose this point'),
  ]) {
    testWidgets('driver availability uses $code', (tester) async {
      await tester.pumpWidget(localized(
        Locale(code),
        DriverScreen(
          userId: 'driver-test',
          activeOrderLoader: () async => null,
          availableOrdersLoader: () async => [],
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(Duration.zero);
      }
      expect(find.text(online), findsOneWidget);
      expect(find.text(empty), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('map point picker uses $code', (tester) async {
      await tester.pumpWidget(localized(
        Locale(code),
        const MapPointPickerScreen(
          initialCenter: LatLng(51.957, 66.404),
          initialAddress: 'Test address',
          purpose: MapPointPurpose.pickup,
          showMapTiles: false,
        ),
      ));
      expect(find.text(pickup), findsOneWidget);
      expect(find.text(choose), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
