import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/models/navigation_step.dart';
import 'package:taxi_esil/widgets/navigation_overlay.dart';

NavigationStep step({
  String type = 'turn',
  String modifier = 'right',
  String street = 'ул. Абая',
  double lat = 51.95,
  int? exitNumber,
  double distanceMeters = 0,
  double durationSeconds = 0,
}) => NavigationStep(
  type: type,
  modifier: modifier,
  targetLat: lat,
  targetLng: 66.4,
  streetName: street,
  exitNumber: exitNumber,
  distanceMeters: distanceMeters,
  durationSeconds: durationSeconds,
);

Widget app({
  required ThemeData theme,
  required List<NavigationStep> steps,
  required ValueNotifier<LatLng?> position,
  int routeGeneration = 1,
  double? distanceMeters,
  double? durationSeconds,
  double accuracy = 5,
  bool isRerouting = false,
  String? rerouteErrorMessage,
  LatLng? routeTarget,
}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Stack(
      children: [
        NavigationOverlay(
          key: const Key('navigation_overlay'),
          steps: steps,
          routeGeneration: routeGeneration,
          routeDistanceMeters: distanceMeters,
          routeDurationSeconds: durationSeconds,
          positionListenable: position,
          positionAccuracyProvider: () => accuracy,
          isRerouting: isRerouting,
          rerouteErrorMessage: rerouteErrorMessage,
          routeTarget: routeTarget,
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('uses light and dark ColorScheme', (tester) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.947, 66.4));
    final lightScheme = ColorScheme.fromSeed(seedColor: Colors.amber);
    await tester.pumpWidget(
      app(
        theme: ThemeData(colorScheme: lightScheme),
        steps: [step()],
        position: position,
      ),
    );
    expect(tester.widget<Card>(find.byType(Card)).color, lightScheme.surface);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('navigation_instruction')))
          .style
          ?.color,
      lightScheme.onSurface,
    );
    await tester.pumpWidget(const SizedBox.shrink());

    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.amber,
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      app(
        theme: ThemeData(brightness: Brightness.dark, colorScheme: darkScheme),
        steps: [step()],
        position: position,
      ),
    );
    expect(tester.widget<Card>(find.byType(Card)).color, darkScheme.surface);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('navigation_instruction')))
          .style
          ?.color,
      darkScheme.onSurface,
    );
    position.dispose();
  });

  testWidgets('shows distance, instruction, street and static route summary', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.947, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step()],
        position: position,
        distanceMeters: 6200,
        durationSeconds: 540,
      ),
    );

    expect(find.text('Через 350 м'), findsOneWidget);
    expect(find.text('Поверните направо'), findsOneWidget);
    expect(find.text('ул. Абая'), findsOneWidget);
    expect(find.text('6,2 км • 9 мин'), findsOneWidget);
    position.dispose();
  });

  testWidgets('immediate maneuver has no zero-distance prefix', (tester) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.95, 66.4));
    await tester.pumpWidget(
      app(theme: ThemeData.light(), steps: [step()], position: position),
    );

    expect(find.byKey(const Key('navigation_distance')), findsNothing);
    expect(find.textContaining('Через 0'), findsNothing);
    expect(find.text('Поверните направо'), findsOneWidget);
    position.dispose();
  });

  testWidgets('shows a live remaining summary from step metrics', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.9455, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [
          step(distanceMeters: 1000, durationSeconds: 600),
          step(lat: 51.96, distanceMeters: 2000, durationSeconds: 1200),
        ],
        position: position,
        distanceMeters: 9999,
        durationSeconds: 9999,
      ),
    );

    expect(find.text('2,5 км • 26 мин'), findsOneWidget);
    position.dispose();
  });

  testWidgets('long roundabout instruction is limited to two lines', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.947, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step(type: 'roundabout', exitNumber: 12)],
        position: position,
      ),
    );

    final instruction = tester.widget<Text>(
      find.byKey(const Key('navigation_instruction')),
    );
    expect(instruction.data, 'На кольце сверните на 12-й съезд');
    expect(instruction.maxLines, 2);
    position.dispose();
  });

  testWidgets('omits empty street and unavailable footer', (tester) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.947, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step(street: '')],
        position: position,
      ),
    );

    expect(find.byKey(const Key('navigation_street')), findsNothing);
    expect(find.byKey(const Key('navigation_route_summary')), findsNothing);
    position.dispose();
  });

  testWidgets('arrival and unknown maneuver use stable presentations', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.947, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step(type: 'arrive')],
        position: position,
        routeTarget: const LatLng(51.95, 66.4),
      ),
    );
    expect(find.text('Продолжайте к точке'), findsOneWidget);

    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step(type: 'mystery')],
        position: position,
        routeGeneration: 2,
      ),
    );
    expect(find.text('Продолжайте движение'), findsOneWidget);
    position.dispose();
  });

  testWidgets('route replacement resets the displayed first step', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.947, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step(modifier: 'right')],
        position: position,
      ),
    );
    expect(find.text('Поверните направо'), findsOneWidget);

    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step(modifier: 'left')],
        position: position,
        routeGeneration: 2,
      ),
    );
    expect(find.text('Поверните налево'), findsOneWidget);
    position.dispose();
  });

  testWidgets('technical depart immediately shows the next useful maneuver', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.95, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [
          step(type: 'depart', distanceMeters: 800),
          step(modifier: 'left', lat: 51.96),
        ],
        position: position,
      ),
    );

    expect(find.text('Начните движение'), findsNothing);
    expect(find.text('Поверните налево'), findsOneWidget);
    expect(find.text('Через 1,1 км'), findsOneWidget);
    position.dispose();
  });

  testWidgets('arrival appears only inside the safe target radius', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.949, 66.4));
    const target = LatLng(51.95, 66.4);
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step(type: 'arrive')],
        position: position,
        routeTarget: target,
      ),
    );
    expect(find.text('Вы прибыли'), findsNothing);
    expect(find.text('Продолжайте к точке'), findsOneWidget);

    position.value = const LatLng(51.9498, 66.4);
    await tester.pump();
    expect(find.text('Вы прибыли'), findsOneWidget);
    position.dispose();
  });

  test('poor GPS accuracy cannot confirm arrival', () {
    expect(
      navigationArrivalConfirmed(
        position: const LatLng(51.95, 66.4),
        target: const LatLng(51.95, 66.4),
        accuracyMeters: 80,
      ),
      isFalse,
    );
  });

  testWidgets('depart remains a fallback without a real maneuver', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.95, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step(type: 'depart')],
        position: position,
      ),
    );
    expect(find.text('Начните движение'), findsOneWidget);
    position.dispose();
  });

  testWidgets('never enters false recalculation without a callback', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.95, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step(), step(lat: 51.96)],
        position: position,
      ),
    );
    position.value = const LatLng(51.95001, 66.4);
    await tester.pump();
    position.value = const LatLng(51.949, 66.4);
    await tester.pump();

    expect(find.textContaining('Перерасчёт'), findsNothing);
    position.dispose();
  });

  testWidgets('shows rerouting only while request is active then instruction', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.947, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step()],
        position: position,
        isRerouting: true,
      ),
    );
    expect(find.text('Перестраиваем маршрут…'), findsOneWidget);

    await tester.pumpWidget(
      app(
        theme: ThemeData.light(),
        steps: [step(modifier: 'left')],
        position: position,
        routeGeneration: 2,
      ),
    );
    expect(find.byKey(const Key('navigation_rerouting')), findsNothing);
    expect(find.text('Поверните налево'), findsOneWidget);
    position.dispose();
  });

  testWidgets('failure is non-blocking and does not leave rerouting stuck', (
    tester,
  ) async {
    final position = ValueNotifier<LatLng?>(const LatLng(51.947, 66.4));
    await tester.pumpWidget(
      app(
        theme: ThemeData.dark(),
        steps: [step()],
        position: position,
        rerouteErrorMessage: 'Не удалось перестроить маршрут',
      ),
    );
    expect(find.byKey(const Key('navigation_rerouting')), findsNothing);
    expect(find.text('Не удалось перестроить маршрут'), findsOneWidget);
    expect(find.text('Поверните направо'), findsOneWidget);
    position.dispose();
  });
}
