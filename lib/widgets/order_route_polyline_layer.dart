import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'tulpar_map_visuals.dart';

const orderRoutePolylineLayerKey = Key('order_route_polyline_layer');

class OrderRoutePolylineLayer extends StatelessWidget {
  const OrderRoutePolylineLayer({
    super.key,
    required this.routeFuture,
    required this.onRouteReady,
  });

  final Future<List<LatLng>> routeFuture;
  final ValueChanged<List<LatLng>> onRouteReady;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LatLng>>(
      future: routeFuture,
      builder: (context, snapshot) {
        final points = snapshot.data;
        if (points == null || points.length < 2) {
          return const SizedBox.shrink();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onRouteReady(points);
        });
        return PolylineLayer(
          key: orderRoutePolylineLayerKey,
          polylines: [TulparMapVisuals.routePolyline(points)],
        );
      },
    );
  }
}
