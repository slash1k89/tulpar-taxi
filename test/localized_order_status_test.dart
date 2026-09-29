import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/models/order_service_type.dart';

void main() {
  for (final (code, passenger, driver) in [
    ('ru', 'Поиск свободного водителя...', 'Заказы такси'),
    ('kk', 'Бос жүргізуші ізделуде...', 'Такси тапсырыстары'),
    ('en', 'Looking for an available driver...', 'Taxi orders'),
  ]) {
    test('passenger and driver status use $code', () {
      final l10n = lookupAppLocalizations(Locale(code));
      expect(OrderServiceType.city.localizedSearchingText(l10n), passenger);
      expect(OrderServiceType.city.localizedDriverSectionTitle(l10n), driver);
      expect(OrderServiceType.delivery.localizedAcceptedText(l10n),
          isNot(OrderServiceType.city.localizedAcceptedText(l10n)));
    });
  }
}
