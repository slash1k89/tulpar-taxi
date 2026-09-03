import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/screens/auth/login_screen.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/services/tulpar_auth_session.dart';

class MemoryAuthStore implements TulparAuthSessionStore {
  TulparAuthSession? value;
  int writes = 0;
  int clears = 0;

  @override
  Future<void> clear() async {
    clears += 1;
    value = null;
  }

  @override
  Future<TulparAuthSession?> read() async => value;

  @override
  Future<void> write(TulparAuthSession session) async {
    writes += 1;
    value = session;
  }
}

Map<String, Object> sessionResponse({
  String accessToken = 'access-1',
  String refreshToken = 'refresh-1',
  bool profileRequired = false,
}) => {
  'accessToken': accessToken,
  'refreshToken': refreshToken,
  'accessTokenExpiresIn': 900,
  'sessionId': 'session-1',
  'userId': 'user-1',
  'profileRequired': profileRequired,
};

void main() {
  test(
    'Flash Call request and verify use the provider-neutral contract',
    () async {
      final paths = <String>[];
      final store = MemoryAuthStore();
      final controller = TulparAuthController(
        store: store,
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path.endsWith('/request')) {
            expect(body, containsPair('method', 'flash_call'));
            expect(body, isNot(contains('code')));
            return http.Response(
              jsonEncode({
                'challengeId': 'challenge-1',
                'expiresIn': 300,
                'resendAfter': 60,
              }),
              202,
            );
          }
          expect(body['code'], '0421');
          return http.Response(jsonEncode(sessionResponse()), 200);
        }),
      );
      final challenge = await controller.requestFlashCall(
        phone: '+77771234567',
      );
      expect(challenge.challengeId, 'challenge-1');
      await controller.verifyFlashCall(
        challengeId: challenge.challengeId,
        phone: '+77771234567',
        code: '0421',
      );
      expect(paths, [
        '/api/auth/verification/request',
        '/api/auth/verification/verify',
      ]);
      expect(store.writes, 1);
      expect(controller.currentUserId, 'user-1');
    },
  );

  test('restore refreshes an expired session and persists rotation', () async {
    final store = MemoryAuthStore()
      ..value = TulparAuthSession(
        accessToken: 'expired',
        refreshToken: 'refresh-old',
        accessTokenExpiresAt: DateTime.utc(2026),
        userId: 'user-1',
        sessionId: 'session-1',
      );
    final controller = TulparAuthController(
      store: store,
      baseUrl: 'https://api.test',
      now: () => DateTime.utc(2026, 8, 31),
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/refresh');
        return http.Response(
          jsonEncode(
            sessionResponse(
              accessToken: 'access-new',
              refreshToken: 'refresh-new',
            ),
          ),
          200,
        );
      }),
    );
    expect(await controller.restore(), true);
    expect(controller.session?.accessToken, 'access-new');
    expect(store.value?.refreshToken, 'refresh-new');
  });

  test(
    'concurrent API 401 responses perform one refresh and retry once',
    () async {
      final store = MemoryAuthStore()
        ..value = TulparAuthSession(
          accessToken: 'access-old',
          refreshToken: 'refresh-old',
          accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
          userId: 'user-1',
          sessionId: 'session-1',
        );
      var refreshCalls = 0;
      final controller = TulparAuthController(
        store: store,
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshCalls += 1;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return http.Response(
              jsonEncode(
                sessionResponse(
                  accessToken: 'access-new',
                  refreshToken: 'refresh-new',
                ),
              ),
              200,
            );
          }
          return http.Response('{}', 500);
        }),
      );
      await controller.restore();
      var profileCalls = 0;
      final api = TulparApiClient(
        tulparAuth: controller,
        client: MockClient((request) async {
          profileCalls += 1;
          final auth = request.headers['authorization'];
          if (auth == 'Bearer access-old') return http.Response('{}', 401);
          expect(auth, 'Bearer access-new');
          return http.Response(jsonEncode({'name': 'Test'}), 200);
        }),
      );
      await Future.wait([
        api.getCurrentUserProfile(),
        api.getCurrentUserProfile(),
      ]);
      expect(refreshCalls, 1);
      expect(profileCalls, 4);
    },
  );

  test('logout clears local secure session after server success', () async {
    final store = MemoryAuthStore()
      ..value = TulparAuthSession(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        userId: 'user-1',
        sessionId: 'session-1',
      );
    final controller = TulparAuthController(
      store: store,
      baseUrl: 'https://api.test',
      client: MockClient(
        (request) async =>
            http.Response(jsonEncode({'status': 'logged_out'}), 200),
      ),
    );
    await controller.restore();
    await controller.logout();
    expect(controller.hasSession, false);
    expect(store.clears, 1);
  });

  testWidgets('Flash Call UI requests code and shows four-digit input', (
    tester,
  ) async {
    final controller = TulparAuthController(
      store: MemoryAuthStore(),
      baseUrl: 'https://api.test',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'challengeId': 'challenge-1',
            'expiresIn': 300,
            'resendAfter': 2,
          }),
          202,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authController: controller,
          activeOrderLoader: () async => null,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('login_phone_field')),
      '+7 (700) 123-45-67',
    );
    await tester.tap(find.byKey(const Key('flash_call_primary_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flash_call_code_field')), findsOneWidget);
    expect(find.textContaining('через 2 сек.'), findsOneWidget);
  });
}
