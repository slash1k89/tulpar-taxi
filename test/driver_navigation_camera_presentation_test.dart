import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/screens/driver/driver_map_screen.dart';

void main() {
  testWidgets('fixed vehicle stays at the same screen point when GPS changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const markerKey = Key('test-vehicle');

    Widget app(LatLng gps) => MaterialApp(
      home: SizedBox(
        width: 400,
        height: 800,
        child: Stack(
          children: [
            FixedNavigationVehicleMarker(
              gpsPosition: gps,
              marker: const ColoredBox(key: markerKey, color: Colors.blue),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(app(const LatLng(51.95, 66.4)));
    final first = tester.getCenter(find.byKey(markerKey));
    await tester.pumpWidget(app(const LatLng(51.951, 66.402)));
    final second = tester.getCenter(find.byKey(markerKey));

    expect(second, first);
    expect(second.dx, closeTo(200, 0.1));
    expect(second.dy, closeTo(800 * navigationVehicleVerticalFraction, 0.1));
  });

  test('camera offset and fixed marker share the same vertical anchor', () {
    const size = Size(400, 800);
    final offset = navigationCameraOffset(size);
    expect(0.5 + offset.dy / size.height, navigationVehicleVerticalFraction);
    expect(navigationVehicleVerticalFraction, inInclusiveRange(0.60, 0.65));
  });

  test('fixed marker is limited to active navigation follow mode', () {
    expect(
      navigationUsesFixedVehicleMarker(
        following: true,
        hasActiveNavigation: true,
      ),
      isTrue,
    );
    for (final state in const [
      (following: false, active: true),
      (following: true, active: false),
      (following: false, active: false),
    ]) {
      expect(
        navigationUsesFixedVehicleMarker(
          following: state.following,
          hasActiveNavigation: state.active,
        ),
        isFalse,
      );
    }
  });

  test('programmatic camera sources never disable follow', () {
    for (final source in const [
      MapEventSource.mapController,
      MapEventSource.fitCamera,
      MapEventSource.nonRotatedSizeChange,
      MapEventSource.custom,
    ]) {
      expect(navigationMapEventDisablesFollow(source), isFalse);
    }
  });

  test('drag, pinch and rotation gesture sources disable follow', () {
    for (final source in const [
      MapEventSource.dragStart,
      MapEventSource.onDrag,
      MapEventSource.onMultiFinger,
      MapEventSource.cursorKeyboardRotation,
    ]) {
      expect(navigationMapEventDisablesFollow(source), isTrue);
    }
  });

  test('resume restores camera only for active follow navigation', () {
    expect(
      navigationShouldRestoreCameraOnResume(
        following: true,
        hasActiveNavigation: true,
      ),
      isTrue,
    );
    expect(
      navigationShouldRestoreCameraOnResume(
        following: false,
        hasActiveNavigation: true,
      ),
      isFalse,
    );
    expect(
      navigationShouldRestoreCameraOnResume(
        following: true,
        hasActiveNavigation: false,
      ),
      isFalse,
    );
  });
}
