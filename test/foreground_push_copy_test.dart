import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/services/foreground_push_copy.dart';

void main() {
  for (final (code, passenger, driver) in [
    ('ru', 'Заказ отменён пассажиром', 'Водитель отменил поездку'),
    ('kk', 'Тапсырысты жолаушы тоқтатты', 'Жүргізуші сапарды тоқтатты'),
    ('en', 'Order cancelled by passenger', 'Driver cancelled the trip'),
  ]) {
    test('city cancellation foreground copy identifies actor in $code', () {
      final l10n = lookupAppLocalizations(Locale(code));
      expect(
        localizedForegroundPushCopy(
          l10n: l10n,
          eventType: 'cancelled',
          serviceType: 'city',
          cancelledBy: 'passenger',
        ).body,
        passenger,
      );
      expect(
        localizedForegroundPushCopy(
          l10n: l10n,
          eventType: 'cancelled',
          serviceType: 'city',
          cancelledBy: 'driver',
        ).body,
        driver,
      );
    });
  }
  for (final (code, expected) in [
    ('ru', 'Водитель едет к вам'),
    ('kk', 'Жүргізуші сізге келе жатыр'),
    ('en', 'Your driver is on the way'),
  ]) {
    test('foreground order status uses current $code locale', () {
      final copy = localizedForegroundPushCopy(
        l10n: lookupAppLocalizations(Locale(code)),
        eventType: 'accepted',
        fallbackBody: 'Водитель едет к вам',
      );
      expect(copy.body, expected);
    });
  }

  test('foreground chat and intercity ignore raw Russian body', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      localizedForegroundPushCopy(
        l10n: en,
        eventType: 'chat_message',
        fallbackBody: 'Новое сообщение',
      ).body,
      'New chat message',
    );
    expect(
      localizedForegroundPushCopy(
        l10n: en,
        eventType: 'intercity_ride_cancelled',
        fallbackBody: 'Водитель отменил попутку',
      ).body,
      'The driver cancelled the intercity ride',
    );
  });

  test('delivery uses service-specific copy', () {
    final kk = lookupAppLocalizations(const Locale('kk'));
    expect(
      localizedForegroundPushCopy(
        l10n: kk,
        eventType: 'completed',
        serviceType: 'delivery',
      ).body,
      'Жеткізу аяқталды',
    );
  });
}
