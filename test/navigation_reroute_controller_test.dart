import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/services/navigation_reroute_controller.dart';

void main() {
  const route = [LatLng(51.95, 66.4), LatLng(51.96, 66.4)];
  final start = DateTime.utc(2026, 8, 27, 10);

  group('distanceToPolylineMeters', () {
    test('handles on-line, nearby and far points', () {
      expect(
        distanceToPolylineMeters(const LatLng(51.955, 66.4), route),
        lessThan(1),
      );
      expect(
        distanceToPolylineMeters(const LatLng(51.955, 66.4001), route),
        inInclusiveRange(5, 10),
      );
      expect(
        distanceToPolylineMeters(const LatLng(51.955, 66.402), route),
        greaterThan(100),
      );
    });

    test('handles empty, single-point, short and invalid geometry safely', () {
      expect(distanceToPolylineMeters(route.first, const []), isNull);
      expect(
        distanceToPolylineMeters(route.first, [route.first]),
        closeTo(0, 0.01),
      );
      expect(
        distanceToPolylineMeters(route.first, [
          route.first,
          const LatLng(51.95000001, 66.4),
        ]),
        closeTo(0, 0.01),
      );
      expect(
        distanceToPolylineMeters(route.first, const [
          LatLng(double.nan, 66.4),
          LatLng(double.nan, 66.5),
        ]),
        isNull,
      );
    });
  });

  group('NavigationRerouteController', () {
    NavigationRerouteController controller() {
      final value = NavigationRerouteController();
      value.replaceRoute(route);
      return value;
    }

    test('poor accuracy and one far sample do not trigger reroute', () {
      final value = controller();
      final poor = value.updatePosition(
        position: const LatLng(51.955, 66.403),
        accuracyMeters: 100,
        timestamp: start,
      );
      expect(poor.ignoredForAccuracy, isTrue);
      expect(poor.shouldReroute, isFalse);

      final one = value.updatePosition(
        position: const LatLng(51.955, 66.403),
        accuracyMeters: 5,
        timestamp: start,
      );
      expect(one.confirmationSamples, 1);
      expect(one.shouldReroute, isFalse);
    });

    test('two consecutive far samples trigger reroute quickly', () {
      final value = controller();
      var shouldReroute = false;
      for (var index = 0; index < 2; index++) {
        final decision = value.updatePosition(
          position: LatLng(51.955, 66.403 + index * 0.0001),
          accuracyMeters: 5,
          timestamp: start.add(Duration(seconds: index)),
        );
        shouldReroute = decision.shouldReroute;
        if (index == 0) expect(decision.shouldReroute, isFalse);
      }
      expect(value.confirmationSamples, 2);
      expect(shouldReroute, isTrue);
    });

    test('first reroute is not blocked by route creation cooldown', () {
      final value = NavigationRerouteController();
      value.replaceRoute(route, timestamp: start);
      final first = value.updatePosition(
        position: const LatLng(51.955, 66.403),
        accuracyMeters: 5,
        timestamp: start,
      );
      final second = value.updatePosition(
        position: const LatLng(51.955, 66.4031),
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 1)),
      );

      expect(first.cooldownActive, isFalse);
      expect(second.cooldownActive, isFalse);
      expect(second.shouldReroute, isTrue);
    });

    test('empty route never triggers and reset removes an active route', () {
      final value = NavigationRerouteController();
      expect(
        value
            .updatePosition(
              position: const LatLng(51.955, 66.403),
              accuracyMeters: 5,
              timestamp: start,
            )
            .shouldReroute,
        isFalse,
      );
      value.replaceRoute(route);
      value.reset();
      expect(
        value
            .updatePosition(
              position: const LatLng(51.955, 66.403),
              accuracyMeters: 5,
              timestamp: start,
            )
            .distanceToRouteMeters,
        isNull,
      );
    });

    test('returning to route resets candidate samples', () {
      final value = controller();
      value.updatePosition(
        position: const LatLng(51.955, 66.403),
        accuracyMeters: 5,
        timestamp: start,
      );
      value.updatePosition(
        position: const LatLng(51.955, 66.4),
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 1)),
      );
      expect(value.confirmationSamples, 0);
    });

    test('accuracy allowance prevents a cross-road jitter trigger', () {
      final value = controller();
      final decision = value.updatePosition(
        position: const LatLng(51.955, 66.40075),
        accuracyMeters: 30,
        timestamp: start,
      );
      expect(decision.confirmationSamples, 0);
    });

    test('request in flight and cooldown prevent reroute storms', () {
      final value = controller();
      for (var index = 0; index < 2; index++) {
        value.updatePosition(
          position: const LatLng(51.955, 66.403),
          accuracyMeters: 5,
          timestamp: start.add(Duration(seconds: index)),
        );
      }
      value.markRequestStarted();
      expect(
        value
            .updatePosition(
              position: const LatLng(51.955, 66.403),
              accuracyMeters: 5,
              timestamp: start.add(const Duration(seconds: 3)),
            )
            .shouldReroute,
        isFalse,
      );
      value.markRequestFailed(timestamp: start.add(const Duration(seconds: 4)));
      final cooldown = value.updatePosition(
        position: const LatLng(51.955, 66.403),
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 5)),
      );
      expect(cooldown.cooldownActive, isTrue);

      for (var index = 0; index < 2; index++) {
        final after = value.updatePosition(
          position: const LatLng(51.955, 66.403),
          accuracyMeters: 5,
          timestamp: start.add(Duration(seconds: 20 + index)),
        );
        if (index == 1) expect(after.shouldReroute, isTrue);
      }
    });

    test('route replacement clears candidate and starts optional cooldown', () {
      final value = controller();
      value.updatePosition(
        position: const LatLng(51.955, 66.403),
        accuracyMeters: 5,
        timestamp: start,
      );
      value.replaceRoute(route, timestamp: start, startCooldown: true);
      expect(value.confirmationSamples, 0);
      expect(
        value
            .updatePosition(
              position: const LatLng(51.955, 66.403),
              accuracyMeters: 5,
              timestamp: start.add(const Duration(seconds: 1)),
            )
            .cooldownActive,
        isTrue,
      );
    });

    test(
      'successful replacement activates new route and resets confirmation',
      () {
        final value = controller();
        value.updatePosition(
          position: const LatLng(51.955, 66.403),
          accuracyMeters: 5,
          timestamp: start,
        );
        const newRoute = [LatLng(52, 67), LatLng(52.01, 67)];
        value.replaceRoute(newRoute);

        final onNewRoute = value.updatePosition(
          position: const LatLng(52.005, 67),
          accuracyMeters: 5,
          timestamp: start.add(const Duration(seconds: 1)),
        );
        expect(onNewRoute.distanceToRouteMeters, lessThan(1));
        expect(onNewRoute.confirmationSamples, 0);
        expect(onNewRoute.shouldReroute, isFalse);
      },
    );
  });
}
