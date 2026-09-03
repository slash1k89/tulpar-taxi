import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MapLibre and PMTiles globals load before Flutter bootstrap', () {
    final index = File('web/index.html').readAsStringSync();
    final mapLibre = index.indexOf('maplibre-gl@5.13.0/dist/maplibre-gl.js');
    final pmTiles = index.indexOf('pmtiles@4.5.0/dist/pmtiles.js');
    final registration = index.indexOf('new pmtiles.Protocol()');
    final flutterBootstrap = index.indexOf(
      '<script src="flutter_bootstrap.js" async>',
    );

    expect(mapLibre, greaterThanOrEqualTo(0));
    expect(pmTiles, greaterThan(mapLibre));
    expect(registration, greaterThan(pmTiles));
    expect(flutterBootstrap, greaterThan(registration));
    expect(index, contains('maplibregl.addProtocol("pmtiles", protocol.tile)'));
  });

  test('Firebase Messaging service worker is a real configured JS asset', () {
    final worker = File('web/firebase-messaging-sw.js');
    expect(worker.existsSync(), isTrue);

    final source = worker.readAsStringSync();
    expect(source, contains('firebasejs/12.17.0/firebase-app-compat.js'));
    expect(source, contains('firebasejs/12.17.0/firebase-messaging-compat.js'));
    expect(source, contains("projectId: 'taxi-esil'"));
    expect(source, contains('const messaging = firebase.messaging()'));
  });

  test('Tulpar MapLibre style URL remains unchanged', () {
    final source = File(
      'lib/widgets/tulpar_map_tile_layer.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('https://maps.tulpartaxi.kz/styles/tulpar/style.json'),
    );
  });
}
