import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class NavigationCameraUpdate {
  const NavigationCameraUpdate({
    required this.accepted,
    required this.headingDegrees,
    required this.didUpdateHeading,
  });

  final bool accepted;
  final double? headingDegrees;
  final bool didUpdateHeading;
}

class NavigationCameraController {
  NavigationCameraController({
    this.maximumAccuracyMeters = 50,
    this.minimumMovementMeters = 8,
    this.minimumHeadingSpeedMetersPerSecond = 1.5,
    this.headingSmoothing = 0.65,
  });

  final double maximumAccuracyMeters;
  final double minimumMovementMeters;
  final double minimumHeadingSpeedMetersPerSecond;
  final double headingSmoothing;

  static const Distance _distance = Distance();

  LatLng? _previousPosition;
  double? _headingDegrees;
  bool following = true;
  int _generation = 0;

  int beginCameraUpdate() => ++_generation;
  bool canApply(int generation) => following && generation == _generation;
  void suspendFollow() {
    following = false;
    _generation++;
  }

  void resumeFollow() {
    following = true;
    _generation++;
  }

  double? get headingDegrees => _headingDegrees;

  void reset() {
    _generation++;
    _previousPosition = null;
    _headingDegrees = null;
  }

  NavigationCameraUpdate update({
    required LatLng position,
    double? accuracyMeters,
    double? reportedHeadingDegrees,
    double? speedMetersPerSecond,
    List<LatLng> routeAhead = const [],
  }) {
    final accurateEnough =
        accuracyMeters == null ||
        (accuracyMeters.isFinite &&
            accuracyMeters >= 0 &&
            accuracyMeters <= maximumAccuracyMeters);
    if (!accurateEnough) {
      return NavigationCameraUpdate(
        accepted: false,
        headingDegrees: _headingDegrees,
        didUpdateHeading: false,
      );
    }

    final previous = _previousPosition;
    final movementMeters = previous == null
        ? 0.0
        : _distance.as(LengthUnit.Meter, previous, position);
    final moving =
        (speedMetersPerSecond?.isFinite ?? false) &&
            speedMetersPerSecond! >= minimumHeadingSpeedMetersPerSecond ||
        movementMeters >= minimumMovementMeters;

    double? targetHeading;
    final movementHeading =
        movementMeters >= minimumMovementMeters && previous != null
        ? _bearing(previous, position)
        : null;
    final reportedHeadingValid =
        reportedHeadingDegrees != null &&
        reportedHeadingDegrees.isFinite &&
        reportedHeadingDegrees >= 0 &&
        reportedHeadingDegrees < 360;
    final routeHeading = bearingAlongRoute(position, routeAhead);
    if (routeHeading != null) {
      targetHeading = routeHeading;
    } else if (moving && reportedHeadingValid) {
      final reportedMovementDifference = movementHeading == null
          ? 0.0
          : shortestAngularDifference(
              reportedHeadingDegrees,
              movementHeading,
            ).abs();
      // Some Android providers keep reporting a stale (often zero) heading.
      // Once actual displacement is available, prefer it when the sensor value
      // clearly contradicts the direction of travel.
      targetHeading = movementHeading != null && reportedMovementDifference > 75
          ? movementHeading
          : reportedHeadingDegrees;
    } else {
      targetHeading = movementHeading;
    }

    // Accumulate short GPS steps instead of discarding displacement < 8m.
    if (previous == null || movementMeters >= minimumMovementMeters) {
      _previousPosition = position;
    }
    if (targetHeading == null) {
      return NavigationCameraUpdate(
        accepted: true,
        headingDegrees: _headingDegrees,
        didUpdateHeading: false,
      );
    }

    final oldHeading = _headingDegrees;
    if (oldHeading != null &&
        shortestAngularDifference(oldHeading, targetHeading).abs() < 1) {
      return NavigationCameraUpdate(
        accepted: true,
        headingDegrees: oldHeading,
        didUpdateHeading: false,
      );
    }
    _headingDegrees = oldHeading == null
        ? _normalize(targetHeading)
        : _normalize(
            oldHeading +
                shortestAngularDifference(oldHeading, targetHeading) *
                    headingSmoothing,
          );
    return NavigationCameraUpdate(
      accepted: true,
      headingDegrees: _headingDegrees,
      didUpdateHeading: true,
    );
  }

  static double shortestAngularDifference(double from, double to) =>
      ((to - from + 540) % 360) - 180;

  // Input is already trimmed to monotonically confirmed route progress.
  // A short, distance-capped look-ahead cannot select an old/opposite segment.
  double? bearingAlongRoute(LatLng position, List<LatLng> route) {
    if (route.length < 2 ||
        _distance.as(LengthUnit.Meter, position, route.first) > 50) {
      return null;
    }
    var remaining = 12.0;
    var travelled = 0.0;
    var target = route.first;
    for (var i = 1; i < route.length; i++) {
      final start = route[i - 1];
      final end = route[i];
      final length = _distance.as(LengthUnit.Meter, start, end);
      if (length < 0.01) continue;
      final fraction = math.min(remaining / length, 1.0);
      target = LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      );
      travelled += length * fraction;
      remaining -= length * fraction;
      if (remaining <= 0.01) break;
    }
    if (travelled < 2 ||
        _distance.as(LengthUnit.Meter, route.first, target) < 2) {
      return null;
    }
    return _bearing(route.first, target);
  }

  static double _normalize(double value) => (value % 360 + 360) % 360;

  static double _bearing(LatLng from, LatLng to) {
    final fromLat = from.latitude * math.pi / 180;
    final toLat = to.latitude * math.pi / 180;
    final deltaLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(deltaLng) * math.cos(toLat);
    final x =
        math.cos(fromLat) * math.sin(toLat) -
        math.sin(fromLat) * math.cos(toLat) * math.cos(deltaLng);
    return _normalize(math.atan2(y, x) * 180 / math.pi);
  }
}
