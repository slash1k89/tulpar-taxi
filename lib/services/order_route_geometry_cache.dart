import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

import 'route_service.dart';
import '../models/order_stops.dart';

typedef OrderRouteLoader =
    Future<List<LatLng>> Function({
      required double startLat,
      required double startLng,
      required double destLat,
      required double destLng,
    });

typedef OrderRouteLoadFailure =
    void Function(Object error, StackTrace stackTrace);

typedef MultiStopOrderRouteLoader =
    Future<List<LatLng>> Function({
      required double startLat,
      required double startLng,
      required double destLat,
      required double destLng,
      required List<LatLng> intermediatePoints,
    });

class OrderRouteEndpoints {
  const OrderRouteEndpoints({
    required this.start,
    required this.destination,
    this.intermediatePoints = const [],
  });

  final LatLng start;
  final LatLng destination;
  final List<LatLng> intermediatePoints;

  static OrderRouteEndpoints? fromOrderData(Map<String, dynamic> orderData) {
    final fromLat = _coordinate(orderData['fromLat']);
    final fromLng = _coordinate(orderData['fromLng']);
    final toLat = _coordinate(orderData['toLat']);
    final toLng = _coordinate(orderData['toLng']);
    if (fromLat == null ||
        fromLng == null ||
        toLat == null ||
        toLng == null ||
        fromLat < -90 ||
        fromLat > 90 ||
        toLat < -90 ||
        toLat > 90 ||
        fromLng < -180 ||
        fromLng > 180 ||
        toLng < -180 ||
        toLng > 180) {
      return null;
    }
    final intermediatePoints = <LatLng>[];
    final stops = orderStopsFromData(orderData);
    if (stops.length > 1) {
      for (final stop in stops.take(stops.length - 1)) {
        final latitude = _coordinate(stop.raw['latitude'] ?? stop.raw['lat']);
        final longitude = _coordinate(stop.raw['longitude'] ?? stop.raw['lng']);
        if (latitude != null &&
            longitude != null &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180) {
          intermediatePoints.add(LatLng(latitude, longitude));
        }
      }
    }
    return OrderRouteEndpoints(
      start: LatLng(fromLat, fromLng),
      destination: LatLng(toLat, toLng),
      intermediatePoints: List.unmodifiable(intermediatePoints),
    );
  }

  static double? _coordinate(Object? value) {
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
    return parsed?.isFinite == true ? parsed : null;
  }

  @override
  bool operator ==(Object other) =>
      other is OrderRouteEndpoints &&
      start == other.start &&
      destination == other.destination &&
      listEquals(intermediatePoints, other.intermediatePoints);

  @override
  int get hashCode =>
      Object.hash(start, destination, Object.hashAll(intermediatePoints));
}

/// Keeps one route Future for stable order endpoints.
///
/// Order status and driver location updates therefore reuse the completed
/// geometry. A straight line remains available when OSRM is unavailable.
class OrderRouteGeometryCache {
  OrderRouteGeometryCache({
    OrderRouteLoader? loader,
    MultiStopOrderRouteLoader? multiStopLoader,
    OrderRouteLoadFailure? onFailure,
  }) : _loader = loader ?? RouteService.fetchRouteGeometry,
       _multiStopLoader =
           multiStopLoader ??
           (({
             required double startLat,
             required double startLng,
             required double destLat,
             required double destLng,
             required List<LatLng> intermediatePoints,
           }) => RouteService.fetchRouteGeometry(
             startLat: startLat,
             startLng: startLng,
             destLat: destLat,
             destLng: destLng,
             intermediatePoints: intermediatePoints,
           )),
       _onFailure = onFailure;

  final OrderRouteLoader _loader;
  final MultiStopOrderRouteLoader _multiStopLoader;
  final OrderRouteLoadFailure? _onFailure;

  OrderRouteEndpoints? _endpoints;
  Future<List<LatLng>>? _routeFuture;

  Future<List<LatLng>> load(OrderRouteEndpoints endpoints) {
    final cached = _routeFuture;
    if (cached != null && endpoints == _endpoints) return cached;

    _endpoints = endpoints;
    return _routeFuture = _loadWithFallback(endpoints);
  }

  Future<List<LatLng>> _loadWithFallback(OrderRouteEndpoints endpoints) async {
    try {
      final points = endpoints.intermediatePoints.isEmpty
          ? await _loader(
              startLat: endpoints.start.latitude,
              startLng: endpoints.start.longitude,
              destLat: endpoints.destination.latitude,
              destLng: endpoints.destination.longitude,
            )
          : await _multiStopLoader(
              startLat: endpoints.start.latitude,
              startLng: endpoints.start.longitude,
              destLat: endpoints.destination.latitude,
              destLng: endpoints.destination.longitude,
              intermediatePoints: endpoints.intermediatePoints,
            );
      if (points.length >= 2) return List<LatLng>.unmodifiable(points);
      throw StateError('RouteService returned fewer than two points.');
    } catch (error, stackTrace) {
      _onFailure?.call(error, stackTrace);
      return List<LatLng>.unmodifiable([
        endpoints.start,
        ...endpoints.intermediatePoints,
        endpoints.destination,
      ]);
    }
  }

  void clear() {
    _endpoints = null;
    _routeFuture = null;
  }
}
