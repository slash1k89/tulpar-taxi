import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/services/tulpar_api_client.dart';

void main() {
  test(
    'authorized locale update uses only the current-user endpoint',
    () async {
      final sent = <String>[];
      final client = TulparApiClient(
        tokenProvider: () async => 'test-access-token',
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/users/me/locale');
          expect(request.headers['authorization'], 'Bearer test-access-token');
          sent.add(jsonDecode(request.body)['locale'] as String);
          return http.Response(jsonEncode({'locale': sent.last}), 200);
        }),
      );
      for (final code in ['ru', 'kk', 'en']) {
        await client.updateCurrentUserLocale(code);
      }
      expect(sent, ['ru', 'kk', 'en']);
      await expectLater(
        client.updateCurrentUserLocale('kz'),
        throwsArgumentError,
      );
      expect(sent, ['ru', 'kk', 'en']);
      client.close();
    },
  );
}
