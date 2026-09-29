import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/screens/chat/chat_screen.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

void main() {
  for (final (intercity, path) in [
    (false, '/api/orders/order-read/messages/read'),
    (true, '/api/intercity-bookings/order-read/messages/read'),
  ]) {
    testWidgets('opening ${intercity ? 'intercity' : 'city'} chat marks read', (
      tester,
    ) async {
      final seen = <String>[];
      final client = TulparApiClient(
        client: MockClient((request) async {
          seen.add('${request.method} ${request.url.path}');
          if (request.method == 'POST') {
            return http.Response('{"unreadCount":0}', 200);
          }
          return http.Response('{"messages":[]}', 200);
        }),
        tokenProvider: () async => 'test-token',
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(
            orderId: 'order-read',
            peerName: 'Peer',
            intercity: intercity,
            apiClient: client,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(seen, contains('POST $path'));
      await tester.pumpWidget(const SizedBox());
      client.close();
    });
  }

  testWidgets('chat stays readable when mark-read request fails', (
    tester,
  ) async {
    final client = TulparApiClient(
      client: MockClient(
        (request) async => request.method == 'POST'
            ? http.Response('{"error":"unavailable"}', 503)
            : http.Response('{"messages":[{"id":"m1","text":"hello"}]}', 200),
      ),
      tokenProvider: () async => 'test-token',
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          orderId: 'network-error',
          peerName: 'Peer',
          apiClient: client,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });
  for (final (locale, empty, hint) in [
    ('ru', 'Нет сообщений. Напишите первым!', 'Сообщение...'),
    ('kk', 'Әзірге хабарлама жоқ. Бірінші болып жазыңыз!', 'Хабарлама...'),
    ('en', 'No messages yet. Say hello!', 'Message...'),
  ]) {
    testWidgets('chat UI uses $locale', (tester) async {
      final client = TulparApiClient(
        client: MockClient((_) async => http.Response('{"messages":[]}', 200)),
        tokenProvider: () async => 'test-token',
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(
            orderId: 'order-1',
            peerName: 'Peer',
            apiClient: client,
          ),
        ),
      );
      await tester.pump();
      expect(find.text(empty), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
        hint,
      );
      await tester.pumpWidget(const SizedBox());
      client.close();
    });
  }

  testWidgets('chat 429 keeps messages and allows retry after Retry-After', (
    tester,
  ) async {
    var posts = 0;
    final client = TulparApiClient(
      client: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages/read')) {
          return http.Response('{"unreadCount":0}', 200);
        }
        if (request.method == 'POST') {
          posts++;
          if (posts == 1) {
            return http.Response(
              '{"error":"chat_rate_limited","retryAfterSeconds":1}',
              429,
            );
          }
          return http.Response('{"message":{"id":"m2"}}', 201);
        }
        return http.Response(
          '{"messages":[{"id":"m1","senderId":"peer","text":"hello"}]}',
          200,
        );
      }),
      tokenProvider: () async => 'test-token',
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          orderId: 'order-1',
          peerName: 'Peer',
          apiClient: client,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'retry me');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(
      find.text('Слишком много сообщений. Повторите через 1 сек.'),
      findsOneWidget,
    );
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('retry me'), findsOneWidget);
    expect(posts, 1);

    ScaffoldMessenger.of(
      tester.element(find.byType(ChatScreen)),
    ).hideCurrentSnackBar();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(posts, 2);
    expect(find.text('hello'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });
}
