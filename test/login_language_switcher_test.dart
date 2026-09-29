import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/screens/auth/login_screen.dart';
import 'package:taxi_esil/screens/auth/register_screen.dart';
import 'package:taxi_esil/services/locale_controller.dart';

Widget authApp(LocaleController language, {Widget? home}) => AnimatedBuilder(
  animation: language,
  builder: (_, _) => MaterialApp(
    locale: language.effectiveLocale,
    localeResolutionCallback: (device, _) =>
        LocaleController.resolveLocale(device ?? const Locale('ru')),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home ?? LoginScreen(localeController: language),
  ),
);

LocaleController languageFor({Locale system = const Locale('ru')}) =>
    LocaleController(
      isAuthenticated: () => false,
      sync: (_) async {},
      systemLocale: () => system,
    );

Future<void> choose(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(const Key('language_switcher')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('language_option_$code')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('switcher is visible before login with no backend sync', (
    tester,
  ) async {
    var syncs = 0;
    final language = LocaleController(
      isAuthenticated: () => false,
      sync: (_) async {
        syncs++;
      },
      systemLocale: () => const Locale('ru'),
    );
    await language.load();
    await tester.pumpWidget(authApp(language));
    expect(find.byKey(const Key('language_switcher')), findsOneWidget);
    expect(find.text('RU'), findsOneWidget);
    await choose(tester, 'en');
    expect(syncs, 0);
    language.dispose();
  });

  testWidgets('legal and privacy links are available before login', (
    tester,
  ) async {
    final language = languageFor();
    await language.load();
    await tester.pumpWidget(authApp(language));
    await tester.ensureVisible(find.byKey(const Key('prelogin_legal_links')));
    expect(find.byKey(const Key('prelogin_legal_links')), findsOneWidget);
    await tester.tap(find.byKey(const Key('prelogin_legal_links')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legal_privacy_link')), findsOneWidget);
    language.dispose();
  });

  for (final (code, badge, title) in [
    ('ru', 'RU', 'Вход в MEKEN'),
    ('kk', 'ҚАЗ', 'MEKEN жүйесіне кіру'),
    ('en', 'EN', 'Sign in to MEKEN'),
  ]) {
    testWidgets('select $badge updates login immediately', (tester) async {
      final language = languageFor();
      await language.load();
      await tester.pumpWidget(authApp(language));
      await choose(tester, code);
      expect(find.text(badge), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          LocaleController.preferenceKey,
        ),
        code,
      );
      await tester.pumpWidget(const SizedBox());
      language.dispose();
    });
  }

  for (final (code, badge) in [('ru', 'RU'), ('kk', 'ҚАЗ'), ('en', 'EN')]) {
    testWidgets(
      '$badge remains selected in registration and password recovery',
      (tester) async {
        final language = languageFor();
        await language.load();
        await tester.pumpWidget(authApp(language));
        await choose(tester, code);
      await tester.ensureVisible(find.byKey(const Key('register_button')));
      await tester.tap(find.byKey(const Key('register_button')));
        await tester.pump();
        expect(find.byKey(const Key('language_switcher')), findsOneWidget);
        expect(find.text(badge), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('auth_back_to_login')));
      await tester.tap(find.byKey(const Key('auth_back_to_login')));
        await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('forgot_password_button')));
      await tester.tap(find.byKey(const Key('forgot_password_button')));
        await tester.pump();
        expect(find.byKey(const Key('language_switcher')), findsOneWidget);
        expect(find.text(badge), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        language.dispose();
      },
    );
  }

  testWidgets(
    'manual selection survives restart and is shared with registration',
    (tester) async {
      final first = languageFor(system: const Locale('en'));
      await first.load();
      await tester.pumpWidget(authApp(first));
      await choose(tester, 'kk');
      await tester.pumpWidget(const SizedBox());
      first.dispose();

      final restarted = languageFor(system: const Locale('en'));
      await restarted.load();
      await tester.pumpWidget(authApp(restarted));
      expect(find.text('ҚАЗ'), findsOneWidget);
      expect(find.text('MEKEN жүйесіне кіру'), findsOneWidget);
      await tester.pumpWidget(authApp(restarted, home: const RegisterScreen()));
      expect(find.text('Тіркелу'), findsWidgets);
      expect(find.text('Аккаунт ашу'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      restarted.dispose();
    },
  );

  testWidgets('English selection is shared with registration', (tester) async {
    final language = languageFor();
    await language.load();
    await tester.pumpWidget(authApp(language));
    await choose(tester, 'en');
    await tester.pumpWidget(authApp(language, home: const RegisterScreen()));
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    language.dispose();
  });

  test('system locale is used only before manual selection', () async {
    final kk = languageFor(system: const Locale('kk'));
    await kk.load();
    expect(kk.manualLocale, isNull);
    expect(kk.effectiveLocale.languageCode, 'kk');
    final unsupported = languageFor(system: const Locale('de'));
    await unsupported.load();
    expect(unsupported.effectiveLocale.languageCode, 'ru');
    await kk.choose('en');
    expect(kk.effectiveLocale.languageCode, 'en');
    kk.dispose();
    unsupported.dispose();
  });

  test('backend sync waits for auth and sends the saved locale', () async {
    var authenticated = false;
    final sent = <String>[];
    final language = LocaleController(
      isAuthenticated: () => authenticated,
      sync: (code) async {
        sent.add(code);
      },
      systemLocale: () => const Locale('ru'),
    );
    await language.load();
    await language.choose('kk');
    expect(sent, isEmpty);
    authenticated = true;
    await language.syncIfAuthenticated();
    expect(sent, ['kk']);
    await language.choose('en');
    expect(sent, ['kk', 'en']);
    language.dispose();
  });
}
