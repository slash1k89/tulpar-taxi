import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/services/driver_tracking_service.dart';
import 'package:taxi_esil/utils/single_key_future_cache.dart';
import 'package:taxi_esil/widgets/driver_location_marker_layer.dart';

void main() {
  test(
    'latest-value writer throttles updates and never writes in parallel',
    () async {
      final writes = <int>[];
      var concurrentWrites = 0;
      var maximumConcurrentWrites = 0;
      final firstWriteGate = Completer<void>();

      final writer = LatestValueWriteThrottler<int>(
        minimumInterval: const Duration(milliseconds: 20),
        write: (value) async {
          concurrentWrites++;
          maximumConcurrentWrites = concurrentWrites > maximumConcurrentWrites
              ? concurrentWrites
              : maximumConcurrentWrites;
          writes.add(value);
          if (value == 1) await firstWriteGate.future;
          concurrentWrites--;
        },
      );

      writer.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(writes, [1]);

      writer.add(2);
      writer.add(3);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(writes, [1]);

      firstWriteGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(writes, [1, 3]);
      expect(maximumConcurrentWrites, 1);
      await writer.close();
    },
  );

  test('latest-value writer enforces the minimum interval', () async {
    final writes = <int>[];
    final writer = LatestValueWriteThrottler<int>(
      minimumInterval: const Duration(milliseconds: 40),
      write: (value) async => writes.add(value),
    );

    writer.add(1);
    await Future<void>.delayed(Duration.zero);
    writer.add(2);

    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(writes, [1]);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(writes, [1, 2]);

    await writer.close();
  });

  test('single-key future cache reuses a load until the key changes', () async {
    final cache = SingleKeyFutureCache<String, int>();
    var loadCount = 0;

    Future<int> load() async => ++loadCount;

    final first = cache.get('driver-a', load);
    final repeated = cache.get('driver-a', load);
    final changed = cache.get('driver-b', load);

    expect(identical(first, repeated), isTrue);
    expect(await first, 1);
    expect(await changed, 2);
    expect(loadCount, 2);
  });

  testWidgets('moving marker updates without rebuilding the map parent', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(null);
    var mapParentBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              mapParentBuilds++;
              return FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(51.957, 66.404),
                  initialZoom: 13,
                ),
                children: [
                  DriverLocationMarkerLayer(
                    positionListenable: position,
                    marker: const Icon(Icons.local_taxi),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(mapParentBuilds, 1);
    expect(find.byIcon(Icons.local_taxi), findsNothing);

    position.value = const LatLng(51.96, 66.41);
    await tester.pump();

    expect(mapParentBuilds, 1);
    expect(find.byIcon(Icons.local_taxi), findsOneWidget);
    position.dispose();
  });
}
