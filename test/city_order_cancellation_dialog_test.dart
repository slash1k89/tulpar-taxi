import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';
import 'package:taxi_esil/widgets/city_order_cancellation_dialog.dart';

Widget app(
  Locale locale, {
  required bool isDriver,
  required void Function(CityCancellationReason?) onResult,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => onResult(
          await showCityCancellationDialog(context, isDriver: isDriver),
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  testWidgets('started ride requires reason and second confirmation', (
    tester,
  ) async {
    CityCancellationReason? result;
    await tester.pumpWidget(
      app(
        const Locale('ru'),
        isDriver: false,
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить поездку?'), findsOneWidget);
    await tester.tap(find.text('Да, отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Выберите причину отмены поездки.'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Экстренная ситуация').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Да, отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Подтвердить отмену начавшейся поездки?'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.text('Да, отменить'));
    await tester.pumpAndSettle();
    expect(result?.code, 'emergency');
  });

  for (final locale in const ['ru', 'kk', 'en']) {
    testWidgets('$locale driver cancellation choices are localized', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(Locale(locale), isDriver: true, onResult: (_) {}),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final labels = {
        'ru': 'Поломка автомобиля',
        'kk': 'Көлік бұзылды',
        'en': 'Car breakdown',
      };
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text(labels[locale]!), findsWidgets);
    });
  }
}
