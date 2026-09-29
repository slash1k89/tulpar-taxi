import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/navigation_step.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/navigation_progress_controller.dart';
import '../services/navigation_voice_service.dart';
import '../utils/navigation_instruction_formatter.dart';

class NavigationOverlay extends StatefulWidget {
  const NavigationOverlay({
    super.key,
    required this.steps,
    this.routeGeneration = 0,
    this.routeDistanceMeters,
    this.routeDurationSeconds,
    this.onOffRoute,
    this.positionListenable,
    this.positionAccuracyProvider,
    this.isRerouting = false,
    this.rerouteErrorMessage,
    this.voiceController,
    this.voiceEnabled = true,
    this.voiceActive = true,
    this.routePhase = 'navigation',
    this.routeTarget,
  });

  final List<NavigationStep> steps;
  final int routeGeneration;
  final double? routeDistanceMeters;
  final double? routeDurationSeconds;

  // Kept for source compatibility with the unused legacy navigation screen.
  // Stage 11C will connect real route-geometry based off-route detection.
  final VoidCallback? onOffRoute;
  final ValueListenable<LatLng?>? positionListenable;
  final double? Function()? positionAccuracyProvider;
  final bool isRerouting;
  final String? rerouteErrorMessage;
  final NavigationVoiceController? voiceController;
  final bool voiceEnabled;
  final bool voiceActive;
  final String routePhase;
  final LatLng? routeTarget;

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay> {
  late final NavigationProgressController _progressController;
  late NavigationProgressState _progress;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _progressController = NavigationProgressController();
    _replaceRoute();
    if (widget.positionListenable != null) {
      widget.positionListenable!.addListener(_handleListenablePosition);
      _readCurrentListenablePosition();
    } else {
      _startLocationTracking();
    }
  }

  @override
  void didUpdateWidget(covariant NavigationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeGeneration != widget.routeGeneration ||
        !identical(oldWidget.steps, widget.steps)) {
      _replaceRoute();
      _readCurrentListenablePosition();
    }
    if (oldWidget.voiceEnabled != widget.voiceEnabled ||
        oldWidget.voiceActive != widget.voiceActive) {
      _updateVoice();
    }
    if (oldWidget.positionListenable != widget.positionListenable) {
      oldWidget.positionListenable?.removeListener(_handleListenablePosition);
      _positionSubscription?.cancel();
      _positionSubscription = null;
      if (widget.positionListenable != null) {
        widget.positionListenable!.addListener(_handleListenablePosition);
        _readCurrentListenablePosition();
      } else {
        _startLocationTracking();
      }
    }
  }

  @override
  void dispose() {
    widget.voiceController?.update(
      active: false,
      enabled: widget.voiceEnabled,
      stepIndex: _progress.currentStepIndex,
      step: _progress.currentStep,
      distanceMeters: _progress.distanceToManeuverMeters,
    );
    widget.positionListenable?.removeListener(_handleListenablePosition);
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _replaceRoute() {
    _progressController.replaceRoute(
      steps: widget.steps,
      routeGeneration: widget.routeGeneration,
    );
    _progress = _progressController.state;
    widget.voiceController?.replaceRoute(widget.routeGeneration);
    _updateVoice();
  }

  void _readCurrentListenablePosition() {
    final position = widget.positionListenable?.value;
    if (position == null) return;
    _progress = _progressController.updatePosition(
      position: position,
      accuracyMeters: widget.positionAccuracyProvider?.call(),
    );
    _updateVoice();
  }

  void _handleListenablePosition() {
    final position = widget.positionListenable?.value;
    if (position == null || !mounted) return;
    final next = _progressController.updatePosition(
      position: position,
      accuracyMeters: widget.positionAccuracyProvider?.call(),
    );
    setState(() => _progress = next);
    if (kDebugMode) {
      final target = widget.routeTarget;
      final targetDistance = target == null
          ? null
          : const Distance().as(LengthUnit.Meter, position, target);
      debugPrint(
        '[Nav] phase=${widget.routePhase} step=${next.currentStepIndex} '
        'maneuver=${next.currentStep?.type}/${next.currentStep?.modifier} '
        'distanceToManeuver=${next.distanceToManeuverMeters?.round()} '
        'distanceToTarget=${targetDistance?.round()} '
        'accuracy=${widget.positionAccuracyProvider?.call()} '
        'arrival=${_arrivalConfirmed()}',
      );
    }
    _updateVoice();
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            if (!mounted) return;
            final next = _progressController.updatePosition(
              position: LatLng(position.latitude, position.longitude),
              accuracyMeters: position.accuracy,
            );
            setState(() => _progress = next);
            _updateVoice();
          },
        );
  }

  void _updateVoice() {
    final arrivalConfirmed = _arrivalConfirmed();
    widget.voiceController?.update(
      active: widget.voiceActive,
      enabled: widget.voiceEnabled,
      stepIndex: _progress.currentStepIndex,
      step: _progress.currentStep,
      distanceMeters: _progress.distanceToManeuverMeters,
      arrivalConfirmed: arrivalConfirmed,
    );
  }

  bool _arrivalConfirmed() {
    final step = _progress.currentStep;
    if (step?.type.trim().toLowerCase() != 'arrive') return true;
    final position = widget.positionListenable?.value;
    final target = widget.routeTarget;
    if (position == null || target == null) return false;
    return navigationArrivalConfirmed(
      position: position,
      target: target,
      accuracyMeters: widget.positionAccuracyProvider?.call(),
    );
  }

  IconData _maneuverIcon(NavigationManeuverIcon icon) => switch (icon) {
    NavigationManeuverIcon.left => Icons.turn_left,
    NavigationManeuverIcon.right => Icons.turn_right,
    NavigationManeuverIcon.slightLeft => Icons.turn_slight_left,
    NavigationManeuverIcon.slightRight => Icons.turn_slight_right,
    NavigationManeuverIcon.sharpLeft => Icons.turn_sharp_left,
    NavigationManeuverIcon.sharpRight => Icons.turn_sharp_right,
    NavigationManeuverIcon.straight => Icons.straight,
    NavigationManeuverIcon.keepLeft ||
    NavigationManeuverIcon.keepRight => Icons.call_split,
    NavigationManeuverIcon.merge => Icons.merge,
    NavigationManeuverIcon.ramp => Icons.alt_route,
    NavigationManeuverIcon.uTurn => Icons.u_turn_left,
    NavigationManeuverIcon.roundaboutLeft => Icons.roundabout_left,
    NavigationManeuverIcon.roundaboutRight => Icons.roundabout_right,
    NavigationManeuverIcon.arrive => Icons.flag,
    NavigationManeuverIcon.depart => Icons.navigation,
  };

  @override
  Widget build(BuildContext context) {
    final step = _progress.currentStep;
    if (step == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final presentation = NavigationInstructionFormatter.formatLocalized(
      step,
      l10n,
      distanceToManeuverMeters: _progress.distanceToManeuverMeters,
      arrivalConfirmed: _arrivalConfirmed(),
    );
    final hasLiveSummary =
        (_progress.remainingDistanceMeters ?? 0) > 0 &&
        (_progress.remainingDurationSeconds ?? 0) > 0;
    final routeSummary =
        NavigationInstructionFormatter.formatRouteSummaryLocalized(
          distanceMeters: hasLiveSummary
              ? _progress.remainingDistanceMeters
              : widget.routeDistanceMeters,
          durationSeconds: hasLiveSummary
              ? _progress.remainingDurationSeconds
              : widget.routeDurationSeconds,
          l10n: l10n,
        );
    final semanticsLabel = [
      presentation.distanceLabel,
      presentation.instruction,
      presentation.streetName,
      if (routeSummary != null) l10n.navRemaining(routeSummary),
      if (widget.isRerouting) l10n.navigationRecalculating,
      widget.rerouteErrorMessage,
    ].whereType<String>().join('. ');
    final colors = Theme.of(context).colorScheme;

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Semantics(
        container: true,
        label: semanticsLabel,
        child: ExcludeSemantics(
          child: Card(
            color: colors.surface,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _maneuverIcon(presentation.icon),
                      color: colors.onPrimaryContainer,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (presentation.distanceLabel != null) ...[
                          Text(
                            presentation.distanceLabel!,
                            key: const Key('navigation_distance'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          presentation.instruction,
                          key: const Key('navigation_instruction'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 22,
                            height: 1.08,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (presentation.streetName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            presentation.streetName!,
                            key: const Key('navigation_street'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ],
                        if (routeSummary != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            routeSummary,
                            key: const Key('navigation_route_summary'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (widget.isRerouting) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.navigationRecalculating,
                            key: const Key('navigation_rerouting'),
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ] else if (widget.rerouteErrorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.rerouteErrorMessage!,
                            key: const Key('navigation_reroute_error'),
                            style: TextStyle(color: colors.error, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool navigationArrivalConfirmed({
  required LatLng position,
  required LatLng target,
  double? accuracyMeters,
  double thresholdMeters = 40,
}) {
  if (accuracyMeters != null &&
      (!accuracyMeters.isFinite || accuracyMeters > 50)) {
    return false;
  }
  return const Distance().as(LengthUnit.Meter, position, target) <=
      thresholdMeters;
}
