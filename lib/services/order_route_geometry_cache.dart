import 'package:latlong2/latlong.dart';

import 'route_service.dart';

typedef OrderRouteLoader =
    Future<List<LatLng>> Function({
      required double startLat,
      required double startLng,
      required double destLat,
      required double destLng,
    });

typedef OrderRouteLoadFailure =
    void Function(Object error, StackTrace stackTrace);

class OrderRouteEndpoints {
  const OrderRouteEndpoints({required this.start, required this.destination});

  final LatLng start;
  final LatLng destination;

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
    return OrderRouteEndpoints(
      start: LatLng(fromLat, fromLng),
      destination: LatLng(toLat, toLng),
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
      destination == other.destination;

  @override
  int get hashCode => Object.hash(start, destination);
}

/// Keeps one route Future for stable order endpoints.
///
/// Order status and driver location updates therefore reuse the completed
/// geometry. A straight line remains available when OSRM is unavailable.
class OrderRouteGeometryCache {
  OrderRouteGeometryCache({
    OrderRouteLoader? loader,
    OrderRouteLoadFailure? onFailure,
  }) : _loader = loader ?? RouteService.fetchRouteGeometry,
       _onFailure = onFailure;

  final OrderRouteLoader _loader;
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
      final points = await _loader(
        startLat: endpoints.start.latitude,
        startLng: endpoints.start.longitude,
        destLat: endpoints.destination.latitude,
        destLng: endpoints.destination.longitude,
      );
      if (points.length >= 2) return List<LatLng>.unmodifiable(points);
      throw StateError('RouteService returned fewer than two points.');
    } catch (error, stackTrace) {
      _onFailure?.call(error, stackTrace);
      return List<LatLng>.unmodifiable([
        endpoints.start,
        endpoints.destination,
      ]);
    }
  }

  void clear() {
    _endpoints = null;
    _routeFuture = null;
  }
}
