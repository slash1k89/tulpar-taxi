import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/models/city.dart';
import 'package:taxi_esil/services/geocoding_service.dart';

void main() {
  test(
    'two-character street candidate stays selectable as a street, not a house',
    () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['query'], 'Мы');
        expect(request.url.queryParameters['cityId'], 'esil');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'kind': 'street',
                'displayName': 'улица Мырзашева, Есиль, Казахстан',
                'lat': 51.96,
                'lng': 66.40,
                'address': {
                  'road': 'улица Мырзашева',
                  'town': 'Есиль',
                  'country_code': 'kz',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final results = await GeocodingService.searchCityAddress(
        query: 'Мы',
        city: cityById('esil'),
        client: client,
      );
      expect(results, hasLength(1));
      expect(results.single.isStreetOnly, isTrue);
      expect(results.single.shortAddress, 'улица Мырзашева');
    },
  );

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
      expect(requestedUri?.queryParameters['cityId'], city.id);
      expect(results, hasLength(1));
      expect(results.single.displayName, contains('Есиль'));
    });
  }

  test('Rudny search sends its own city identifier', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        '{"results":[]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await GeocodingService.searchCityAddress(
      query: 'Аба',
      city: cityById('rudny'),
      client: client,
    );
    expect(requested?.queryParameters['cityId'], 'rudny');
  });
}
