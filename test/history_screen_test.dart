import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/screens/profile/history_screen.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';

TulparApiClient _client(http.Response response) => TulparApiClient(
  client: MockClient((request) async {
    expect(request.method, 'GET');
    expect(request.url.path, '/api/orders/history');
    expect(request.headers['authorization'], 'Bearer test-token');
    return response;
  }),
  tokenProvider: () async => 'test-token',
);

void main() {
  test('history 200 parses orders JSON', () async {
    final orders = await _client(
      http.Response(
        jsonEncode({
          'orders': [
            {'id': '1', 'serviceType': 'city'},
          ],
        }),
        200,
      ),
    ).getOrderHistory();

    expect(orders.single['id'], '1');
  });

  for (final status in [404, 500]) {
    test('history $status HTML becomes TulparApiException', () async {
      final call = _client(
        http.Response('<!DOCTYPE html><html>Error</html>', status),
      ).getOrderHistory();

      await expectLater(
        call,
        throwsA(
          isA<TulparApiException>()
              .having((error) => error.statusCode, 'statusCode', status)
              .having(
                (error) => error,
                'not FormatException',
                isNot(isA<FormatException>()),
              ),
        ),
      );
    });
  }

  testWidgets('history renders city delivery and intercity in one list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HistoryScreen(
          historyLoader: () async => [
            _order('city', 'Такси'),
            _order('delivery', 'Доставка'),
            _order('intercity', 'Межгород'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Такси'), findsOneWidget);
    expect(find.text('Доставка'), findsOneWidget);
    expect(find.text('Межгород'), findsOneWidget);
    expect(find.text('Абая, 1 → Ауэзова, 2'), findsNWidgets(3));
  });

  testWidgets('history retry loads data after an error', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HistoryScreen(
          historyLoader: () async {
            calls++;
            if (calls == 1) throw const TulparApiException(404, 'not found');
            return [_order('city', 'Такси')];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить историю поездок.'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Такси'), findsOneWidget);
    expect(calls, 2);
  });
}

Map<String, dynamic> _order(String serviceType, String _) => {
  'id': serviceType,
  'serviceType': serviceType,
  'status': 'completed',
  'pickupAddress': 'Абая, 1',
  'destinationAddress': 'Ауэзова, 2',
  'passengerPrice': 1000,
  'createdAt': '2026-08-24T10:00:00Z',
};
