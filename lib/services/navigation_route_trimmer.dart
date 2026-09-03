import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class NavigationRouteTrimmer {
  NavigationRouteTrimmer({
    this.maximumAccuracyMeters = 50,
    this.maximumForwardJumpMeters = 150,
    this.maximumProjectionDistanceMeters = 80,
  });

  final double maximumAccuracyMeters;
  final double maximumForwardJumpMeters;
  final double maximumProjectionDistanceMeters;

  static const Distance _distance = Distance();

  List<LatLng> _fullRoute = const [];
  List<double> _cumulativeMeters = const [];
  List<LatLng> _visibleRoute = const [];
  double _confirmedProgressMeters = 0;
  int _confirmedSegmentIndex = 0;

  List<LatLng> get visibleRoute => _visibleRoute;
  double get confirmedProgressMeters => _confirmedProgressMeters;

  void replaceRoute(List<LatLng> geometry) {
    _fullRoute = List<LatLng>.unmodifiable(geometry);
    _visibleRoute = _fullRoute;
    _confirmedProgressMeters = 0;
    _confirmedSegmentIndex = 0;
    if (_fullRoute.isEmpty) {
      _cumulativeMeters = const [];
      return;
    }
    final cumulative = <double>[0];
    for (var index = 1; index < _fullRoute.length; index++) {
      cumulative.add(
        cumulative.last +
            _distance.as(
              LengthUnit.Meter,
              _fullRoute[index - 1],
              _fullRoute[index],
            ),
      );
    }
    _cumulativeMeters = List<double>.unmodifiable(cumulative);
  }

  void reset() => replaceRoute(const []);

  bool updatePosition({required LatLng position, double? accuracyMeters}) {
    final accurateEnough =
        accuracyMeters == null ||
        (accuracyMeters.isFinite &&
            accuracyMeters >= 0 &&
            accuracyMeters <= maximumAccuracyMeters);
    if (!accurateEnough || _fullRoute.length < 2) return false;

    _Projection? best;
    for (
      var index = _confirmedSegmentIndex;
      index < _fullRoute.length - 1;
      index++
    ) {
      final segmentStart = _cumulativeMeters[index];
      if (segmentStart > _confirmedProgressMeters + maximumForwardJumpMeters) {
        break;
      }
      final candidate = _projectToSegment(
        position,
        _fullRoute[index],
        _fullRoute[index + 1],
        index,
        segmentStart,
      );
      if (candidate.progressMeters + 0.5 < _confirmedProgressMeters) continue;
      if (candidate.progressMeters >
          _confirmedProgressMeters + maximumForwardJumpMeters) {
        continue;
      }
      if (best == null || candidate.distanceMeters < best.distanceMeters) {
        best = candidate;
      }
    }
    if (best == null ||
        best.distanceMeters > maximumProjectionDistanceMeters ||
        best.progressMeters <= _confirmedProgressMeters + 0.5) {
      return false;
    }

    _confirmedProgressMeters = best.progressMeters;
    _confirmedSegmentIndex = best.segmentIndex;
    _visibleRoute = List<LatLng>.unmodifiable([
      best.point,
      ..._fullRoute.skip(best.segmentIndex + 1),
    ]);
    return true;
  }

  _Projection _projectToSegment(
    LatLng point,
    LatLng start,
    LatLng end,
    int segmentIndex,
    double segmentStartMeters,
  ) {
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
    final fraction = lengthSquared <= 0
        ? 0.0
        : (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared).clamp(
            0.0,
            1.0,
          );
    final projectedX = a.x + fraction * dx;
    final projectedY = a.y + fraction * dy;
    final segmentLength = math.sqrt(lengthSquared);

    return _Projection(
      point: LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      ),
      segmentIndex: segmentIndex,
      progressMeters: segmentStartMeters + segmentLength * fraction,
      distanceMeters: math.sqrt(
        math.pow(p.x - projectedX, 2) + math.pow(p.y - projectedY, 2),
      ),
    );
  }
}

class _Projection {
  const _Projection({
    required this.point,
    required this.segmentIndex,
    required this.progressMeters,
    required this.distanceMeters,
  });

  final LatLng point;
  final int segmentIndex;
  final double progressMeters;
  final double distanceMeters;
}
