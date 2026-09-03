import 'package:latlong2/latlong.dart';

class LiveMarkerSampleResult {
  const LiveMarkerSampleResult({
    required this.accepted,
    required this.snapped,
    required this.duration,
  });

  final bool accepted;
  final bool snapped;
  final Duration duration;
}

class LiveMarkerInterpolationController {
  LiveMarkerInterpolationController({
    this.minimumDuration = const Duration(milliseconds: 250),
    this.maximumDuration = const Duration(milliseconds: 4500),
    this.defaultDuration = const Duration(milliseconds: 800),
    this.durationFactor = 0.9,
    this.teleportThresholdMeters = 1000,
    this.maximumAccuracyMeters = 50,
  });

  final Duration minimumDuration;
  final Duration maximumDuration;
  final Duration defaultDuration;
  final double durationFactor;
  final double teleportThresholdMeters;
  final double maximumAccuracyMeters;

  static const Distance _distance = Distance();

  LatLng? _start;
  LatLng? _target;
  DateTime? _animationStartedAt;
  DateTime? _lastSampleAt;
  Duration _duration = Duration.zero;
  bool _disposed = false;

  LatLng? positionAt(DateTime now) {
    final target = _target;
    final start = _start;
    final animationStartedAt = _animationStartedAt;
    if (target == null || start == null || animationStartedAt == null) {
      return target;
    }
    if (_duration == Duration.zero) return target;
    final elapsed = now.difference(animationStartedAt);
    final fraction =
        elapsed.inMicroseconds / _duration.inMicroseconds.clamp(1, 1 << 62);
    final t = fraction.clamp(0.0, 1.0);
    return LatLng(
      start.latitude + (target.latitude - start.latitude) * t,
      start.longitude + (target.longitude - start.longitude) * t,
    );
  }

  LiveMarkerSampleResult addSample({
    required LatLng position,
    required DateTime timestamp,
    double? accuracyMeters,
  }) {
    final accurateEnough =
        accuracyMeters == null ||
        (accuracyMeters.isFinite &&
            accuracyMeters >= 0 &&
            accuracyMeters <= maximumAccuracyMeters);
    if (_disposed || !accurateEnough) {
      return const LiveMarkerSampleResult(
        accepted: false,
        snapped: false,
        duration: Duration.zero,
      );
    }

    final current = positionAt(timestamp);
    final previousSampleAt = _lastSampleAt;
    _lastSampleAt = timestamp;
    if (current == null ||
        _distance.as(LengthUnit.Meter, current, position) >=
            teleportThresholdMeters) {
      _start = position;
      _target = position;
      _animationStartedAt = timestamp;
      _duration = Duration.zero;
      return const LiveMarkerSampleResult(
        accepted: true,
        snapped: true,
        duration: Duration.zero,
      );
    }

    final distanceMeters = _distance.as(LengthUnit.Meter, current, position);
    if (distanceMeters < 0.5) {
      _start = position;
      _target = position;
      _animationStartedAt = timestamp;
      _duration = Duration.zero;
      return const LiveMarkerSampleResult(
        accepted: true,
        snapped: false,
        duration: Duration.zero,
      );
    }

    final interval = previousSampleAt == null
        ? defaultDuration
        : timestamp.difference(previousSampleAt);
    final scaledMicroseconds = (interval.inMicroseconds * durationFactor)
        .round();
    final durationMicroseconds = scaledMicroseconds.clamp(
      minimumDuration.inMicroseconds,
      maximumDuration.inMicroseconds,
    );
    _start = current;
    _target = position;
    _animationStartedAt = timestamp;
    _duration = Duration(microseconds: durationMicroseconds);
    return LiveMarkerSampleResult(
      accepted: true,
      snapped: false,
      duration: _duration,
    );
  }

  void reset() {
    _start = null;
    _target = null;
    _animationStartedAt = null;
    _lastSampleAt = null;
    _duration = Duration.zero;
  }

  void dispose() {
    reset();
    _disposed = true;
  }
}
