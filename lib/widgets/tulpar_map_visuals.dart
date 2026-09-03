import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum TulparMapEndpoint { pickup, destination }

abstract final class TulparMapVisuals {
  static const routeColor = Color(0xFF007C91);
  static const routeOutlineColor = Colors.white;
  static const pickupColor = Color(0xFF159447);
  static const destinationColor = Color(0xFFE55259);
  static const userLocationColor = Color(0xFF1565C0);
  static const vehicleColor = Color(0xFF1565C0);

  static const routeStrokeWidth = 6.5;
  static const routeOutlineWidth = 2.5;
  static const endpointMarkerSize = 48.0;
  static const userLocationMarkerSize = 44.0;
  static const vehicleMarkerSize = 50.0;
  static const selectionPinSize = 48.0;

  static Polyline routePolyline(List<LatLng> points) => Polyline(
    points: points,
    strokeWidth: routeStrokeWidth,
    color: routeColor,
    borderStrokeWidth: routeOutlineWidth,
    borderColor: routeOutlineColor,
  );

  static Marker endpointMarker({
    Key? key,
    required LatLng point,
    required TulparMapEndpoint endpoint,
  }) => Marker(
    key: key,
    point: point,
    width: endpointMarkerSize,
    height: endpointMarkerSize,
    rotate: true,
    child: TulparEndpointMarker(endpoint: endpoint),
  );

  static Marker userLocationMarker({Key? key, required LatLng point}) => Marker(
    key: key,
    point: point,
    width: userLocationMarkerSize,
    height: userLocationMarkerSize,
    rotate: true,
    child: const TulparUserLocationMarker(),
  );

  static Widget rotateToHeading({
    required Widget child,
    required double? headingDegrees,
  }) {
    final heading = headingDegrees;
    if (heading == null || !heading.isFinite || heading < 0) return child;
    return Transform.rotate(angle: heading * math.pi / 180, child: child);
  }
}

class TulparSelectionPin extends StatelessWidget {
  const TulparSelectionPin({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Выбранная точка',
    child: Transform.translate(
      key: const Key('map_selection_pin_anchor'),
      offset: const Offset(0, -TulparMapVisuals.selectionPinSize / 2),
      child: const SizedBox.square(
        dimension: TulparMapVisuals.selectionPinSize,
        child: CustomPaint(painter: _TulparSelectionPinPainter()),
      ),
    ),
  );
}

class _TulparSelectionPinPainter extends CustomPainter {
  const _TulparSelectionPinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.39);
    final radius = size.width * 0.34;
    final path = ui.Path()
      ..moveTo(center.dx, size.height)
      ..cubicTo(
        size.width * 0.40,
        size.height * 0.78,
        center.dx - radius,
        size.height * 0.60,
        center.dx - radius,
        center.dy,
      )
      ..arcToPoint(
        Offset(center.dx + radius, center.dy),
        radius: Radius.circular(radius),
        largeArc: true,
      )
      ..cubicTo(
        center.dx + radius,
        size.height * 0.60,
        size.width * 0.60,
        size.height * 0.78,
        center.dx,
        size.height,
      )
      ..close();
    canvas.drawShadow(path, const Color(0x66000000), 4, true);
    canvas.drawPath(path, Paint()..color = TulparMapVisuals.routeColor);
    canvas.drawCircle(
      center,
      size.width * 0.105,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _TulparSelectionPinPainter oldDelegate) => false;
}

class TulparEndpointMarker extends StatelessWidget {
  const TulparEndpointMarker({super.key, required this.endpoint});

  final TulparMapEndpoint endpoint;

  @override
  Widget build(BuildContext context) {
    final isPickup = endpoint == TulparMapEndpoint.pickup;
    final color = isPickup
        ? TulparMapVisuals.pickupColor
        : TulparMapVisuals.destinationColor;
    return Semantics(
      label: isPickup ? 'Точка подачи' : 'Точка назначения',
      child: SizedBox.square(
        dimension: TulparMapVisuals.endpointMarkerSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x52000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isPickup ? Icons.person_pin_circle : Icons.flag,
              color: Colors.white,
              size: 27,
            ),
          ),
        ),
      ),
    );
  }
}

class TulparUserLocationMarker extends StatelessWidget {
  const TulparUserLocationMarker({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ваше местоположение',
    child: Stack(
      alignment: Alignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: TulparMapVisuals.userLocationColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const SizedBox.expand(),
        ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Color(0x38000000), blurRadius: 5),
            ],
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: TulparMapVisuals.userLocationColor,
            shape: BoxShape.circle,
          ),
        ),
      ],
    ),
  );
}

class TulparVehicleMarker extends StatelessWidget {
  const TulparVehicleMarker({
    super.key,
    this.isDelivery = false,
    this.headingDegrees,
  });

  final bool isDelivery;
  final double? headingDegrees;

  @override
  Widget build(BuildContext context) {
    final heading = headingDegrees;
    final marker = Semantics(
      label: isDelivery ? 'Курьер на карте' : 'Автомобиль на карте',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: TulparMapVisuals.vehicleColor, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x52000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            isDelivery ? Icons.local_shipping : Icons.local_taxi,
            color: TulparMapVisuals.vehicleColor,
            size: 28,
          ),
        ),
      ),
    );
    return TulparMapVisuals.rotateToHeading(
      child: marker,
      headingDegrees: heading,
    );
  }
}
