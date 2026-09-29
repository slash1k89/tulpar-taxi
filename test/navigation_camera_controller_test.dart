import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/services/navigation_camera_controller.dart';

void main() {
  test('invalid heading falls back to nearby forward route while moving', () {
    final controller = NavigationCameraController(headingSmoothing: 1);
    final update = controller.update(
      position: const LatLng(51.95, 66.4),
      reportedHeadingDegrees: double.nan,
      speedMetersPerSecond: 5,
      routeAhead: const [LatLng(51.95, 66.4), LatLng(51.95, 66.401)],
    );
    expect(update.headingDegrees, closeTo(90, 1));
  });

  test('nearby route orients immediately; distant route is rejected', () {
    for (final speed in [0.0, 5.0]) {
      final controller = NavigationCameraController();
      final update = controller.update(
        position: const LatLng(51.95, 66.4),
        speedMetersPerSecond: speed,
        routeAhead: speed == 0
            ? const [LatLng(51.95, 66.4), LatLng(51.95, 66.401)]
            : const [LatLng(52, 67), LatLng(52, 67.001)],
      );
      expect(update.didUpdateHeading, speed == 0);
    }
  });

  for (final degrees in [0.0, 90.0, 270.0, 40.0]) {
    test('route bearing follows $degrees degrees instead of sensor', () {
      const start = LatLng(51, 71);
      final end = const Distance().offset(start, 60, degrees);
      final controller = NavigationCameraController(headingSmoothing: 1);
      controller.update(
        position: start,
        routeAhead: [start, const Distance().offset(start, 60, 0)],
      );
      final update = controller.update(
        position: start,
        routeAhead: [start, end],
        reportedHeadingDegrees: 180,
        speedMetersPerSecond: 5,
      );
      expect(update.headingDegrees, closeTo(degrees, 0.2));
    });
  }

  test(
    'short look-ahead ignores a distant turn; GPS jitter cannot rotate route',
    () {
      const start = LatLng(51, 71);
      final north = const Distance().offset(start, 30, 0);
      final east = const Distance().offset(north, 100, 90);
      final controller = NavigationCameraController(headingSmoothing: 1);
      for (final heading in [0.0, 180.0, 270.0]) {
        final update = controller.update(
          position: const Distance().offset(start, 1, heading),
          reportedHeadingDegrees: heading,
          speedMetersPerSecond: 5,
          routeAhead: [start, north, east],
        );
        expect(update.headingDegrees, closeTo(0, 0.2));
      }
    },
  );

  test('manual gesture invalidates delayed update even after resume', () {
    final controller = NavigationCameraController();
    final old = controller.beginCameraUpdate();
    expect(controller.canApply(old), isTrue);
    controller.suspendFollow();
    expect(controller.canApply(old), isFalse);
    controller.resumeFollow();
    expect(controller.canApply(old), isFalse);
    final current = controller.beginCameraUpdate();
    expect(controller.canApply(current), isTrue);
    controller.reset();
    expect(controller.canApply(current), isFalse);
  });

  test('manual gesture disables follow and GPS action restores it', () {
    final controller = NavigationCameraController();
    expect(controller.following, isTrue);
    controller.suspendFollow();
    expect(controller.following, isFalse);
    controller.resumeFollow();
    expect(controller.following, isTrue);
  });

  test('GPS, route/status rebuild and reroute keep follow enabled', () {
    final controller = NavigationCameraController();
    controller.update(position: const LatLng(51.95, 66.4));
    controller.restoreAfterNavigationChange();
    expect(controller.following, isTrue);
    controller.restoreAfterNavigationChange();
    expect(controller.following, isTrue);
  });

  test('locale/rebuild preserves an explicit user gesture suspension', () {
    final controller = NavigationCameraController();
    controller.suspendFollow();
    controller.restoreAfterNavigationChange();
    expect(controller.following, isFalse);
    expect(controller.userSuspended, isTrue);
    controller.resumeFollow();
    expect(controller.following, isTrue);
    expect(controller.userSuspended, isFalse);
  });

  test('camera update exposes route and target bearings for application', () {
    const start = LatLng(51, 71);
    final end = const Distance().offset(start, 60, 40);
    final controller = NavigationCameraController(headingSmoothing: 1);
    final update = controller.update(
      position: start,
      routeAhead: [start, end],
      reportedHeadingDegrees: 180,
      speedMetersPerSecond: 5,
    );

    expect(update.routeBearingDegrees, closeTo(40, 0.2));
    expect(update.targetHeadingDegrees, closeTo(40, 0.2));
    expect(update.headingDegrees, closeTo(40, 0.2));
  });

  test('short GPS steps accumulate enough displacement for fallback', () {
    final controller = NavigationCameraController(headingSmoothing: 1);
    controller.update(position: const LatLng(51.95, 66.4));
    controller.update(position: const LatLng(51.95003, 66.4));
    controller.update(position: const LatLng(51.95006, 66.4));
    final update = controller.update(position: const LatLng(51.95009, 66.4));
    expect(update.didUpdateHeading, isTrue);
    expect(update.headingDegrees, closeTo(0, 1));
  });

  test('straight movement calculates a northbound heading', () {
    final controller = NavigationCameraController(headingSmoothing: 1);
    controller.update(position: const LatLng(51.95, 66.4));
    final update = controller.update(position: const LatLng(51.9502, 66.4));

    expect(update.didUpdateHeading, isTrue);
    expect(update.headingDegrees, closeTo(0, 0.5));
  });

  test('turn changes heading toward the new movement direction', () {
    final controller = NavigationCameraController(headingSmoothing: 1);
    controller.update(position: const LatLng(51.95, 66.4));
    controller.update(position: const LatLng(51.9502, 66.4));
    final turn = controller.update(position: const LatLng(51.9502, 66.4003));

    expect(turn.headingDegrees, closeTo(90, 1));
  });

  test('stale reported heading does not prevent a real turn', () {
    final controller = NavigationCameraController(headingSmoothing: 1);
    controller.update(
      position: const LatLng(51.95, 66.4),
      reportedHeadingDegrees: 0,
      speedMetersPerSecond: 5,
    );
    final turn = controller.update(
      position: const LatLng(51.95, 66.4003),
      reportedHeadingDegrees: 0,
      speedMetersPerSecond: 5,
    );

    expect(turn.didUpdateHeading, isTrue);
    expect(turn.headingDegrees, closeTo(90, 1));
  });

  test('359 to 1 degrees uses the shortest angular direction', () {
    final controller = NavigationCameraController(headingSmoothing: 0.5);
    controller.update(
      position: const LatLng(51.95, 66.4),
      reportedHeadingDegrees: 359,
      speedMetersPerSecond: 5,
    );
    final update = controller.update(
      position: const LatLng(51.9501, 66.4),
      reportedHeadingDegrees: 1,
      speedMetersPerSecond: 5,
    );

    expect(NavigationCameraController.shortestAngularDifference(359, 1), 2);
    expect(update.headingDegrees, closeTo(0, 0.01));
  });

  test('stationary samples do not rotate the camera', () {
    final controller = NavigationCameraController();
    controller.update(position: const LatLng(51.95, 66.4));
    final update = controller.update(
      position: const LatLng(51.950001, 66.4),
      reportedHeadingDegrees: 180,
      speedMetersPerSecond: 0,
    );

    expect(update.didUpdateHeading, isFalse);
    expect(update.headingDegrees, isNull);
  });

  test('poor GPS sample is rejected without changing heading', () {
    final controller = NavigationCameraController(headingSmoothing: 1);
    controller.update(
      position: const LatLng(51.95, 66.4),
      reportedHeadingDegrees: 20,
      speedMetersPerSecond: 5,
    );
    final update = controller.update(
      position: const LatLng(52, 67),
      accuracyMeters: 100,
      reportedHeadingDegrees: 200,
      speedMetersPerSecond: 20,
    );

    expect(update.accepted, isFalse);
    expect(update.headingDegrees, 20);
  });

  test('reset clears position and heading state', () {
    final controller = NavigationCameraController();
    controller.update(
      position: const LatLng(51.95, 66.4),
      reportedHeadingDegrees: 90,
      speedMetersPerSecond: 5,
    );
    controller.reset();
    final update = controller.update(position: const LatLng(52, 67));

    expect(controller.headingDegrees, isNull);
    expect(update.didUpdateHeading, isFalse);
  });

  test(
    'a real route turn overrides a stale sensor and recenter snaps exactly',
    () {
      const corner = LatLng(51.95, 66.4);
      final west = const Distance().offset(corner, 35, 270);
      final east = const Distance().offset(corner, 35, 90);
      final north = const Distance().offset(corner, 35, 0);
      final controller = NavigationCameraController();
      controller.update(position: west, routeAhead: [west, corner]);
      final turn = controller.update(
        position: corner,
        routeAhead: [west, corner, north],
        reportedHeadingDegrees: 45,
        speedMetersPerSecond: 4,
      );
      expect(turn.routeBearingDegrees, closeTo(0, 1));
      final recentered = controller.update(
        position: corner,
        routeAhead: [corner, east],
        reportedHeadingDegrees: 45,
        speedMetersPerSecond: 4,
        snapToRoute: true,
      );
      expect(recentered.routeBearingDegrees, closeTo(90, 1));
      expect(recentered.headingDegrees, closeTo(90, 1));
    },
  );

  test(
    'reroute immediately changes the route bearing at the same GPS point',
    () {
      const position = LatLng(51.95, 66.4);
      final controller = NavigationCameraController(headingSmoothing: 1);
      controller.update(
        position: position,
        routeAhead: [position, const Distance().offset(position, 50, 0)],
      );
      controller.restoreAfterNavigationChange();
      final rerouted = controller.update(
        position: position,
        routeAhead: [position, const Distance().offset(position, 50, 90)],
      );
      expect(rerouted.routeBearingDegrees, closeTo(90, 1));
      expect(rerouted.headingDegrees, closeTo(90, 1));
    },
  );

  testWidgets('gesture follow resumes after 3.5 seconds of inactivity', (
    tester,
  ) async {
    final camera = NavigationCameraController();
    var active = true;
    final timer = NavigationFollowResumeTimer(
      canResume: () => active,
      onResume: camera.resumeFollow,
    );
    camera.suspendFollow();
    timer.schedule();
    await tester.pump(const Duration(seconds: 3));
    expect(camera.following, isFalse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(camera.following, isTrue);
    camera.suspendFollow();
    timer.schedule();
    await tester.pump(const Duration(seconds: 3));
    timer.schedule(); // a second gesture resets the clock
    await tester.pump(const Duration(seconds: 1));
    expect(camera.following, isFalse);
    active = false; // navigation ended or map closed
    await tester.pump(const Duration(seconds: 3));
    expect(camera.following, isFalse);
    timer.dispose();
  });
}
