import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/navigation_step.dart';

class RouteService {
  // Метод для водителя: получает пошаговые инструкции для навигации
  static Future fetchSteps({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$destLng,$destLat?steps=true&geometries=geojson',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map;
        final routes = data['routes'] as List?;

        if (routes == null || routes.isEmpty) {
          return [];
        }

        final legs = routes[0]['legs'] as List?;
        if (legs == null || legs.isEmpty) {
          return [];
        }

        final List stepsData = legs[0]['steps'] ?? [];
        return stepsData
            .map((e) => NavigationStep.fromJson(e as Map))
            .toList();
      } else {
        throw Exception('Ошибка загрузки маршрута: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка сети при получении маршрута: $e');
    }
  }

  // Метод для пассажира: получает только точки для отрисовки линии (Polyline)
  static Future<List<LatLng>> fetchRouteGeometry({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$destLng,$destLat?geometries=geojson',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map;
        final routes = data['routes'] as List?;

        if (routes == null || routes.isEmpty) {
          return [];
        }

        final List coordinates = routes[0]['geometry']['coordinates'];
        // OSRM возвращает [longitude, latitude], а FlutterMap требует LatLng(latitude, longitude)
        return coordinates.map((c) => LatLng(c[1], c[0])).toList();
      } else {
        throw Exception('Ошибка загрузки геометрии маршрута: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка сети при получении геометрии: $e');
    }
  }
}