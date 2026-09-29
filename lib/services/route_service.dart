import 'package:latlong2/latlong.dart';

import '../models/navigation_step.dart';
import 'tulpar_api_client.dart';

class RouteResult {
  const RouteResult({
    required this.geometry,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> geometry;
  final List<NavigationStep> steps;
  final double distanceMeters;
  final double durationSeconds;
}

class RouteEndpointDiagnostics {
  const RouteEndpointDiagnostics({
    required this.startDistanceMeters,
    required this.destinationDistanceMeters,
    this.maximumSnapDistanceMeters = 250,
  });

  factory RouteEndpointDiagnostics.fromRoute({
    required List<LatLng> geometry,
    required LatLng expectedStart,
    required LatLng expectedDestination,
    double maximumSnapDistanceMeters = 250,
  }) {
    if (geometry.isEmpty) {
      return RouteEndpointDiagnostics(
        startDistanceMeters: double.infinity,
        destinationDistanceMeters: double.infinity,
        maximumSnapDistanceMeters: maximumSnapDistanceMeters,
      );
    }
    const distance = Distance();
    return RouteEndpointDiagnostics(
      startDistanceMeters: distance.as(
        LengthUnit.Meter,
        expectedStart,
        geometry.first,
      ),
      destinationDistanceMeters: distance.as(
        LengthUnit.Meter,
        expectedDestination,
        geometry.last,
      ),
      maximumSnapDistanceMeters: maximumSnapDistanceMeters,
    );
  }

  final double startDistanceMeters;
  final double destinationDistanceMeters;
  final double maximumSnapDistanceMeters;

  bool get startWithinTolerance =>
      startDistanceMeters <= maximumSnapDistanceMeters;
  bool get destinationWithinTolerance =>
      destinationDistanceMeters <= maximumSnapDistanceMeters;
}

class RouteService {
  static TulparApiClient apiClient = TulparApiClient();
  static String? _cachedKey;
  static Future<RouteResult>? _cachedRoute;

  static Future<RouteResult> fetchRoute({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
    List<LatLng> intermediatePoints = const [],
  }) {
    final viaKey = intermediatePoints
        .map((point) => '${point.latitude},${point.longitude}')
        .join(';');
    final key = '$startLat,$startLng;$viaKey;$destLat,$destLng';
    if (_cachedKey == key && _cachedRoute != null) return _cachedRoute!;
    _cachedKey = key;
    return _cachedRoute = apiClient
        .getRoute(
          startLat: startLat,
          startLng: startLng,
          destLat: destLat,
          destLng: destLng,
          intermediatePoints: intermediatePoints,
        )
        .then(parseRouteResponse)
        .catchError((Object error) {
          if (_cachedKey == key) {
            _cachedKey = null;
            _cachedRoute = null;
          }
          throw error;
        });
  }

  static RouteResult parseRouteResponse(Map<String, dynamic> data) {
    final rawGeometry = data['geometry'];
    if (rawGeometry is! List) {
      throw const FormatException('Route geometry is missing.');
    }
    final geometry = rawGeometry
        .map((point) {
          if (point is! Map) {
            throw const FormatException('Invalid route point.');
          }
          final lat = point['lat'];
          final lng = point['lng'];
          if (lat is! num || lng is! num) {
            throw const FormatException('Invalid route point.');
          }
          return LatLng(lat.toDouble(), lng.toDouble());
        })
        .toList(growable: false);

    final steps = <NavigationStep>[];
    final rawSteps = data['steps'];
    if (rawSteps is List) {
      for (final step in rawSteps) {
        try {
          if (step is Map) {
            steps.add(NavigationStep.fromJson(step));
          }
        } on Object {
          // A malformed maneuver must not hide valid route geometry.
        }
      }
    }

    return RouteResult(
      geometry: geometry,
      steps: steps,
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0,
      durationSeconds: (data['durationSeconds'] as num?)?.toDouble() ?? 0,
    );
  }

  static Future<List<NavigationStep>> fetchSteps({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
  }) async => (await fetchRoute(
    startLat: startLat,
    startLng: startLng,
    destLat: destLat,
    destLng: destLng,
  )).steps;

  static Future<List<LatLng>> fetchRouteGeometry({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
    List<LatLng> intermediatePoints = const [],
  }) async => (await fetchRoute(
    startLat: startLat,
    startLng: startLng,
    destLat: destLat,
    destLng: destLng,
    intermediatePoints: intermediatePoints,
  )).geometry;
}
