import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DriverLocationMarkerLayer extends StatelessWidget {
  const DriverLocationMarkerLayer({
    super.key,
    required this.positionListenable,
    required this.marker,
    this.width = 45,
    this.height = 45,
  });

  final ValueListenable<LatLng?> positionListenable;
  final Widget marker;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LatLng?>(
      valueListenable: positionListenable,
      child: marker,
      builder: (context, position, marker) {
        if (position == null) return const SizedBox.shrink();
        return MarkerLayer(
          markers: [
            Marker(
              point: position,
              width: width,
              height: height,
              child: marker!,
            ),
          ],
        );
      },
    );
  }
}
