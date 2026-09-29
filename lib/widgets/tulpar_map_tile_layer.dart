import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart';
import 'package:url_launcher/url_launcher.dart';

const tulparMapStyleUrl = 'https://maps.tulpartaxi.kz/styles/tulpar/style.json';
const tulparOsmAttributionUrl = 'https://www.openstreetmap.org/copyright';

@visibleForTesting
Future<void> synchronizeTulparMapCamera(
  fm.MapCamera camera,
  MapController controller,
) => controller.moveCamera(
  center: Geographic(lon: camera.center.longitude, lat: camera.center.latitude),
  zoom: camera.zoom - 1,
  bearing: -camera.rotation,
);

@immutable
class TulparMapCameraFrame {
  const TulparMapCameraFrame({
    required this.center,
    required this.zoom,
    required this.bearing,
  });

  factory TulparMapCameraFrame.fromFlutterMap(fm.MapCamera camera) =>
      TulparMapCameraFrame(
        center: camera.center,
        zoom: camera.zoom - 1,
        // FlutterMap uses the inverse sign of MapLibre's geographic bearing.
        bearing: -camera.rotation,
      );

  final LatLng center;
  final double zoom;
  final double bearing;
}

/// Serializes Android camera calls and coalesces animation frames while a
/// previous platform call is still in flight. This prevents stale frames from
/// overtaking the latest navigation center/bearing on a real platform view.
class TulparMapCameraBridge {
  MapController? _controller;
  _QueuedCameraFrame? _pending;
  Future<void>? _drainFuture;
  int _generation = 0;

  void attach(MapController controller) {
    _generation++;
    _pending = null;
    _controller = controller;
  }

  void detach() {
    _generation++;
    _pending = null;
    _controller = null;
  }

  void cancelPending() {
    _generation++;
    _pending = null;
  }

  Future<void> applyFlutterMapCamera(fm.MapCamera camera) =>
      applyFrame(TulparMapCameraFrame.fromFlutterMap(camera));

  Future<void> applyFrame(TulparMapCameraFrame frame) {
    _pending = _QueuedCameraFrame(frame, _generation);
    return _drainFuture ??= Future<void>.microtask(_drain).whenComplete(() {
      _drainFuture = null;
      if (_pending != null && _controller != null) {
        unawaited(applyFrame(_pending!.frame));
      }
    });
  }

  Future<void> _drain() async {
    while (true) {
      final queued = _pending;
      final controller = _controller;
      if (queued == null || controller == null) return;
      _pending = null;
      if (queued.generation != _generation) continue;
      final frame = queued.frame;
      await controller.moveCamera(
        center: Geographic(
          lon: frame.center.longitude,
          lat: frame.center.latitude,
        ),
        zoom: frame.zoom,
        bearing: frame.bearing,
      );
    }
  }
}

class _QueuedCameraFrame {
  const _QueuedCameraFrame(this.frame, this.generation);

  final TulparMapCameraFrame frame;
  final int generation;
}

class TulparMapTileLayer extends StatefulWidget {
  const TulparMapTileLayer({super.key, this.layerBuilder, this.cameraBridge});

  @visibleForTesting
  final WidgetBuilder? layerBuilder;
  final TulparMapCameraBridge? cameraBridge;

  @override
  State<TulparMapTileLayer> createState() => _TulparMapTileLayerState();
}

class TulparMapAttribution extends StatelessWidget {
  const TulparMapAttribution({super.key, this.openUrl});

  final Future<bool> Function(Uri url)? openUrl;

  Future<void> _openAttribution() async {
    final url = Uri.parse(tulparOsmAttributionUrl);
    final launcher = openUrl;
    if (launcher != null) {
      await launcher(url);
      return;
    }
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.all(4),
    child: Align(
      alignment: Alignment.bottomRight,
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          key: const Key('osm_attribution_link'),
          onTap: _openAttribution,
          borderRadius: BorderRadius.circular(4),
          child: Semantics(
            link: true,
            label: 'OpenStreetMap copyright and attribution',
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              child: Text(
                '© OpenStreetMap contributors',
                maxLines: 1,
                textScaler: TextScaler.linear(1),
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TulparMapTileLayerState extends State<TulparMapTileLayer> {
  bool _layoutReady = false;
  bool _activationScheduled = false;
  MapController? _mapLibreController;
  final TulparMapCameraBridge _ownedCameraBridge = TulparMapCameraBridge();
  fm.MapController? _flutterMapController;
  StreamSubscription<fm.MapEvent>? _cameraEvents;

  TulparMapCameraBridge get _cameraBridge =>
      widget.cameraBridge ?? _ownedCameraBridge;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tests and placeholders may use the injected builder outside FlutterMap.
    if (widget.layerBuilder != null) return;
    final controller = fm.MapController.of(context);
    if (identical(controller, _flutterMapController)) return;
    unawaited(_cameraEvents?.cancel());
    _flutterMapController = controller;
    _cameraEvents = controller.mapEventStream.listen((event) {
      if (event is fm.MapEventWithMove) {
        unawaited(_cameraBridge.applyFlutterMapCamera(event.camera));
      }
    });
  }

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
      await _cameraBridge.applyFlutterMapCamera(camera);
    });
  }

  @override
  void didUpdateWidget(covariant TulparMapTileLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraBridge == widget.cameraBridge) return;
    (oldWidget.cameraBridge ?? _ownedCameraBridge).detach();
    final controller = _mapLibreController;
    if (controller != null) {
      _cameraBridge.attach(controller);
      _resyncFlutterMapCamera();
    }
  }

  @override
  void dispose() {
    unawaited(_cameraEvents?.cancel());
    _cameraBridge.detach();
    super.dispose();
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
        if (_mapLibreController != null) _cameraBridge.detach();
        _layoutReady = false;
        _mapLibreController = null;
      } else {
        _activateAfterLayout();
      }
      if (!_layoutReady || !hasUsableSize) return const SizedBox.expand();

      final testBuilder = widget.layerBuilder;
      if (testBuilder != null) return testBuilder(context);
      final flutterCamera = fm.MapCamera.of(context);
      return Stack(
        fit: StackFit.expand,
        children: [
          MapLibreMap(
            options: MapOptions(
              initCenter: Geographic(
                lon: flutterCamera.center.longitude,
                lat: flutterCamera.center.latitude,
              ),
              initBearing: -flutterCamera.rotation,
              initZoom: flutterCamera.zoom - 1,
              initStyle: tulparMapStyleUrl,
              maxPitch: 0,
              gestures: const MapGestures.none(),
            ),
            gestureRecognizers: const {},
            onMapCreated: (controller) {
              _mapLibreController = controller;
              _cameraBridge.attach(controller);
              _resyncFlutterMapCamera();
            },
            onEvent: (event) {
              if (event is MapEventStyleLoaded) {
                _resyncFlutterMapCamera();
              }
            },
          ),
          const TulparMapAttribution(),
        ],
      );
    },
  );
}
