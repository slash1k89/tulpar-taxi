import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/navigation_step.dart';

class NavigationProgressState {
  const NavigationProgressState({
    required this.currentStepIndex,
    required this.currentStep,
    required this.distanceToManeuverMeters,
    this.remainingDistanceMeters,
    this.remainingDurationSeconds,
    this.didAdvance = false,
  });

  final int currentStepIndex;
  final NavigationStep? currentStep;
  final double? distanceToManeuverMeters;
  final double? remainingDistanceMeters;
  final double? remainingDurationSeconds;
  final bool didAdvance;
}

class NavigationProgressController {
  NavigationProgressController({
    this.advancementRadiusMeters = 25,
    this.maximumAdvancementAccuracyMeters = 50,
    this.requiredConfirmationSamples = 2,
    this.advancementCooldown = const Duration(seconds: 2),
  });

  final double advancementRadiusMeters;
  final double maximumAdvancementAccuracyMeters;
  final int requiredConfirmationSamples;
  final Duration advancementCooldown;

  static const Distance _distance = Distance();

  List<NavigationStep> _steps = const [];
  List<NavigationStep>? _stepsIdentity;
  int? _routeGeneration;
  int _currentStepIndex = 0;
  int _confirmationSamples = 0;
  DateTime? _lastAdvancementAt;
  double? _distanceToManeuverMeters;
  LatLng? _previousAccuratePosition;
  double? _previousAccurateDistanceMeters;
  bool _hasApproachEvidence = false;

  NavigationProgressState get state => _state();

  void replaceRoute({
    required List<NavigationStep> steps,
    required int routeGeneration,
  }) {
    if (_routeGeneration == routeGeneration &&
        identical(_stepsIdentity, steps)) {
      return;
    }
    _routeGeneration = routeGeneration;
    _stepsIdentity = steps;
    _steps = steps;
    _currentStepIndex = _initialUsefulStepIndex(steps);
    _confirmationSamples = 0;
    _lastAdvancementAt = null;
    _distanceToManeuverMeters = null;
    _previousAccuratePosition = null;
    _previousAccurateDistanceMeters = null;
    _hasApproachEvidence = false;
  }

  NavigationProgressState updatePosition({
    required LatLng position,
    double? accuracyMeters,
    DateTime? timestamp,
  }) {
    if (_steps.isEmpty || _currentStepIndex >= _steps.length) return _state();

    final step = _steps[_currentStepIndex];
    if (!_hasUsableCoordinate(step)) {
      _distanceToManeuverMeters = null;
      _confirmationSamples = 0;
      return _state();
    }

    final directDistanceToManeuverMeters = _distance.as(
      LengthUnit.Meter,
      position,
      LatLng(step.targetLat, step.targetLng),
    );
    _distanceToManeuverMeters = directDistanceToManeuverMeters;

    final accurateEnough =
        accuracyMeters == null ||
        (accuracyMeters.isFinite &&
            accuracyMeters >= 0 &&
            accuracyMeters <= maximumAdvancementAccuracyMeters);
    final now = timestamp ?? DateTime.now();
    final cooldownActive =
        _lastAdvancementAt != null &&
        now.difference(_lastAdvancementAt!) < advancementCooldown;
    final isClose = directDistanceToManeuverMeters < advancementRadiusMeters;

    if (!accurateEnough) {
      _confirmationSamples = 0;
      return _state();
    }

    final previousDistance = _previousAccurateDistanceMeters;
    if (directDistanceToManeuverMeters <= advancementRadiusMeters * 3 ||
        (previousDistance != null &&
            directDistanceToManeuverMeters + 5 < previousDistance)) {
      _hasApproachEvidence = true;
    }
    final passedManeuver =
        _hasApproachEvidence &&
        (_didCrossManeuver(
              previousPosition: _previousAccuratePosition,
              position: position,
              step: step,
            ) ||
            (previousDistance != null &&
                previousDistance <= advancementRadiusMeters * 2 &&
                directDistanceToManeuverMeters > previousDistance + 5 &&
                directDistanceToManeuverMeters <= advancementRadiusMeters * 3));
    _previousAccuratePosition = position;
    _previousAccurateDistanceMeters = directDistanceToManeuverMeters;

    if (cooldownActive || (!isClose && !passedManeuver)) {
      _confirmationSamples = 0;
      return _state();
    }

    if (!passedManeuver) _confirmationSamples++;
    if ((!passedManeuver &&
            _confirmationSamples < requiredConfirmationSamples) ||
        _currentStepIndex >= _steps.length - 1) {
      return _state();
    }

    _currentStepIndex++;
    _confirmationSamples = 0;
    _lastAdvancementAt = now;
    _previousAccuratePosition = position;
    _previousAccurateDistanceMeters = null;
    _hasApproachEvidence = false;
    final nextStep = _steps[_currentStepIndex];
    _distanceToManeuverMeters = _hasUsableCoordinate(nextStep)
        ? _distance.as(
            LengthUnit.Meter,
            position,
            LatLng(nextStep.targetLat, nextStep.targetLng),
          )
        : null;
    return _state(didAdvance: true);
  }

  bool _didCrossManeuver({
    required LatLng? previousPosition,
    required LatLng position,
    required NavigationStep step,
  }) {
    if (previousPosition == null || _currentStepIndex >= _steps.length - 1) {
      return false;
    }
    final nextStep = _steps[_currentStepIndex + 1];
    if (!_hasUsableCoordinate(nextStep)) return false;

    final maneuver = LatLng(step.targetLat, step.targetLng);
    final outgoing = _metersFrom(
      maneuver,
      LatLng(nextStep.targetLat, nextStep.targetLng),
    );
    final before = _metersFrom(maneuver, previousPosition);
    final after = _metersFrom(maneuver, position);
    final outgoingLengthSquared =
        outgoing.$1 * outgoing.$1 + outgoing.$2 * outgoing.$2;
    if (outgoingLengthSquared < 1) return false;

    final beforeProgress =
        _dot(before, outgoing) / math.sqrt(outgoingLengthSquared);
    final afterProgress =
        _dot(after, outgoing) / math.sqrt(outgoingLengthSquared);
    final afterLateral =
        _crossMagnitude(after, outgoing) / math.sqrt(outgoingLengthSquared);
    final crossingDistance = _distanceToSegmentMeters(
      maneuver,
      previousPosition,
      position,
    );

    return beforeProgress <= 5 &&
        afterProgress > 5 &&
        afterLateral <= math.max(advancementRadiusMeters * 2, 40) &&
        crossingDistance <= math.max(advancementRadiusMeters * 3, 75);
  }

  static (double, double) _metersFrom(LatLng origin, LatLng point) {
    const metersPerDegreeLatitude = 111320.0;
    final metersPerDegreeLongitude =
        metersPerDegreeLatitude * math.cos(origin.latitude * math.pi / 180);
    return (
      (point.longitude - origin.longitude) * metersPerDegreeLongitude,
      (point.latitude - origin.latitude) * metersPerDegreeLatitude,
    );
  }

  static double _dot((double, double) a, (double, double) b) =>
      a.$1 * b.$1 + a.$2 * b.$2;

  static double _crossMagnitude((double, double) a, (double, double) b) =>
      (a.$1 * b.$2 - a.$2 * b.$1).abs();

  static double _distanceToSegmentMeters(
    LatLng origin,
    LatLng start,
    LatLng end,
  ) {
    final a = _metersFrom(origin, start);
    final b = _metersFrom(origin, end);
    final segment = (b.$1 - a.$1, b.$2 - a.$2);
    final lengthSquared = _dot(segment, segment);
    if (lengthSquared < 1) return math.sqrt(_dot(a, a));
    final t = (-_dot(a, segment) / lengthSquared).clamp(0.0, 1.0);
    final closest = (a.$1 + segment.$1 * t, a.$2 + segment.$2 * t);
    return math.sqrt(_dot(closest, closest));
  }

  NavigationProgressState _state({bool didAdvance = false}) =>
      NavigationProgressState(
        currentStepIndex: _currentStepIndex,
        currentStep: _steps.isEmpty || _currentStepIndex >= _steps.length
            ? null
            : _steps[_currentStepIndex],
        distanceToManeuverMeters: _distanceToManeuverMeters,
        remainingDistanceMeters: _remainingDistanceMeters(),
        remainingDurationSeconds: _remainingDurationSeconds(),
        didAdvance: didAdvance,
      );

  double? _remainingDistanceMeters() {
    if (_steps.isEmpty || _currentStepIndex >= _steps.length) return null;
    final current = _steps[_currentStepIndex];
    final currentDistance = _safeCurrentDistance(current);
    final future = _steps
        .skip(_currentStepIndex + 1)
        .fold<double>(0, (sum, step) => sum + _safeMetric(step.distanceMeters));
    final result = currentDistance + future;
    return result.isFinite && result >= 0 ? result : null;
  }

  double? _remainingDurationSeconds() {
    if (_steps.isEmpty || _currentStepIndex >= _steps.length) return null;
    final current = _steps[_currentStepIndex];
    final stepDistance = _safeMetric(current.distanceMeters);
    final stepDuration = _safeMetric(current.durationSeconds);
    final currentDistance = _safeCurrentDistance(current);
    final currentDuration = stepDistance > 0
        ? stepDuration * (currentDistance / stepDistance).clamp(0.0, 1.0)
        : stepDuration;
    final future = _steps
        .skip(_currentStepIndex + 1)
        .fold<double>(
          0,
          (sum, step) => sum + _safeMetric(step.durationSeconds),
        );
    final result = currentDuration + future;
    return result.isFinite && result >= 0 ? result : null;
  }

  double _safeCurrentDistance(NavigationStep step) {
    final configured = _safeMetric(step.distanceMeters);
    final live = _distanceToManeuverMeters;
    if (live == null || !live.isFinite || live < 0) return configured;
    return configured > 0 ? live.clamp(0.0, configured) : live;
  }

  static double _safeMetric(double value) =>
      value.isFinite && value >= 0 ? value : 0;

  static bool _hasUsableCoordinate(NavigationStep step) =>
      step.targetLat.isFinite &&
      step.targetLng.isFinite &&
      step.targetLat >= -90 &&
      step.targetLat <= 90 &&
      step.targetLng >= -180 &&
      step.targetLng <= 180;

  static int _initialUsefulStepIndex(List<NavigationStep> steps) {
    if (steps.length < 2) return 0;
    final firstUseful = steps.indexWhere(
      (step) => step.type.trim().toLowerCase().replaceAll('_', ' ') != 'depart',
    );
    return firstUseful <= 0 ? 0 : firstUseful;
  }
}
