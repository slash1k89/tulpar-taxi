import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/address_suggestion.dart';

class GeocodingService {
  // 1. Поиск подсказок при ручном вводе
  static Future<List<AddressSuggestion>> searchAddress({
    required String query,
    required String cityName,
    double? cityLat,
    double? cityLng,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    // Уровень 1: поиск через Photon (текстовый запрос + геоприоритет по lat/lon)
    try {
      final String urlStr =
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}'
          '&lang=ru&limit=7'
          '${cityLat != null && cityLng != null ? "&lat=$cityLat&lon=$cityLng" : ""}';

      final Uri url = Uri.parse(urlStr);
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        final List features = data['features'] ?? [];

        if (features.isNotEmpty) {
          final List<AddressSuggestion> suggestions = [];

          for (var f in features) {
            final props = f['properties'] as Map<String, dynamic>;
            final geometry = f['geometry'] as Map<String, dynamic>;
            final List coords = geometry['coordinates'];

            final String name = props['name']?.toString() ?? '';
            final String street = props['street']?.toString() ?? '';
            final String house = props['housenumber']?.toString() ?? '';
            final String district =
                props['district']?.toString() ??
                props['city']?.toString() ??
                '';

            String title = '';
            if (street.isNotEmpty) {
              title = house.isNotEmpty ? '$street, $house' : street;
            } else if (name.isNotEmpty) {
              title = house.isNotEmpty ? '$name, $house' : name;
            } else if (district.isNotEmpty) {
              title = district;
            }

            if (title.isNotEmpty) {
              suggestions.add(
                AddressSuggestion(
                  displayName: title,
                  lat: (coords[1] as num).toDouble(),
                  lng: (coords[0] as num).toDouble(),
                ),
              );
            }
          }

          if (suggestions.isNotEmpty) return suggestions;
        }
      }
    } catch (e) {
      debugPrint('Photon Search Exception: $e');
    }

    // Уровень 2: fallback на Nominatim, если Photon вернул 0 результатов
    try {
      final searchQuery = '$cleanQuery, $cityName';
      final Uri nominatimUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(searchQuery)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=6'
        '&accept-language=ru',
      );

      final response = await http.get(
        nominatimUrl,
        headers: {'User-Agent': 'TulparTaxiApp/1.0 (kz.tulpar.app@gmail.com)'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((item) {
          final address = item['address'] as Map<String, dynamic>?;
          String title = item['display_name'] ?? '';

          if (address != null) {
            final road =
                address['road'] ??
                address['pedestrian'] ??
                address['building'] ??
                '';
            final house = address['house_number'] ?? '';
            if (road.toString().isNotEmpty) {
              title = house.toString().isNotEmpty ? '$road, $house' : '$road';
            }
          }

          return AddressSuggestion(
            displayName: title,
            lat: double.parse(item['lat'].toString()),
            lng: double.parse(item['lon'].toString()),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Nominatim Search Exception: $e');
    }

    return [];
  }

  // 2. Обратное геокодирование (клик на карте -> адрес)
  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final Uri photonUrl = Uri.parse(
        'https://photon.komoot.io/reverse?lat=$lat&lon=$lng&lang=ru',
      );
      final response = await http.get(photonUrl);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        final List features = data['features'] ?? [];

        if (features.isNotEmpty) {
          final props = features.first['properties'] as Map<String, dynamic>;

          final String name = props['name']?.toString() ?? '';
          final String street = props['street']?.toString() ?? '';
          final String house = props['housenumber']?.toString() ?? '';
          final String district =
              props['district']?.toString() ??
              props['suburb']?.toString() ??
              props['city']?.toString() ??
              '';

          if (street.isNotEmpty && house.isNotEmpty) return '$street, $house';
          if (street.isNotEmpty) return street;
          if (name.isNotEmpty && house.isNotEmpty) return '$name, $house';
          if (name.isNotEmpty) return name;
          if (district.isNotEmpty) return district;
        }
      }
    } catch (e) {
      debugPrint('Photon Reverse Exception: $e');
    }

    try {
      final Uri nominatimUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1&accept-language=ru',
      );
      final response = await http.get(
        nominatimUrl,
        headers: {'User-Agent': 'TulparTaxiApp/1.0 (kz.tulpar.app@gmail.com)'},
      );

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final road =
              address['road'] ??
              address['pedestrian'] ??
              address['building'] ??
              address['amenity'] ??
              address['suburb'] ??
              '';
          final houseNumber = address['house_number'] ?? '';

          if (road.toString().isNotEmpty) {
            return houseNumber.toString().isNotEmpty
                ? '$road, $houseNumber'
                : '$road';
          }
        }

        if (data['display_name'] != null) {
          final parts = (data['display_name'] as String).split(',');
          if (parts.length >= 2) {
            return '${parts[0].trim()}, ${parts[1].trim()}';
          }
          return parts[0].trim();
        }
      }
    } catch (e) {
      debugPrint('Nominatim Reverse Exception: $e');
    }

    return 'Точка на карте (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})';
  }
}
