import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_map_maplibre/flutter_map_maplibre.dart';
import 'package:maplibre/maplibre.dart';

const tulparMapStyleUrl = 'https://maps.tulpartaxi.kz/styles/tulpar/style.json';

@visibleForTesting
Future<void> synchronizeTulparMapCamera(
  fm.MapCamera camera,
  MapController controller,
) => controller.moveCamera(
  center: Geographic(lon: camera.center.longitude, lat: camera.center.latitude),
  zoom: camera.zoom - 1,
  bearing: -camera.rotation,
);

class TulparMapTileLayer extends StatefulWidget {
  const TulparMapTileLayer({super.key, this.layerBuilder});

  @visibleForTesting
  final WidgetBuilder? layerBuilder;

  @override
  State<TulparMapTileLayer> createState() => _TulparMapTileLayerState();
}

class _TulparMapTileLayerState extends State<TulparMapTileLayer> {
  bool _layoutReady = false;
  bool _activationScheduled = false;
  MapController? _mapLibreController;

  void _activateAfterLayout() {
    if (_layoutReady || _activationScheduled) return;
    _activationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _layoutReady = true;
        _activationScheduled = false;
      });
    });
  }

  void _resyncFlutterMapCamera() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = _mapLibreController;
      if (controller == null) return;
      final camera = fm.MapCamera.of(context);
      // FlutterMap.move with the same center/zoom is a no-op: it emits no
      // bridge event. Synchronize the existing native controller directly.
      await synchronizeTulparMapCamera(camera, controller);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final hasUsableSize =
          constraints.hasBoundedWidth &&
          constraints.hasBoundedHeight &&
          constraints.maxWidth.isFinite &&
          constraints.maxHeight.isFinite &&
          constraints.maxWidth > 0 &&
          constraints.maxHeight > 0;
      if (!hasUsableSize) {
        _layoutReady = false;
        _mapLibreController = null;
      } else {
        _activateAfterLayout();
      }
      if (!_layoutReady || !hasUsableSize) return const SizedBox.expand();

      final testBuilder = widget.layerBuilder;
      if (testBuilder != null) return testBuilder(context);
      return MapLibreLayer(
        initStyle: tulparMapStyleUrl,
        onEvent: (event) {
          if (event is MapEventMapCreated) {
            _mapLibreController = event.mapController;
          }
          if (event is MapEventMapCreated || event is MapEventStyleLoaded) {
            _resyncFlutterMapCamera();
          }
        },
      );
    },
  );
}
