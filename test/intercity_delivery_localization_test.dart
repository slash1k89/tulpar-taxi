import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/screens/intercity/intercity_mode_screen.dart';
import 'package:taxi_esil/screens/driver/driver_intercity_mode_screen.dart';
import 'package:taxi_esil/widgets/delivery_details_view.dart';
import 'package:taxi_esil/widgets/intercity_details_view.dart';

void main() {
  testWidgets('intercity details inherit light text on a dark driver card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ColoredBox(
            color: const Color(0xFF1E1E1E),
            child: IntercityDetailsView(
              onDarkCard: true,
              orderData: {
                'serviceType': 'intercity',
                'intercity': {'passengerCount': 2},
              },
            ),
          ),
        ),
      ),
    );
    final label = find.text('Passengers: 2');
    expect(label, findsOneWidget);
    final text = tester.widget<Text>(label);
    expect(
      DefaultTextStyle.of(tester.element(label)).style.color,
      Colors.white,
    );
    expect(text.style?.color, isNull);
  });
  for (final (code, ride, package, passengers) in [
    ('ru', 'Найти попутку', 'Посылка: Книги', 'Пассажиров: 2'),
    ('kk', 'Сапарлас табу', 'Сәлемдеме: Книги', 'Жолаушылар: 2'),
    ('en', 'Find a shared ride', 'Package: Книги', 'Passengers: 2'),
  ]) {
    testWidgets('intercity and delivery common UI uses $code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(
              children: [
                Expanded(child: IntercityModeScreen()),
                DeliveryDetailsView(
                  orderData: {
                    'serviceType': 'delivery',
                    'delivery': {'itemDescription': 'Книги'},
                  },
                ),
                IntercityDetailsView(
                  orderData: {
                    'serviceType': 'intercity',
                    'intercity': {'passengerCount': 2},
                  },
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text(ride), findsOneWidget);
      expect(find.text(package), findsOneWidget);
      expect(find.text(passengers), findsOneWidget);
    });
  }
  for (final (code, orders, rides, create) in [
    ('ru', 'Заказы пассажиров', 'Мои поездки', 'Создать поездку'),
    ('kk', 'Жолаушылар тапсырыстары', 'Менің сапарларым', 'Сапар жасау'),
    ('en', 'Passenger orders', 'My rides', 'Create a ride'),
  ]) {
    testWidgets('driver intercity menu uses $code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DriverIntercityModeScreen(
            ordersBuilder: (_) => const SizedBox(),
            ridesBuilder: (_) => const SizedBox(),
            createBuilder: (_) => const SizedBox(),
          ),
        ),
      );
      expect(find.text(orders), findsOneWidget);
      expect(find.text(rides), findsOneWidget);
      expect(find.text(create), findsOneWidget);
    });
  }
}
