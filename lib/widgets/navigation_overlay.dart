import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/navigation_step.dart';

class NavigationOverlay extends StatefulWidget {
  final List<NavigationStep> steps;
  final VoidCallback? onOffRoute;

  const NavigationOverlay({
    super.key,
    required this.steps,
    this.onOffRoute,
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
    _startLocationTracking();
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
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (_currentStepIndex >= widget.steps.length || _isRecalculating) return;

      final currentStep = widget.steps[_currentStepIndex];

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        currentStep.targetLat,
        currentStep.targetLng,
      );

      setState(() {
        _distanceToNextStep = distance;
      });

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
          (distance - _minDistanceToCurrentStep > 45)) {
        _triggerRecalculation();
      }
    });
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

  IconData _getManeuverIcon(String modifier) {
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
      case 'uturn':
        return Icons.u_turn_left;
      default:
        return Icons.straight;
    }
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
                  _isRecalculating
                      ? Icons.sync
                      : _getManeuverIcon(step.modifier),
                  color: Colors.black,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isRecalculating
                          ? 'Перерасчет...'
                          : (_distanceToNextStep > 1000
                              ? '${(_distanceToNextStep / 1000).toStringAsFixed(1)} км'
                              : '${_distanceToNextStep.toInt()} м'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _isRecalculating
                          ? 'Вы сбились с маршрута'
                          : (step.streetName.isNotEmpty
                              ? step.streetName
                              : 'Следуйте по маршруту'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
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