import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/intercity_pickup_draft.dart';
import '../../widgets/tulpar_map_tile_layer.dart';
import '../../widgets/tulpar_map_visuals.dart';

class IntercityPickupViewerScreen extends StatelessWidget {
  const IntercityPickupViewerScreen({
    super.key,
    required this.pickup,
    this.showMapTiles = true,
  });

  final IntercityPickupDraft pickup;
  final bool showMapTiles;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Точка посадки')),
    body: Stack(
      children: [
        FlutterMap(
          key: const Key('intercity_pickup_readonly_map'),
          options: MapOptions(
            initialCenter: pickup.point,
            initialZoom: 16,
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(
                const LatLng(-90, -180),
                const LatLng(90, 180),
              ),
            ),
          ),
          children: [
            if (showMapTiles) const TulparMapTileLayer(),
            MarkerLayer(
              markers: [
                TulparMapVisuals.endpointMarker(
                  key: const Key('intercity_pickup_marker'),
                  point: pickup.point,
                  endpoint: TulparMapEndpoint.pickup,
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pickup.address,
                        key: const Key('intercity_pickup_viewer_address'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
