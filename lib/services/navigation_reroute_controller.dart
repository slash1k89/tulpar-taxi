import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class NavigationRerouteDecision {
  const NavigationRerouteDecision({
    required this.shouldReroute,
    required this.distanceToRouteMeters,
    required this.confirmationSamples,
    this.ignoredForAccuracy = false,
    this.cooldownActive = false,
  });

  final bool shouldReroute;
  final double? distanceToRouteMeters;
  final int confirmationSamples;
  final bool ignoredForAccuracy;
  final bool cooldownActive;
}

class NavigationRerouteController {
  NavigationRerouteController({
    this.offRouteThresholdMeters = 45,
    this.maximumAccuracyMeters = 50,
    this.requiredConfirmationSamples = 2,
    this.cooldown = const Duration(seconds: 15),
  });

  final double offRouteThresholdMeters;
  final double maximumAccuracyMeters;
  final int requiredConfirmationSamples;
  final Duration cooldown;

  List<LatLng> _geometry = const [];
  int _confirmationSamples = 0;
  bool _requestInFlight = false;
  DateTime? _lastAttemptCompletedAt;

  bool get requestInFlight => _requestInFlight;
  int get confirmationSamples => _confirmationSamples;

  void replaceRoute(
    List<LatLng> geometry, {
    DateTime? timestamp,
    bool startCooldown = false,
  }) {
    _geometry = geometry;
    _confirmationSamples = 0;
    _requestInFlight = false;
    if (startCooldown) _lastAttemptCompletedAt = timestamp ?? DateTime.now();
  }

  void reset() {
    _geometry = const [];
    _confirmationSamples = 0;
    _requestInFlight = false;
    _lastAttemptCompletedAt = null;
  }

  NavigationRerouteDecision updatePosition({
    required LatLng position,
    double? accuracyMeters,
    DateTime? timestamp,
  }) {
    final accurateEnough =
        accuracyMeters == null ||
        (accuracyMeters.isFinite &&
            accuracyMeters >= 0 &&
            accuracyMeters <= maximumAccuracyMeters);
    if (!accurateEnough) {
      return NavigationRerouteDecision(
        shouldReroute: false,
        distanceToRouteMeters: null,
        confirmationSamples: _confirmationSamples,
        ignoredForAccuracy: true,
      );
    }

    final distance = distanceToPolylineMeters(position, _geometry);
    if (distance == null) {
      _confirmationSamples = 0;
      return const NavigationRerouteDecision(
        shouldReroute: false,
        distanceToRouteMeters: null,
        confirmationSamples: 0,
      );
    }

    final accuracyAllowance = accuracyMeters == null
        ? 0.0
        : (accuracyMeters / 2).clamp(0.0, 15.0);
    if (distance <= offRouteThresholdMeters + accuracyAllowance) {
      _confirmationSamples = 0;
      return NavigationRerouteDecision(
        shouldReroute: false,
        distanceToRouteMeters: distance,
        confirmationSamples: 0,
      );
    }

    final now = timestamp ?? DateTime.now();
    final cooldownActive =
        _lastAttemptCompletedAt != null &&
        now.difference(_lastAttemptCompletedAt!) < cooldown;
    if (_requestInFlight || cooldownActive) {
      _confirmationSamples = 0;
      return NavigationRerouteDecision(
        shouldReroute: false,
        distanceToRouteMeters: distance,
        confirmationSamples: 0,
        cooldownActive: cooldownActive,
      );
    }

    _confirmationSamples++;
    return NavigationRerouteDecision(
      shouldReroute: _confirmationSamples >= requiredConfirmationSamples,
      distanceToRouteMeters: distance,
      confirmationSamples: _confirmationSamples,
    );
  }

  void markRequestStarted() {
    _requestInFlight = true;
    _confirmationSamples = 0;
  }

  void markRequestFailed({DateTime? timestamp}) {
    _requestInFlight = false;
    _confirmationSamples = 0;
    _lastAttemptCompletedAt = timestamp ?? DateTime.now();
  }
}

double? distanceToPolylineMeters(LatLng point, List<LatLng> geometry) {
  if (!_validCoordinate(point) || geometry.isEmpty) return null;
  if (geometry.length == 1) {
    return _distanceBetweenMeters(point, geometry.single);
  }

  double? minimum;
  for (var index = 0; index < geometry.length - 1; index++) {
    final start = geometry[index];
    final end = geometry[index + 1];
    if (!_validCoordinate(start) || !_validCoordinate(end)) continue;
    final distance = _distanceToSegmentMeters(point, start, end);
    if (distance.isFinite && (minimum == null || distance < minimum)) {
      minimum = distance;
    }
  }
  return minimum;
}

double _distanceToSegmentMeters(LatLng point, LatLng start, LatLng end) {
  const earthRadius = 6371000.0;
  final referenceLatitude =
      (point.latitude + start.latitude + end.latitude) / 3 * math.pi / 180;

  ({double x, double y}) project(LatLng value) => (
    x:
        value.longitude *
        math.pi /
        180 *
        earthRadius *
        math.cos(referenceLatitude),
    y: value.latitude * math.pi / 180 * earthRadius,
  );

  final p = project(point);
  final a = project(start);
  final b = project(end);
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared <= 0) {
    return math.sqrt(math.pow(p.x - a.x, 2) + math.pow(p.y - a.y, 2));
  }
  final projection = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared;
  final t = projection.clamp(0.0, 1.0);
  final x = a.x + t * dx;
  final y = a.y + t * dy;
  return math.sqrt(math.pow(p.x - x, 2) + math.pow(p.y - y, 2));
}

double _distanceBetweenMeters(LatLng first, LatLng second) {
  const Distance distance = Distance();
  return distance.as(LengthUnit.Meter, first, second);
}

bool _validCoordinate(LatLng value) =>
    value.latitude.isFinite &&
    value.longitude.isFinite &&
    value.latitude >= -90 &&
    value.latitude <= 90 &&
    value.longitude >= -180 &&
    value.longitude <= 180;
