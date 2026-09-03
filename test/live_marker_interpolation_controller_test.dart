import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/services/live_marker_interpolation_controller.dart';

void main() {
  final start = DateTime.utc(2026, 8, 30, 10);

  test('first sample is shown immediately', () {
    final controller = LiveMarkerInterpolationController();
    final result = controller.addSample(
      position: const LatLng(51.95, 66.4),
      timestamp: start,
    );
    expect(result.snapped, isTrue);
    expect(controller.positionAt(start), const LatLng(51.95, 66.4));
  });

  test('ordinary movement has an intermediate visual position', () {
    final controller = LiveMarkerInterpolationController();
    controller.addSample(position: const LatLng(51.95, 66.4), timestamp: start);
    final result = controller.addSample(
      position: const LatLng(51.95, 66.401),
      timestamp: start.add(const Duration(seconds: 2)),
    );
    final middle = controller.positionAt(
      start.add(const Duration(seconds: 2)).add(result.duration ~/ 2),
    )!;
    expect(middle.longitude, inExclusiveRange(66.4, 66.401));
  });

  test('animation reaches the authoritative target', () {
    final controller = LiveMarkerInterpolationController();
    controller.addSample(position: const LatLng(51.95, 66.4), timestamp: start);
    final timestamp = start.add(const Duration(seconds: 2));
    final result = controller.addSample(
      position: const LatLng(51.95, 66.401),
      timestamp: timestamp,
    );
    expect(
      controller.positionAt(timestamp.add(result.duration)),
      const LatLng(51.95, 66.401),
    );
  });

  test('new target continues from current visual position', () {
    final controller = LiveMarkerInterpolationController();
    controller.addSample(position: const LatLng(51.95, 66.4), timestamp: start);
    final bTime = start.add(const Duration(seconds: 2));
    final firstAnimation = controller.addSample(
      position: const LatLng(51.95, 66.402),
      timestamp: bTime,
    );
    final cTime = bTime.add(firstAnimation.duration ~/ 2);
    final beforeRetarget = controller.positionAt(cTime)!;
    controller.addSample(
      position: const LatLng(51.95, 66.403),
      timestamp: cTime,
    );

    expect(controller.positionAt(cTime), beforeRetarget);
  });

  test('ordinary samples animate instead of teleporting', () {
    final controller = LiveMarkerInterpolationController();
    controller.addSample(position: const LatLng(51.95, 66.4), timestamp: start);
    final result = controller.addSample(
      position: const LatLng(51.9502, 66.4002),
      timestamp: start.add(const Duration(seconds: 2)),
    );
    expect(result.snapped, isFalse);
    expect(result.duration, greaterThan(Duration.zero));
  });

  test('large jump snaps instead of animating across the city', () {
    final controller = LiveMarkerInterpolationController();
    controller.addSample(position: const LatLng(51.95, 66.4), timestamp: start);
    final result = controller.addSample(
      position: const LatLng(52.05, 66.5),
      timestamp: start.add(const Duration(seconds: 2)),
    );
    expect(result.snapped, isTrue);
    expect(
      controller.positionAt(start.add(const Duration(seconds: 2))),
      const LatLng(52.05, 66.5),
    );
  });

  test('poor accuracy is ignored', () {
    final controller = LiveMarkerInterpolationController();
    controller.addSample(position: const LatLng(51.95, 66.4), timestamp: start);
    final result = controller.addSample(
      position: const LatLng(51.96, 66.41),
      timestamp: start.add(const Duration(seconds: 1)),
      accuracyMeters: 100,
    );
    expect(result.accepted, isFalse);
    expect(
      controller.positionAt(start.add(const Duration(seconds: 1))),
      const LatLng(51.95, 66.4),
    );
  });

  test('reset and dispose clear and stop presentation state', () {
    final controller = LiveMarkerInterpolationController();
    controller.addSample(position: const LatLng(51.95, 66.4), timestamp: start);
    controller.reset();
    expect(controller.positionAt(start), isNull);

    controller.dispose();
    final result = controller.addSample(
      position: const LatLng(52, 67),
      timestamp: start,
    );
    expect(result.accepted, isFalse);
    expect(controller.positionAt(start), isNull);
  });
}
