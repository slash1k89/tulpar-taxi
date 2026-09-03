import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/live_marker_interpolation_controller.dart';
import 'tulpar_map_visuals.dart';

class DriverLocationMarkerLayer extends StatefulWidget {
  const DriverLocationMarkerLayer({
    super.key,
    required this.positionListenable,
    required this.marker,
    this.width = 45,
    this.height = 45,
    this.accuracyProvider,
    this.headingProvider,
    this.maximumAnimationDuration = const Duration(milliseconds: 4500),
  });

  final ValueListenable<LatLng?> positionListenable;
  final Widget marker;
  final double width;
  final double height;
  final double? Function()? accuracyProvider;
  final double? Function()? headingProvider;
  final Duration maximumAnimationDuration;

  @override
  State<DriverLocationMarkerLayer> createState() =>
      _DriverLocationMarkerLayerState();
}

class _DriverLocationMarkerLayerState extends State<DriverLocationMarkerLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late LiveMarkerInterpolationController _interpolator;
  LatLng? _visualPosition;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this)
      ..addListener(_updateVisualPosition);
    _createInterpolator();
    widget.positionListenable.addListener(_handleTargetPosition);
    _handleTargetPosition(notify: false);
  }

  void _createInterpolator() {
    _interpolator = LiveMarkerInterpolationController(
      maximumDuration: widget.maximumAnimationDuration,
    );
  }

  @override
  void didUpdateWidget(covariant DriverLocationMarkerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionListenable != widget.positionListenable ||
        oldWidget.maximumAnimationDuration != widget.maximumAnimationDuration) {
      oldWidget.positionListenable.removeListener(_handleTargetPosition);
      _animationController.stop();
      _interpolator.dispose();
      _createInterpolator();
      widget.positionListenable.addListener(_handleTargetPosition);
      _handleTargetPosition();
    }
  }

  void _handleTargetPosition({bool notify = true}) {
    final target = widget.positionListenable.value;
    if (target == null) {
      _animationController.stop();
      _interpolator.reset();
      _visualPosition = null;
      if (notify && mounted) setState(() {});
      return;
    }

    final now = DateTime.now();
    final result = _interpolator.addSample(
      position: target,
      timestamp: now,
      accuracyMeters: widget.accuracyProvider?.call(),
    );
    if (!result.accepted) return;
    if (result.duration == Duration.zero) {
      _animationController.stop();
      _visualPosition = _interpolator.positionAt(now);
      if (notify && mounted) setState(() {});
      return;
    }
    _animationController.duration = result.duration;
    _animationController.forward(from: 0);
  }

  void _updateVisualPosition() {
    if (!mounted) return;
    setState(() => _visualPosition = _interpolator.positionAt(DateTime.now()));
  }

  @override
  void dispose() {
    widget.positionListenable.removeListener(_handleTargetPosition);
    _animationController.dispose();
    _interpolator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _visualPosition;
    if (position == null) return const SizedBox.shrink();
    return MarkerLayer(
      markers: [
        Marker(
          point: position,
          width: widget.width,
          height: widget.height,
          child: TulparMapVisuals.rotateToHeading(
            headingDegrees: widget.headingProvider?.call(),
            child: widget.marker,
          ),
        ),
      ],
    );
  }
}
