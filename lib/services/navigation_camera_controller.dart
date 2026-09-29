import 'dart:async';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class NavigationCameraUpdate {
  const NavigationCameraUpdate({
    required this.accepted,
    required this.headingDegrees,
    required this.didUpdateHeading,
    required this.routeBearingDegrees,
    required this.targetHeadingDegrees,
  });

  final bool accepted;
  final double? headingDegrees;
  final bool didUpdateHeading;
  final double? routeBearingDegrees;
  final double? targetHeadingDegrees;
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
  bool _userSuspended = false;
  int _generation = 0;

  int beginCameraUpdate() => ++_generation;
  bool canApply(int generation) => following && generation == _generation;
  void suspendFollow() {
    following = false;
    _userSuspended = true;
    _generation++;
  }

  void resumeFollow() {
    following = true;
    _userSuspended = false;
    _generation++;
  }

  double? get headingDegrees => _headingDegrees;
  bool get userSuspended => _userSuspended;

  void reset() {
    _generation++;
    _previousPosition = null;
    _headingDegrees = null;
  }

  /// Route/status rebuilds preserve an explicit user pan, but never turn an
  /// already-following camera off.
  void restoreAfterNavigationChange() {
    _generation++;
    _previousPosition = null;
    _headingDegrees = null;
    if (!_userSuspended) following = true;
  }

  NavigationCameraUpdate update({
    required LatLng position,
    double? accuracyMeters,
    double? reportedHeadingDegrees,
    double? speedMetersPerSecond,
    List<LatLng> routeAhead = const [],
    bool snapToRoute = false,
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
        routeBearingDegrees: null,
        targetHeadingDegrees: null,
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
        routeBearingDegrees: routeHeading,
        targetHeadingDegrees: null,
      );
    }

    final oldHeading = _headingDegrees;
    if (oldHeading != null &&
        shortestAngularDifference(oldHeading, targetHeading).abs() < 1) {
      return NavigationCameraUpdate(
        accepted: true,
        headingDegrees: oldHeading,
        didUpdateHeading: false,
        routeBearingDegrees: routeHeading,
        targetHeadingDegrees: targetHeading,
      );
    }
    _headingDegrees =
        oldHeading == null || (snapToRoute && routeHeading != null)
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
      routeBearingDegrees: routeHeading,
      targetHeadingDegrees: targetHeading,
    );
  }

  static double shortestAngularDifference(double from, double to) =>
      ((to - from + 540) % 360) - 180;

  // Input is already trimmed to monotonically confirmed route progress.
  // Prefer the closest forward segment rather than the bearing from the old
  // trim point: GPS may be tens of metres ahead of it immediately after a turn.
  double? bearingAlongRoute(LatLng position, List<LatLng> route) {
    if (route.length < 2) return null;
    double? bestDistance;
    double? bestBearing;
    var scannedMeters = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      final segmentLength = _distance.as(LengthUnit.Meter, start, end);
      if (segmentLength < 2) continue;
      scannedMeters += segmentLength;
      if (scannedMeters > 250 && bestBearing != null) break;
      final latScale = math.cos(position.latitude * math.pi / 180);
      final dx = (end.longitude - start.longitude) * latScale;
      final dy = end.latitude - start.latitude;
      final denominator = dx * dx + dy * dy;
      if (denominator <= 0) continue;
      final fraction =
          (((position.longitude - start.longitude) * latScale * dx +
                      (position.latitude - start.latitude) * dy) /
                  denominator)
              .clamp(0.0, 1.0);
      final nearest = LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      );
      final distance = _distance.as(LengthUnit.Meter, position, nearest);
      if (distance > 80 ||
          (bestDistance != null && distance > bestDistance + 0.5)) {
        continue;
      }
      // At a corner equal-distance candidates favour the newer segment.
      bestDistance = distance;
      bestBearing = _bearing(start, end);
    }
    return bestBearing;
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

/// Re-enables camera follow only after the final user interaction is quiet.
class NavigationFollowResumeTimer {
  NavigationFollowResumeTimer({
    required this.canResume,
    required this.onResume,
    this.delay = const Duration(milliseconds: 3500),
  });

  final bool Function() canResume;
  final void Function() onResume;
  final Duration delay;
  Timer? _timer;

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void schedule() {
    cancel();
    _timer = Timer(delay, () {
      _timer = null;
      if (canResume()) onResume();
    });
  }

  void dispose() => cancel();
}
