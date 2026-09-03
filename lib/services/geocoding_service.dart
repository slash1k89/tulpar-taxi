import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/address_suggestion.dart';
import '../models/city.dart';
import 'tulpar_api_client.dart';

class KazakhstanSettlement {
  const KazakhstanSettlement({
    required this.id,
    required this.name,
    required this.region,
    required this.lat,
    required this.lng,
  });
  final String id;
  final String name;
  final String region;
  final double lat;
  final double lng;
  String get displayName => region.isEmpty ? name : '$name, $region';
  factory KazakhstanSettlement.fromCity(City city) => KazakhstanSettlement(
    id: city.id,
    name: city.name,
    region: city.region,
    lat: city.latitude,
    lng: city.longitude,
  );
}

class KazakhstanPointAddress {
  const KazakhstanPointAddress({
    required this.settlement,
    required this.address,
  });
  final KazakhstanSettlement settlement;
  final String address;
}

class GeocodingService {
  static const requestTimeout = Duration(seconds: 9);

  static TulparApiClient _api(http.Client? client) => TulparApiClient(
    client: client,
    tokenProvider: client == null ? null : () async => 'test-token',
  );

  static Future<List<KazakhstanSettlement>> searchKazakhstanSettlements({
    required String query,
    http.Client? client,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return [];
    try {
      final rows = await _api(client)
          .searchGeocoding(query: clean, kind: 'settlement')
          .timeout(requestTimeout);
      return rows
          .map(_settlementFromApi)
          .whereType<KazakhstanSettlement>()
          .toList();
    } catch (error) {
      debugPrint('Kazakhstan settlement search failed: $error');
      return [];
    }
  }

  static Future<List<AddressSuggestion>> searchKazakhstanAddress({
    required String query,
    required KazakhstanSettlement settlement,
    String? viewBox,
    http.Client? client,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return [];
    try {
      final rows = await _api(client)
          .searchGeocoding(
            query: clean,
            kind: 'address',
            settlement: settlement.name,
            lat: settlement.lat,
            lng: settlement.lng,
          )
          .timeout(requestTimeout);
      return rows
          .where((row) {
            final address = row['address'];
            return address is Map &&
                address['country_code']?.toString().toLowerCase() == 'kz' &&
                _matchesSettlement(address, settlement.name);
          })
          .map(_addressFromApi)
          .whereType<AddressSuggestion>()
          .toList();
    } catch (error) {
      debugPrint('Kazakhstan address search failed: $error');
      return [];
    }
  }

  static Future<List<AddressSuggestion>> searchCityAddress({
    required String query,
    required City city,
    http.Client? client,
  }) => searchKazakhstanAddress(
    query: query,
    settlement: KazakhstanSettlement.fromCity(city),
    client: client,
  );

  static Future<bool> pointBelongsToCity(
    LatLng point,
    City city, {
    http.Client? client,
  }) async {
    if (!city.contains(point)) return false;
    final resolved = await reverseGeocodeKazakhstanChecked(
      point.latitude,
      point.longitude,
      client: client,
    );
    return resolved != null && _namesMatch(resolved.settlement.name, city.name);
  }

  static Future<KazakhstanPointAddress?> reverseGeocodeKazakhstan(
    double lat,
    double lng, {
    http.Client? client,
  }) async {
    try {
      return await reverseGeocodeKazakhstanChecked(lat, lng, client: client);
    } catch (error) {
      debugPrint('Kazakhstan reverse geocoding failed: $error');
      return null;
    }
  }

  static Future<KazakhstanPointAddress?> reverseGeocodeKazakhstanChecked(
    double lat,
    double lng, {
    http.Client? client,
  }) async {
    final data = await _api(
      client,
    ).reverseGeocoding(lat: lat, lng: lng).timeout(requestTimeout);
    if (data['countryCode']?.toString().toLowerCase() != 'kz') return null;
    final settlement = _settlementFromApi(data['settlement']);
    final address = data['address']?.toString().trim() ?? '';
    if (settlement == null || address.isEmpty) return null;
    return KazakhstanPointAddress(settlement: settlement, address: address);
  }

  static Future<List<AddressSuggestion>> searchAddress({
    required String query,
    required String cityName,
    double? cityLat,
    double? cityLng,
    bool useCityBias = true,
    http.Client? client,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return [];
    try {
      final rows = await _api(client)
          .searchGeocoding(
            query: clean,
            kind: 'address',
            settlement: useCityBias ? cityName : null,
            lat: useCityBias ? cityLat : null,
            lng: useCityBias ? cityLng : null,
          )
          .timeout(requestTimeout);
      return rows
          .where((row) {
            final address = row['address'];
            return address is! Map ||
                address['country_code']?.toString().toLowerCase() == 'kz';
          })
          .map(_addressFromApi)
          .whereType<AddressSuggestion>()
          .toList();
    } catch (error) {
      debugPrint('Address search failed: $error');
      return [];
    }
  }

  static Future<String> reverseGeocode(
    double lat,
    double lng, {
    http.Client? client,
  }) async {
    final data = await _api(
      client,
    ).reverseGeocoding(lat: lat, lng: lng).timeout(requestTimeout);
    return AddressSuggestion.shortAddressFromDisplayName(
      data['address']?.toString() ?? '',
    );
  }

  static KazakhstanSettlement? _settlementFromApi(Object? raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final lat = _number(data['lat']);
    final lng = _number(data['lng']);
    final name = data['name']?.toString().trim() ?? '';
    if (lat == null || lng == null || name.isEmpty) return null;
    return KazakhstanSettlement(
      id: data['id']?.toString() ?? '$lat,$lng',
      name: name,
      region: data['region']?.toString() ?? '',
      lat: lat,
      lng: lng,
    );
  }

  static AddressSuggestion? _addressFromApi(Map<String, dynamic> data) {
    final lat = _number(data['lat']);
    final lng = _number(data['lng']);
    final display = data['displayName']?.toString().trim() ?? '';
    if (lat == null || lng == null || display.isEmpty) return null;
    final raw = data['address'];
    final address = raw is Map ? raw : const {};
    return AddressSuggestion(
      displayName: display,
      lat: lat,
      lng: lng,
      road: AddressSuggestion.streetFromAddressComponents(address),
      houseNumber: address['house_number']?.toString(),
      locality: (address['city'] ?? address['town'] ?? address['village'])
          ?.toString(),
    );
  }

  static double? _number(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  static bool _matchesSettlement(Map address, String expected) => [
    address['city'],
    address['town'],
    address['village'],
    address['municipality'],
    address['city_district'],
    address['county'],
  ].whereType<Object>().any((value) => _namesMatch(value.toString(), expected));

  static bool _namesMatch(String left, String right) {
    final a = _normalizeName(left);
    final b = _normalizeName(right);
    return a.contains(b) || b.contains(a);
  }

  static bool settlementNamesMatch(String left, String right) =>
      _namesMatch(left, right);
  static String _normalizeName(String value) => value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
}
