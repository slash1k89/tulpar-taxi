import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/widgets/chat_unread_badge.dart';

void main() {
  test('large unread count is formatted as 99+', () {
    expect(ChatUnreadBadge.labelFor(99), '99');
    expect(ChatUnreadBadge.labelFor(100), '99+');
  });

  for (final role in ['passenger', 'driver']) {
    testWidgets('$role chat button shows persisted unread count', (
      tester,
    ) async {
      final api = TulparApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'unreadCount': 3}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
        tokenProvider: () async => 'test-token',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatUnreadBadge(orderId: 'order-1', apiClient: api),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('chat_unread_badge')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      api.close();
    });
  }

  testWidgets('badge refreshes to zero after chat read succeeds', (
    tester,
  ) async {
    var unread = 2;
    final api = TulparApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'unreadCount': unread}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      tokenProvider: () async => 'test-token',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatUnreadBadge(orderId: 'order-read', apiClient: api),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    unread = 0;
    ChatUnreadBadge.refreshOrder('order-read');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('chat_unread_badge')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets('resume restores unread count from backend', (tester) async {
    var unread = 0;
    final api = TulparApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'unreadCount': unread}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      tokenProvider: () async => 'test-token',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatUnreadBadge(orderId: 'order-resume', apiClient: api),
        ),
      ),
    );
    await tester.pump();
    unread = 4;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets('confirmed read clears all badges and ignores stale polling', (
    tester,
  ) async {
    final stale = Completer<http.Response>();
    var requests = 0;
    final api = TulparApiClient(
      client: MockClient((_) async {
        requests++;
        if (requests == 3) return stale.future;
        return http.Response(
          jsonEncode({'unreadCount': requests > 3 ? 1 : 3}),
          200,
        );
      }),
      tokenProvider: () async => 'test-token',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ChatUnreadBadge(orderId: 'shared', apiClient: api),
              ChatUnreadBadge(orderId: 'shared', apiClient: api),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('3'), findsNWidgets(2));
    ChatUnreadBadge.refreshOrder('shared');
    await tester.pump();
    ChatUnreadBadge.markReadConfirmed('shared');
    await tester.pump();
    expect(find.byKey(const Key('chat_unread_badge')), findsNothing);
    stale.complete(http.Response('{"unreadCount":3}', 200));
    await tester.pump();
    expect(find.byKey(const Key('chat_unread_badge')), findsNothing);
    ChatUnreadBadge.refreshOrder('shared');
    await tester.pump();
    await tester.pump();
    expect(find.text('1'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
