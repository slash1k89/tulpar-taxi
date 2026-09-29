import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_esil/widgets/tulpar_map_visuals.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';

void main() {
  test('route uses the shared high-contrast stroke and outline', () {
    const points = [LatLng(51.95, 66.40), LatLng(51.97, 66.42)];
    final route = TulparMapVisuals.routePolyline(points);

    expect(route.points, points);
    expect(route.color, TulparMapVisuals.routeColor);
    expect(route.strokeWidth, TulparMapVisuals.routeStrokeWidth);
    expect(route.borderColor, TulparMapVisuals.routeOutlineColor);
    expect(route.borderStrokeWidth, TulparMapVisuals.routeOutlineWidth);
  });

  test('map colors remain legible on the light Tulpar v5 background', () {
    const mapBackground = Color(0xFFECEFF1);
    for (final color in [
      TulparMapVisuals.routeColor,
      TulparMapVisuals.pickupColor,
      TulparMapVisuals.destinationColor,
      TulparMapVisuals.userLocationColor,
    ]) {
      expect(_contrastRatio(color, mapBackground), greaterThanOrEqualTo(3));
    }
  });

  testWidgets('endpoint and location markers keep compact map-safe sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: Wrap(
              children: [
                TulparEndpointMarker(endpoint: TulparMapEndpoint.pickup),
                TulparEndpointMarker(endpoint: TulparMapEndpoint.destination),
                SizedBox.square(
                  dimension: TulparMapVisuals.userLocationMarkerSize,
                  child: TulparUserLocationMarker(),
                ),
                SizedBox.square(
                  dimension: TulparMapVisuals.vehicleMarkerSize,
                  child: TulparVehicleMarker(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.person_pin_circle), findsOneWidget);
    expect(find.byIcon(Icons.flag), findsOneWidget);
    expect(find.byIcon(Icons.local_taxi), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(TulparMapVisuals.endpointMarkerSize, inInclusiveRange(44, 52));
    expect(TulparMapVisuals.vehicleMarkerSize, inInclusiveRange(44, 52));
  });

  testWidgets(
    'vehicle applies a valid heading and ignores unavailable values',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
          home: const TulparVehicleMarker(headingDegrees: 90),
        ),
      );
      final transform = tester.widget<Transform>(find.byType(Transform));
      expect(
        transform.transform.entry(0, 0),
        closeTo(math.cos(math.pi / 2), 1e-9),
      );

      await tester.pumpWidget(
        MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
          home: const TulparVehicleMarker(headingDegrees: -1),
        ),
      );
      expect(find.byType(Transform), findsNothing);
    },
  );

  testWidgets('selection pin uses Tulpar teal and anchors its tip at center', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: TulparSelectionPin())),
      ),
    );

    final transform = tester.widget<Transform>(
      find.byKey(const Key('map_selection_pin_anchor')),
    );
    expect(TulparMapVisuals.selectionPinSize, inInclusiveRange(44, 48));
    expect(
      transform.transform.getTranslation().y,
      -TulparMapVisuals.selectionPinSize / 2,
    );
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

double _contrastRatio(Color a, Color b) {
  final lighter = math.max(_relativeLuminance(a), _relativeLuminance(b));
  final darker = math.min(_relativeLuminance(a), _relativeLuminance(b));
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  double linear(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * linear(color.r) +
      0.7152 * linear(color.g) +
      0.0722 * linear(color.b);
}
