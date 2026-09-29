import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/screens/auth/login_screen.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/services/tulpar_auth_session.dart';

void main() {
  for (final purpose in ['setup', 'reset']) {
    test('$purpose verification sets password and creates session', () async {
      final paths = <String>[];
      final controller = TulparAuthController(
        store: _MemoryStore(),
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          switch (request.url.path) {
            case '/api/auth/verification/request':
              expect(jsonDecode(request.body)['purpose'], purpose);
              return http.Response(
                jsonEncode({
                  'challengeId': 'challenge-1',
                  'expiresIn': 300,
                  'resendAfter': 60,
                }),
                202,
              );
            case '/api/auth/verification/verify':
              expect(jsonDecode(request.body)['purpose'], purpose);
              return http.Response(
                jsonEncode({'verificationToken': 'verified-context-token'}),
                200,
              );
            default:
              if (request.url.path == '/api/auth/password/$purpose') {
                expect(jsonDecode(request.body)['password'], 'secure-password');
                return http.Response(jsonEncode({
                  'accessToken': 'access', 'refreshToken': 'refresh',
                  'accessTokenExpiresIn': 900, 'sessionId': 'session-1',
                  'userId': 'user-1',
                }), 200);
              }
              return http.Response('{}', 404);
          }
        }),
      );
      final challenge = await controller.requestFlashCall(
        phone: '+77001234567',
        purpose: purpose,
      );
      final verification = await controller.verifyPasswordFlashCall(
        challengeId: challenge.challengeId,
        phone: '+77001234567',
        code: '4321',
        purpose: purpose,
      );
      expect(controller.hasSession, isFalse);
      await controller.setVerifiedPassword(
        verificationToken: verification.verificationToken,
        password: 'secure-password',
        purpose: purpose,
      );
      expect(controller.hasSession, isTrue);
      expect(paths, [
        '/api/auth/verification/request',
        '/api/auth/verification/verify',
        '/api/auth/password/$purpose',
      ]);
    });
  }

  testWidgets('initial screen shows phone and password', (tester) async {
    await tester.pumpWidget(_authApp(const LoginScreen()));
    expect(find.byKey(const Key('login_phone_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.byKey(const Key('flash_call_primary_button')), findsNothing);
    expect(find.byKey(const Key('register_button')), findsOneWidget);
  });

  testWidgets('ordinary login never requests Flash Call', (tester) async {
    final paths = <String>[];
    await _pump(tester, (request) async {
      paths.add(request.url.path);
      return http.Response(
        jsonEncode({
          'code': 'invalid_credentials',
          'error': 'Invalid phone or password',
        }),
        401,
      );
    });
    await _enterPhone(tester);
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('auth_primary_button')));
    await tester.pump();
    expect(paths, ['/api/auth/login']);
    expect(find.text('Неверный номер телефона или пароль.'), findsOneWidget);
  });

  for (final entry in const [
    ('register_button', 'setup'),
    ('forgot_password_button', 'reset'),
  ]) {
    testWidgets('${entry.$1} starts Flash Call for ${entry.$2}', (
      tester,
    ) async {
      Map<String, dynamic>? sent;
      await _pump(tester, (request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'challengeId': 'challenge-1',
            'expiresIn': 300,
            'resendAfter': 60,
          }),
          202,
        );
      });
      await _enterPhone(tester);
      final action = find.byKey(Key(entry.$1));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump();
      await tester.tap(find.byKey(const Key('auth_primary_button')));
      await tester.pump();
      expect(sent?['method'], 'flash_call');
      expect(sent?['purpose'], entry.$2);
    });
  }

  testWidgets('password and confirmation are validated locally', (
    tester,
  ) async {
    final paths = <String>[];
    await _pump(tester, (request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/request')) {
        return http.Response(
          jsonEncode({
            'challengeId': 'challenge-1',
            'expiresIn': 300,
            'resendAfter': 60,
          }),
          202,
        );
      }
      if (request.url.path.endsWith('/verify')) {
        return http.Response(
          jsonEncode({
            'verificationToken': 'verified-context-token',
            'profileRequired': false,
          }),
          200,
        );
      }
      return http.Response('{}', 500);
    });
    await _enterPhone(tester);
    final register = find.byKey(const Key('register_button'));
    await tester.ensureVisible(register);
    await tester.tap(register);
    await tester.pump();
    await tester.tap(find.byKey(const Key('auth_primary_button')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('flash_call_code_field')),
      '4321',
    );
    await tester.tap(find.byKey(const Key('auth_primary_button')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'password-one',
    );
    await tester.enterText(
      find.byKey(const Key('register_confirm_password_field')),
      'password-two',
    );
    await tester.tap(find.byKey(const Key('auth_primary_button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(paths, [
      '/api/auth/verification/request',
      '/api/auth/verification/verify',
    ]);
    expect(find.text('Пароли не совпадают'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  final auth = TulparAuthController(
    store: _MemoryStore(),
    client: MockClient(handler),
    baseUrl: 'https://api.test',
  );
  await tester.pumpWidget(_authApp(LoginScreen(authController: auth)));
}

Widget _authApp(Widget home) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Future<void> _enterPhone(WidgetTester tester) =>
    tester.enterText(find.byKey(const Key('login_phone_field')), '7001234567');

class _MemoryStore implements TulparAuthSessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<TulparAuthSession?> read() async => null;
  @override
  Future<void> write(TulparAuthSession session) async {}
}
