import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/screens/map/map_screen.dart';
import 'package:taxi_esil/screens/splash_screen.dart';
import 'package:taxi_esil/services/order_creation_service.dart';
import 'package:taxi_esil/services/splash_startup_service.dart';

void main() {
  testWidgets('splash navigates immediately after required initialization', (
    tester,
  ) async {
    final required = Completer<void>();
    var navigations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          appInitialization: required.future,
          startupLoader: () async => const SplashDestination.login(),
          onNavigate: (_) => navigations++,
        ),
      ),
    );
    expect(navigations, 0);
    required.complete();
    await tester.pump();
    expect(navigations, 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(navigations, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('main map UI is visible while optional GPS remains pending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_city_id': 'esil'});
    final gps = Completer<LatLng?>();
    var gpsRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          showMapTiles: false,
          orderCreationService: OrderCreationService(gateway: _NoopGateway()),
          locationProvider: () {
            gpsRequested = true;
            return gps.future;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(gpsRequested, isTrue);
    expect(gps.isCompleted, isFalse);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
    gps.complete(null);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });
}

class _NoopGateway implements OrderCreationGateway {
  @override
  Future<String> create(OrderDraft draft) async => 'unused';
}
