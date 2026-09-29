import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:taxi_esil/widgets/tulpar_map_tile_layer.dart';

void main() {
  testWidgets('OSM attribution is accessible and opens copyright page', (
    tester,
  ) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TulparMapAttribution(
            openUrl: (url) async {
              opened = url;
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    await tester.tap(find.byKey(const Key('osm_attribution_link')));
    await tester.pump();
    expect(opened.toString(), tulparOsmAttributionUrl);
  });

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

  test('live bridge applies changed center and geographic bearing', () async {
    final native = _CameraRecorder();
    final bridge = TulparMapCameraBridge()..attach(native);

    await bridge.applyFrame(
      const TulparMapCameraFrame(
        center: LatLng(51.95, 66.4),
        zoom: 15.5,
        bearing: 0,
      ),
    );
    await bridge.applyFrame(
      const TulparMapCameraFrame(
        center: LatLng(51.951, 66.402),
        zoom: 15.5,
        bearing: 90,
      ),
    );

    expect(native.calls, 2);
    expect(native.center, const ml.Geographic(lon: 66.402, lat: 51.951));
    expect(native.bearing, 90);
  });

  test(
    'live bridge coalesces delayed Android updates to latest frame',
    () async {
      final native = _DelayedCameraRecorder();
      final bridge = TulparMapCameraBridge()..attach(native);
      final first = bridge.applyFrame(
        const TulparMapCameraFrame(
          center: LatLng(51, 71),
          zoom: 15,
          bearing: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      bridge.applyFrame(
        const TulparMapCameraFrame(
          center: LatLng(51.001, 71.001),
          zoom: 15,
          bearing: 35,
        ),
      );
      bridge.applyFrame(
        const TulparMapCameraFrame(
          center: LatLng(51.002, 71.002),
          zoom: 15,
          bearing: 42,
        ),
      );
      native.releaseFirst();
      await first;

      expect(native.frames, hasLength(2));
      expect(native.frames.last.center.lat, 51.002);
      expect(native.frames.last.center.lon, 71.002);
      expect(native.frames.last.bearing, 42);
    },
  );

  test('cancelPending drops a stale delayed navigation frame', () async {
    final native = _DelayedCameraRecorder();
    final bridge = TulparMapCameraBridge()..attach(native);
    final first = bridge.applyFrame(
      const TulparMapCameraFrame(center: LatLng(51, 71), zoom: 15, bearing: 0),
    );
    await Future<void>.delayed(Duration.zero);
    bridge.applyFrame(
      const TulparMapCameraFrame(
        center: LatLng(52, 72),
        zoom: 15,
        bearing: 180,
      ),
    );
    bridge.cancelPending();
    native.releaseFirst();
    await first;

    expect(native.frames, hasLength(1));
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

class _DelayedCameraRecorder implements ml.MapController {
  final Completer<void> _first = Completer<void>();
  final List<({ml.Geographic center, double bearing})> frames = [];

  void releaseFirst() => _first.complete();

  @override
  Future<void> moveCamera({
    ml.Geographic? center,
    double? zoom,
    double? bearing,
    double? pitch,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    frames.add((center: center!, bearing: bearing!));
    if (frames.length == 1) await _first.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
