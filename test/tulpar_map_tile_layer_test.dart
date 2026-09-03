import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:taxi_esil/widgets/tulpar_map_tile_layer.dart';

void main() {
  testWidgets('resync reaches MapLibre even when FlutterMap move is a no-op', (
    tester,
  ) async {
    final flutterController = fm.MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: fm.FlutterMap(
          mapController: flutterController,
          options: const fm.MapOptions(
            initialCenter: LatLng(51.95, 66.4),
            initialZoom: 16,
            initialRotation: -90,
          ),
          children: const [],
        ),
      ),
    );
    final camera = flutterController.camera;
    expect(flutterController.move(camera.center, camera.zoom), isFalse);
    final native = _CameraRecorder();
    await synchronizeTulparMapCamera(camera, native);
    expect(native.calls, 1);
    expect(native.center!.lat, camera.center.latitude);
    expect(native.center!.lon, camera.center.longitude);
    expect(native.zoom, 15);
    expect(native.bearing, 90);
    await tester.pumpWidget(const SizedBox());
    flutterController.dispose();
  });

  testWidgets('map layer activates only after a non-zero layout frame', (
    tester,
  ) async {
    const layerKey = Key('map-layer-ready');

    Widget app(double size) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: TulparMapTileLayer(
            layerBuilder: (_) =>
                const ColoredBox(key: layerKey, color: Colors.blue),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(0));
    await tester.pump();
    expect(find.byKey(layerKey), findsNothing);

    await tester.pumpWidget(app(300));
    expect(find.byKey(layerKey), findsNothing);
    await tester.pump();
    expect(find.byKey(layerKey), findsOneWidget);
    await tester.pumpWidget(app(0));
    expect(find.byKey(layerKey), findsNothing);
    await tester.pumpWidget(app(400));
    expect(find.byKey(layerKey), findsNothing);
    await tester.pump();
    expect(find.byKey(layerKey), findsOneWidget);
  });
}

class _CameraRecorder implements ml.MapController {
  int calls = 0;
  ml.Geographic? center;
  double? zoom;
  double? bearing;

  @override
  Future<void> moveCamera({
    ml.Geographic? center,
    double? zoom,
    double? bearing,
    double? pitch,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    calls++;
    this.center = center;
    this.zoom = zoom;
    this.bearing = bearing;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
