import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations_en.dart';
import 'package:taxi_esil/l10n/generated/app_localizations_kk.dart';
import 'package:taxi_esil/l10n/generated/app_localizations_ru.dart';

void main() {
  test('Russian unread count uses one, few and many forms', () {
    final l10n = AppLocalizationsRu();
    expect(l10n.unreadMessages(1), '1 сообщение');
    expect(l10n.unreadMessages(2), '2 сообщения');
    expect(l10n.unreadMessages(5), '5 сообщений');
    expect(l10n.unreadMessages(21), '21 сообщение');
  });

  test('Kazakh and English unread counts use natural forms', () {
    final kk = AppLocalizationsKk();
    final en = AppLocalizationsEn();
    expect(kk.unreadMessages(1), '1 оқылмаған хабарлама');
    expect(kk.unreadMessages(5), '5 оқылмаған хабарлама');
    expect(en.unreadMessages(1), '1 unread message');
    expect(en.unreadMessages(5), '5 unread messages');
  });
}
