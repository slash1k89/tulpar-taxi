import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/screens/chat/chat_screen.dart';
import 'package:taxi_esil/screens/legal/terms_acceptance_screen.dart';
import 'package:taxi_esil/screens/legal/about_support_screen.dart';
import 'package:taxi_esil/services/legal_link_service.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

Widget termsApp(Locale locale, {Future<Object?> Function()? onAccept}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: TermsAcceptanceScreen(
      version: '1.0',
      onAccept: onAccept ?? () async => const {},
    ),
  );
}

void main() {
  testWidgets('About exposes legal links in RU KK EN without fake support', (
    tester,
  ) async {
    for (final locale in const [Locale('ru'), Locale('kk'), Locale('en')]) {
      final opened = <Uri>[];
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AboutSupportScreen(
          linkService: LegalLinkService(
            launcher: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
          supportEmail: '<SUPPORT_EMAIL>',
          appVersion: '1.0.0-test',
        ),
      ));
      final context = tester.element(find.byType(AboutSupportScreen));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.legalTerms), findsOneWidget);
      expect(find.text(l10n.legalPrivacy), findsOneWidget);
      expect(find.text(l10n.legalAccountDeletion), findsOneWidget);
      expect(find.text(l10n.legalSupportPending), findsOneWidget);
      expect(find.text('<SUPPORT_EMAIL>'), findsNothing);
      expect(find.text('1.0.0-test'), findsOneWidget);
      expect(
        tester.widget<ListTile>(find.byKey(const Key('legal_support_link'))).onTap,
        isNull,
      );
      await tester.tap(find.byKey(const Key('legal_terms_link')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('legal_privacy_link')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('legal_account_deletion_link')));
      await tester.pump();
      expect(opened.map((uri) => uri.toString()), [
        'https://tulpartaxi.kz/terms',
        'https://tulpartaxi.kz/privacy',
        'https://tulpartaxi.kz/account-deletion',
      ]);
    }
  });

  test('legal link service rejects untrusted and malformed targets', () async {
    final opened = <Uri>[];
    final service = LegalLinkService(launcher: (uri) async {
      opened.add(uri);
      return true;
    });
    expect(await service.openHttps('http://tulpartaxi.kz/privacy'), isFalse);
    expect(await service.openHttps('https://example.com/privacy'), isFalse);
    expect(await service.openSupportEmail('<SUPPORT_EMAIL>'), isFalse);
    expect(opened, isEmpty);
  });

  testWidgets('Terms acceptance is explicit and localized in RU KK EN', (
    tester,
  ) async {
    for (final locale in const [Locale('ru'), Locale('kk'), Locale('en')]) {
      await tester.pumpWidget(termsApp(locale));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(TermsAcceptanceScreen));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.termsTitle), findsOneWidget);
      expect(find.text(l10n.termsAccept), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    }
  });

  testWidgets('Terms accept callback runs only after confirmation', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      termsApp(
        const Locale('en'),
        onAccept: () async {
          calls += 1;
          return const {};
        },
      ),
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('chat exposes localized report and block actions in RU KK EN', (
    tester,
  ) async {
    for (final locale in const [Locale('ru'), Locale('kk'), Locale('en')]) {
      final api = TulparApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response('{"unreadCount":0}', 200);
          }
          return http.Response('{"messages":[]}', 200);
        }),
        tokenProvider: () async => 'test-token',
      );
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          orderId: 'order-1',
          peerName: 'Peer',
          peerUserId: 'peer-1',
          apiClient: api,
        ),
      ));
      await tester.pump();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ChatScreen));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.reportUser), findsOneWidget);
      expect(find.text(l10n.blockUser), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      api.close();
    }
  });
}
