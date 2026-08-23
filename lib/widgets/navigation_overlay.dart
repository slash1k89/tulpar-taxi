import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/navigation_step.dart';

class NavigationOverlay extends StatefulWidget {
  final List<NavigationStep> steps;
  final VoidCallback? onOffRoute;
  final ValueListenable<LatLng?>? positionListenable;

  const NavigationOverlay({
    super.key,
    required this.steps,
    this.onOffRoute,
    this.positionListenable,
  });

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay> {
  int _currentStepIndex = 0;
  double _distanceToNextStep = 0.0;
  double _minDistanceToCurrentStep = double.infinity;
  bool _isRecalculating = false;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.positionListenable != null) {
      widget.positionListenable!.addListener(_handleListenablePosition);
      _handleListenablePosition();
    } else {
      _startLocationTracking();
    }
  }

  @override
  void didUpdateWidget(covariant NavigationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps != widget.steps) {
      setState(() {
        _currentStepIndex = 0;
        _minDistanceToCurrentStep = double.infinity;
        _isRecalculating = false;
      });
    }
    if (oldWidget.positionListenable != widget.positionListenable) {
      oldWidget.positionListenable?.removeListener(_handleListenablePosition);
      _positionSubscription?.cancel();
      _positionSubscription = null;
      if (widget.positionListenable != null) {
        widget.positionListenable!.addListener(_handleListenablePosition);
        _handleListenablePosition();
      } else {
        _startLocationTracking();
      }
    }
  }

  @override
  void dispose() {
    widget.positionListenable?.removeListener(_handleListenablePosition);
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _handleListenablePosition() {
    final position = widget.positionListenable?.value;
    if (position == null) return;
    _handlePosition(position.latitude, position.longitude);
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _handlePosition(position.latitude, position.longitude);
          },
        );
  }

  void _handlePosition(double latitude, double longitude) {
    if (!mounted ||
        _currentStepIndex >= widget.steps.length ||
        _isRecalculating) {
      return;
    }

    final currentStep = widget.steps[_currentStepIndex];
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      currentStep.targetLat,
      currentStep.targetLng,
    );

    setState(() => _distanceToNextStep = distance);

    if (distance < _minDistanceToCurrentStep) {
      _minDistanceToCurrentStep = distance;
    }

    if (distance < 15 && _currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _minDistanceToCurrentStep = double.infinity;
      });
      return;
    }

    if (_minDistanceToCurrentStep != double.infinity &&
        distance - _minDistanceToCurrentStep > 45) {
      _triggerRecalculation();
    }
  }

  void _triggerRecalculation() {
    if (_isRecalculating) return;

    setState(() {
      _isRecalculating = true;
    });

    if (widget.onOffRoute != null) {
      widget.onOffRoute!();
    }
  }

  IconData _getManeuverIcon(NavigationStep step) {
    final type = step.type.toLowerCase().trim();
    final modifier = step.modifier.toLowerCase().trim();

    if (type == 'arrive') return Icons.flag;
    if (type == 'roundabout' || type == 'rotary') {
      return modifier.contains('left')
          ? Icons.roundabout_left
          : Icons.roundabout_right;
    }
    if (type == 'merge') return Icons.merge;
    if (type == 'fork') return Icons.call_split;
    if (type == 'uturn' || modifier == 'uturn') return Icons.u_turn_left;

    switch (modifier) {
      case 'left':
      case 'sharp left':
        return Icons.turn_left;
      case 'slight left':
        return Icons.turn_slight_left;
      case 'right':
      case 'sharp right':
        return Icons.turn_right;
      case 'slight right':
        return Icons.turn_slight_right;
      default:
        return Icons.straight;
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return 'через ${(meters / 1000).toStringAsFixed(1)} км';
    }
    return 'через ${meters.round()} м';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty || _currentStepIndex >= widget.steps.length) {
      return const SizedBox.shrink();
    }

    final step = widget.steps[_currentStepIndex];

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        color: const Color(0xFF1E1E1E),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isRecalculating ? Colors.orange : Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecalculating ? Icons.sync : _getManeuverIcon(step),
                  color: Colors.black,
                  size: 42,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isRecalculating ? 'Перерасчёт...' : step.instruction,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isRecalculating
                          ? 'Вы сбились с маршрута'
                          : _formatDistance(_distanceToNextStep),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!_isRecalculating && step.streetName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.streetName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
