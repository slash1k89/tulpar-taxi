import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/models/navigation_step.dart';
import 'package:taxi_esil/services/navigation_progress_controller.dart';

NavigationStep step(double lat, {String street = 'Step'}) => NavigationStep(
  type: 'turn',
  modifier: 'right',
  targetLat: lat,
  targetLng: 66.4,
  streetName: street,
  distanceMeters: 1000,
  durationSeconds: 100,
);

NavigationStep point(double lat, double lng, {required String street}) =>
    NavigationStep(
      type: 'turn',
      modifier: 'right',
      targetLat: lat,
      targetLng: lng,
      streetName: street,
      distanceMeters: 1000,
      durationSeconds: 100,
    );

void main() {
  test('leading depart is skipped and its route distance is accumulated', () {
    final controller = NavigationProgressController();
    final steps = [
      NavigationStep(
        type: 'depart',
        modifier: 'straight',
        targetLat: 51,
        targetLng: 71,
        streetName: '',
        distanceMeters: 800,
      ),
      NavigationStep(
        type: 'turn',
        modifier: 'right',
        targetLat: 51.007,
        targetLng: 71,
        streetName: '',
      ),
    ];
    controller.replaceRoute(steps: steps, routeGeneration: 1);
    final state = controller.updatePosition(
      position: const LatLng(51, 71),
      accuracyMeters: 5,
    );

    expect(state.currentStepIndex, 1);
    expect(state.currentStep?.modifier, 'right');
    expect(state.distanceToManeuverMeters, closeTo(779, 2));
  });

  final start = DateTime.utc(2026, 8, 27, 10);

  test('empty route has no current step', () {
    final controller = NavigationProgressController();
    controller.replaceRoute(steps: const [], routeGeneration: 1);
    expect(controller.state.currentStep, isNull);
    expect(controller.state.distanceToManeuverMeters, isNull);
  });

  test(
    'initial step and normal approach update distance without advancing',
    () {
      final controller = NavigationProgressController();
      controller.replaceRoute(
        steps: [step(51.95), step(51.96)],
        routeGeneration: 1,
      );

      final state = controller.updatePosition(
        position: const LatLng(51.949, 66.4),
        accuracyMeters: 5,
        timestamp: start,
      );

      expect(state.currentStepIndex, 0);
      expect(state.currentStep?.streetName, 'Step');
      expect(state.distanceToManeuverMeters, greaterThan(100));
    },
  );

  test('one close jitter sample does not advance', () {
    final controller = NavigationProgressController();
    controller.replaceRoute(
      steps: [step(51.95), step(51.96)],
      routeGeneration: 1,
    );

    final state = controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      accuracyMeters: 5,
      timestamp: start,
    );
    expect(state.currentStepIndex, 0);
    expect(state.didAdvance, isFalse);
  });

  test('two accurate close samples advance exactly one step', () {
    final controller = NavigationProgressController();
    controller.replaceRoute(
      steps: [step(51.95), step(51.95), step(51.96)],
      routeGeneration: 1,
    );

    controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      accuracyMeters: 5,
      timestamp: start,
    );
    final state = controller.updatePosition(
      position: const LatLng(51.95001, 66.4),
      accuracyMeters: 5,
      timestamp: start.add(const Duration(milliseconds: 500)),
    );

    expect(state.currentStepIndex, 1);
    expect(state.didAdvance, isTrue);
  });

  test('poor GPS accuracy cannot confirm advancement', () {
    final controller = NavigationProgressController();
    controller.replaceRoute(
      steps: [step(51.95), step(51.96)],
      routeGeneration: 1,
    );

    for (var i = 0; i < 3; i++) {
      controller.updatePosition(
        position: const LatLng(51.95, 66.4),
        accuracyMeters: 100,
        timestamp: start.add(Duration(seconds: i)),
      );
    }
    expect(controller.state.currentStepIndex, 0);
  });

  test('cooldown prevents a second advancement immediately', () {
    final controller = NavigationProgressController();
    controller.replaceRoute(
      steps: [step(51.95), step(51.95), step(51.96)],
      routeGeneration: 1,
    );

    controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      accuracyMeters: 5,
      timestamp: start,
    );
    controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      accuracyMeters: 5,
      timestamp: start.add(const Duration(milliseconds: 100)),
    );
    controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      accuracyMeters: 5,
      timestamp: start.add(const Duration(milliseconds: 200)),
    );
    controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      accuracyMeters: 5,
      timestamp: start.add(const Duration(milliseconds: 300)),
    );

    expect(controller.state.currentStepIndex, 1);
  });

  test('final step remains visible after confirmations', () {
    final controller = NavigationProgressController();
    controller.replaceRoute(steps: [step(51.95)], routeGeneration: 1);
    controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      accuracyMeters: 5,
      timestamp: start,
    );
    final state = controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      accuracyMeters: 5,
      timestamp: start.add(const Duration(seconds: 1)),
    );

    expect(state.currentStepIndex, 0);
    expect(state.currentStep, isNotNull);
    expect(state.didAdvance, isFalse);
  });

  test('new route generation resets progress to its first step', () {
    final controller = NavigationProgressController();
    controller.replaceRoute(
      steps: [
        step(51.95),
        step(51.96, street: 'Old second'),
      ],
      routeGeneration: 1,
    );
    controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      timestamp: start,
    );
    controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      timestamp: start.add(const Duration(seconds: 1)),
    );
    expect(controller.state.currentStepIndex, 1);

    controller.replaceRoute(
      steps: [step(52, street: 'New first')],
      routeGeneration: 2,
    );
    expect(controller.state.currentStepIndex, 0);
    expect(controller.state.currentStep?.streetName, 'New first');
    expect(controller.state.distanceToManeuverMeters, isNull);
  });

  test(
    'remaining distance and ETA combine partial current and future steps',
    () {
      final controller = NavigationProgressController();
      controller.replaceRoute(
        steps: [step(51.95), step(51.96)],
        routeGeneration: 1,
      );
      final state = controller.updatePosition(
        position: const LatLng(51.9455, 66.4),
        accuracyMeters: 5,
        timestamp: start,
      );

      expect(state.remainingDistanceMeters, inInclusiveRange(1490, 1510));
      expect(state.remainingDurationSeconds, inInclusiveRange(149, 151));
    },
  );

  test('remaining metrics never expose invalid values', () {
    final controller = NavigationProgressController();
    controller.replaceRoute(
      steps: [
        NavigationStep(
          modifier: 'straight',
          type: 'turn',
          targetLat: 51.95,
          targetLng: 66.4,
          streetName: '',
          distanceMeters: double.nan,
          durationSeconds: double.infinity,
        ),
      ],
      routeGeneration: 1,
    );
    final state = controller.updatePosition(
      position: const LatLng(51.949, 66.4),
      timestamp: start,
    );
    expect(state.remainingDistanceMeters, isNonNegative);
    expect(state.remainingDistanceMeters!.isFinite, isTrue);
    expect(state.remainingDurationSeconds, 0);
  });

  test('maneuver without a usable coordinate cannot advance', () {
    final controller = NavigationProgressController();
    controller.replaceRoute(
      steps: [step(double.nan), step(51.96)],
      routeGeneration: 1,
    );
    final state = controller.updatePosition(
      position: const LatLng(51.95, 66.4),
      accuracyMeters: 5,
      timestamp: start,
    );

    expect(state.currentStepIndex, 0);
    expect(state.distanceToManeuverMeters, isNull);
  });

  group('passed maneuver progression', () {
    List<NavigationStep> eastboundSteps() => [
      point(51.95, 66.4, street: 'First'),
      point(51.95, 66.41, street: 'Second'),
      point(51.95, 66.42, street: 'Third'),
    ];

    test('200m 100m 50m approach does not advance early', () {
      final controller = NavigationProgressController();
      controller.replaceRoute(steps: eastboundSteps(), routeGeneration: 1);

      for (final latitude in [51.9482, 51.9491, 51.94955]) {
        final state = controller.updatePosition(
          position: LatLng(latitude, 66.4),
          accuracyMeters: 5,
          timestamp: start,
        );
        expect(state.currentStepIndex, 0);
      }
    });

    test('sample after maneuver advances and reports next distance', () {
      final controller = NavigationProgressController();
      controller.replaceRoute(steps: eastboundSteps(), routeGeneration: 1);
      controller.updatePosition(
        position: const LatLng(51.94955, 66.4),
        accuracyMeters: 5,
        timestamp: start,
      );

      final state = controller.updatePosition(
        position: const LatLng(51.95, 66.4007),
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 1)),
      );

      expect(state.currentStepIndex, 1);
      expect(state.currentStep?.streetName, 'Second');
      expect(state.distanceToManeuverMeters, greaterThan(600));
    });

    test('distance follows the active maneuver and decreases on approach', () {
      final controller = NavigationProgressController();
      controller.replaceRoute(steps: eastboundSteps(), routeGeneration: 1);

      final distances = <double>[];
      for (final latitude in [51.947, 51.948, 51.949]) {
        distances.add(
          controller
              .updatePosition(
                position: LatLng(latitude, 66.4),
                accuracyMeters: 5,
                timestamp: start,
              )
              .distanceToManeuverMeters!,
        );
      }

      expect(distances[1], lessThan(distances[0]));
      expect(distances[2], lessThan(distances[1]));
    });

    test('GPS jump from before to after maneuver still advances', () {
      final controller = NavigationProgressController();
      controller.replaceRoute(steps: eastboundSteps(), routeGeneration: 1);
      controller.updatePosition(
        position: const LatLng(51.9491, 66.4),
        accuracyMeters: 5,
        timestamp: start,
      );
      controller.updatePosition(
        position: const LatLng(51.94955, 66.4),
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 1)),
      );

      final state = controller.updatePosition(
        position: const LatLng(51.95, 66.4008),
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 2)),
      );
      expect(state.currentStepIndex, 1);
    });

    test('one lateral bad sample does not falsely advance', () {
      final controller = NavigationProgressController();
      controller.replaceRoute(steps: eastboundSteps(), routeGeneration: 1);
      controller.updatePosition(
        position: const LatLng(51.94955, 66.4),
        accuracyMeters: 5,
        timestamp: start,
      );

      final bad = controller.updatePosition(
        position: const LatLng(51.951, 66.4008),
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 1)),
      );
      expect(bad.currentStepIndex, 0);
    });

    test('poor accuracy cannot advance across maneuver', () {
      final controller = NavigationProgressController();
      controller.replaceRoute(steps: eastboundSteps(), routeGeneration: 1);
      controller.updatePosition(
        position: const LatLng(51.94955, 66.4),
        accuracyMeters: 5,
        timestamp: start,
      );
      final state = controller.updatePosition(
        position: const LatLng(51.95, 66.4008),
        accuracyMeters: 80,
        timestamp: start.add(const Duration(seconds: 1)),
      );
      expect(state.currentStepIndex, 0);
    });

    test('one update advances at most one step', () {
      final controller = NavigationProgressController();
      controller.replaceRoute(
        steps: [
          point(51.95, 66.4, street: 'First'),
          point(51.95, 66.4005, street: 'Second'),
          point(51.95, 66.401, street: 'Third'),
        ],
        routeGeneration: 1,
      );
      controller.updatePosition(
        position: const LatLng(51.94955, 66.4),
        accuracyMeters: 5,
        timestamp: start,
      );
      final state = controller.updatePosition(
        position: const LatLng(51.95, 66.4012),
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 1)),
      );
      expect(state.currentStepIndex, 1);
    });

    test('route replacement clears passed-maneuver evidence', () {
      final controller = NavigationProgressController();
      controller.replaceRoute(steps: eastboundSteps(), routeGeneration: 1);
      controller.updatePosition(
        position: const LatLng(51.94955, 66.4),
        accuracyMeters: 5,
        timestamp: start,
      );

      controller.replaceRoute(
        steps: [
          point(52, 67, street: 'New first'),
          point(52, 67.01, street: 'New second'),
        ],
        routeGeneration: 2,
      );
      final state = controller.updatePosition(
        position: const LatLng(51.95, 66.4008),
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 1)),
      );
      expect(state.currentStepIndex, 0);
      expect(state.currentStep?.streetName, 'New first');
    });
  });
}
