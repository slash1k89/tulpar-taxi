import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/app_routes.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/screens/map/order_tracking_screen.dart';
import 'package:taxi_esil/services/active_order_service.dart';
import 'package:taxi_esil/services/passenger_operational_state_resolver.dart';
import 'package:taxi_esil/widgets/app_drawer.dart';

void main() {
  tearDown(ActiveOrderService.clearRememberedOrder);

  testWidgets('active passenger order opens the same tracking route', (
    tester,
  ) async {
    final resolver = PassengerOperationalStateResolver(
      loader: () async => const ActiveOrder(
        orderId: 'order-42',
        isDriver: false,
        data: {'id': 'order-42', 'status': 'in_progress'},
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {AppRoutes.map: (_) => const Scaffold(key: Key('new-order'))},
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => resolver.openTaxi(context),
            child: const Text('taxi'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('taxi'));
    await tester.pumpAndSettle();
    final tracking = tester.widget<OrderTrackingScreen>(
      find.byType(OrderTrackingScreen),
    );
    expect(tracking.orderId, 'order-42');
    expect(find.byKey(const Key('new-order')), findsNothing);
  });

  for (final terminal in ['completed', 'cancelled']) {
    testWidgets('$terminal order opens a new order form', (tester) async {
      final resolver = PassengerOperationalStateResolver(
        loader: () async => null,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {AppRoutes.map: (_) => const Scaffold(key: Key('new-order'))},
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => resolver.openTaxi(context),
              child: Text(terminal),
            ),
          ),
        ),
      );
      await tester.tap(find.text(terminal));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new-order')), findsOneWidget);
    });
  }

  testWidgets('network failure keeps the last known passenger order', (
    tester,
  ) async {
    const known = ActiveOrder(
      orderId: 'order-known',
      isDriver: false,
      data: {'id': 'order-known', 'status': 'accepted'},
    );
    final resolver = PassengerOperationalStateResolver(
      loader: () async => throw Exception('offline'),
      lastKnownOrder: () => known,
    );
    await tester.pumpWidget(_testApp(resolver));
    await tester.tap(find.text('taxi'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OrderTrackingScreen>(find.byType(OrderTrackingScreen))
          .orderId,
      'order-known',
    );
    expect(find.byKey(const Key('new-order')), findsNothing);
  });

  testWidgets('timeout without known state does not open a new order form', (
    tester,
  ) async {
    final resolver = PassengerOperationalStateResolver(
      loader: () async => throw TimeoutException('timeout'),
      lastKnownOrder: () => null,
    );
    await tester.pumpWidget(_testApp(resolver));
    await tester.tap(find.text('taxi'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-order')), findsNothing);
    expect(find.text('Сервер не ответил. Попробуйте ещё раз.'), findsOneWidget);
  });

  testWidgets('taxi item in profile drawer returns to the active trip', (
    tester,
  ) async {
    final resolver = PassengerOperationalStateResolver(
      loader: () async => const ActiveOrder(
        orderId: 'profile-order',
        isDriver: false,
        data: {'id': 'profile-order', 'status': 'in_progress'},
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(),
          drawer: AppDrawer(
            mode: AppMode.passenger,
            userLabel: '+7 700 000 00 00',
            operationalStateResolver: resolver,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Открыть меню навигации'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer_service_city')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OrderTrackingScreen>(find.byType(OrderTrackingScreen))
          .orderId,
      'profile-order',
    );
  });
}

Widget _testApp(PassengerOperationalStateResolver resolver) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routes: {AppRoutes.map: (_) => const Scaffold(key: Key('new-order'))},
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => resolver.openTaxi(context),
        child: const Text('taxi'),
      ),
    ),
  ),
);
