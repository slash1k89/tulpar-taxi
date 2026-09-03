import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_esil/services/geocoding_service.dart';

void main() {
  test('settlement search requests and keeps only Kazakhstan', () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'results': [
            {
              'id': '1',
              'name': 'Астана',
              'region': '',
              'lat': 51.128,
              'lng': 71.430,
              'address': {'city': 'Астана', 'country_code': 'kz'},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final results = await GeocodingService.searchKazakhstanSettlements(
      query: 'Астана',
      client: client,
    );

    expect(requestedUri?.path, '/api/geocoding/search');
    expect(requestedUri?.queryParameters['kind'], 'settlement');
    expect(results, hasLength(1));
    expect(results.single.name, 'Астана');
  });

  test('address search is bounded to the selected Kazakhstan city', () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'results': [
            {
              'displayName': 'пр. Кабанбай батыра, 25, Астана',
              'lat': 51.12,
              'lng': 71.43,
              'address': {'city': 'Астана', 'country_code': 'kz'},
            },
            {
              'displayName': 'ул. Абая, 15, Караганда',
              'lat': 49.80,
              'lng': 73.10,
              'address': {'city': 'Караганда', 'country_code': 'kz'},
            },
            {
              'displayName': 'улица, Россия',
              'lat': 55.0,
              'lng': 82.0,
              'address': {'city': 'Астана', 'country_code': 'ru'},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final results = await GeocodingService.searchKazakhstanAddress(
      query: 'Кабанбай батыра, 25',
      settlement: const KazakhstanSettlement(
        id: 'astana',
        name: 'Астана',
        region: '',
        lat: 51.128,
        lng: 71.430,
      ),
      client: client,
    );

    expect(requestedUri?.path, '/api/geocoding/search');
    expect(requestedUri?.queryParameters['settlement'], 'Астана');
    expect(results, hasLength(1));
    expect(results.single.displayName, contains('Астана'));
  });

  test('reverse geocoding rejects a point outside Kazakhstan', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'address': 'Омск, Россия', 'countryCode': 'ru'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final result = await GeocodingService.reverseGeocodeKazakhstan(
      54.98,
      73.37,
      client: client,
    );

    expect(result, isNull);
  });
}
