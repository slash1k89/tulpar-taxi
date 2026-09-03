import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/models/city.dart';
import 'package:taxi_esil/services/geocoding_service.dart';

void main() {
  for (final service in ['city', 'delivery']) {
    test('$service autocomplete keeps only selected Esil', () async {
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'results': [
              {
                'displayName': 'ул. Абая, 15, Есиль',
                'lat': 51.96,
                'lng': 66.40,
                'address': {'town': 'Есиль', 'country_code': 'kz'},
              },
              {
                'displayName': 'ул. Абая, 15, Астана',
                'lat': 51.16,
                'lng': 71.43,
                'address': {'city': 'Астана', 'country_code': 'kz'},
              },
              {
                'displayName': 'улица, Россия',
                'lat': 54.98,
                'lng': 73.37,
                'address': {'city': 'Омск', 'country_code': 'ru'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final city = cityById('esil');
      final results = await GeocodingService.searchCityAddress(
        query: 'Абая, 15',
        city: city,
        client: client,
      );

      expect(requestedUri?.path, '/api/geocoding/search');
      expect(requestedUri?.queryParameters['settlement'], city.name);
      expect(results, hasLength(1));
      expect(results.single.displayName, contains('Есиль'));
    });
  }
}
