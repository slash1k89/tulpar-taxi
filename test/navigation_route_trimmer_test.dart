import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/services/navigation_route_trimmer.dart';

void main() {
  const straightRoute = [
    LatLng(51.95, 66.4),
    LatLng(51.95, 66.41),
    LatLng(51.95, 66.42),
  ];

  test('movement removes the completed part of the polyline', () {
    final trimmer = NavigationRouteTrimmer()..replaceRoute(straightRoute);
    expect(
      trimmer.updatePosition(
        position: const LatLng(51.95, 66.4005),
        accuracyMeters: 5,
      ),
      isTrue,
    );

    expect(trimmer.visibleRoute.first.longitude, closeTo(66.4005, 0.00001));
    expect(trimmer.visibleRoute.last, straightRoute.last);
  });

  test('visible line starts at projection between route vertices', () {
    final trimmer = NavigationRouteTrimmer()..replaceRoute(straightRoute);
    trimmer.updatePosition(
      position: const LatLng(51.95005, 66.4007),
      accuracyMeters: 5,
    );

    expect(trimmer.visibleRoute.first.latitude, closeTo(51.95, 0.000001));
    expect(trimmer.visibleRoute.first.longitude, closeTo(66.4007, 0.00001));
  });

  test('small GPS jump backwards cannot restore removed geometry', () {
    final trimmer = NavigationRouteTrimmer()..replaceRoute(straightRoute);
    trimmer.updatePosition(
      position: const LatLng(51.95, 66.401),
      accuracyMeters: 5,
    );
    final progress = trimmer.confirmedProgressMeters;
    final firstPoint = trimmer.visibleRoute.first;

    final changed = trimmer.updatePosition(
      position: const LatLng(51.95, 66.4007),
      accuracyMeters: 5,
    );

    expect(changed, isFalse);
    expect(trimmer.confirmedProgressMeters, progress);
    expect(trimmer.visibleRoute.first, firstPoint);
  });

  test('poor GPS sample cannot trim route forward', () {
    final trimmer = NavigationRouteTrimmer()..replaceRoute(straightRoute);
    final changed = trimmer.updatePosition(
      position: const LatLng(51.95, 66.41),
      accuracyMeters: 100,
    );

    expect(changed, isFalse);
    expect(trimmer.confirmedProgressMeters, 0);
    expect(trimmer.visibleRoute, straightRoute);
  });

  test('nearby later route section cannot cause a large forward jump', () {
    final route = <LatLng>[
      const LatLng(51.95, 66.4),
      const LatLng(51.95, 66.401),
      const LatLng(51.951, 66.401),
      const LatLng(51.951, 66.4),
      const LatLng(51.95001, 66.4),
      const LatLng(51.95001, 66.399),
    ];
    final trimmer = NavigationRouteTrimmer(maximumForwardJumpMeters: 120)
      ..replaceRoute(route);
    trimmer.updatePosition(
      position: const LatLng(51.95, 66.4002),
      accuracyMeters: 5,
    );

    expect(trimmer.confirmedProgressMeters, lessThan(30));
    expect(trimmer.visibleRoute[1], route[1]);
  });

  test('route replacement and reset clear trimming progress', () {
    final trimmer = NavigationRouteTrimmer()..replaceRoute(straightRoute);
    trimmer.updatePosition(
      position: const LatLng(51.95, 66.4008),
      accuracyMeters: 5,
    );
    const reroute = [LatLng(52, 67), LatLng(52.01, 67.01)];

    trimmer.replaceRoute(reroute);
    expect(trimmer.confirmedProgressMeters, 0);
    expect(trimmer.visibleRoute, reroute);

    trimmer.reset();
    expect(trimmer.visibleRoute, isEmpty);
  });
}
