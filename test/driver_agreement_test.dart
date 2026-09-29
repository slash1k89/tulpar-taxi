import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_esil/screens/driver/driver_agreement_screen.dart';
import 'package:taxi_esil/services/driver_agreement_service.dart';
import 'package:taxi_esil/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('agreement acceptance is versioned and scoped to a user', () async {
    final service = DriverAgreementService();
    final acceptedAt = DateTime.utc(2026, 8, 17, 10, 30);

    expect(await service.hasAcceptedCurrentAgreement('driver-a'), isFalse);
    await service.acceptCurrentAgreement('driver-a', acceptedAt: acceptedAt);

    final acceptance = await service.getAcceptance('driver-a');
    expect(acceptance?.version, DriverAgreementService.currentVersion);
    expect(acceptance?.acceptedAt, acceptedAt);
    expect(await service.hasAcceptedCurrentAgreement('driver-a'), isTrue);
    expect(await service.hasAcceptedCurrentAgreement('driver-b'), isFalse);
  });

  test('invalid stored agreement is not treated as accepted', () async {
    SharedPreferences.setMockInitialValues({
      'driver_agreement_acceptance_driver-a': 'invalid json',
    });
    final service = DriverAgreementService();

    expect(await service.hasAcceptedCurrentAgreement('driver-a'), isFalse);
  });

  testWidgets('driver agreement must be confirmed before continuing', (
    tester,
  ) async {
    final service = DriverAgreementService();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriverAgreementScreen(
                      userId: 'driver-a',
                      agreementService: service,
                    ),
                  ),
                );
              },
              child: const Text('Открыть режим водителя'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть режим водителя'));
    await tester.pumpAndSettle();

    ElevatedButton acceptButton = tester.widget(
      find.widgetWithText(ElevatedButton, 'Принять и продолжить'),
    );
    expect(acceptButton.onPressed, isNull);

    await tester.tap(find.text('Я прочитал(а) правила и принимаю соглашение'));
    await tester.pump();

    acceptButton = tester.widget(
      find.widgetWithText(ElevatedButton, 'Принять и продолжить'),
    );
    expect(acceptButton.onPressed, isNotNull);

    await tester.tap(find.text('Принять и продолжить'));
    await tester.pumpAndSettle();

    expect(await service.hasAcceptedCurrentAgreement('driver-a'), isTrue);
    expect(find.text('Открыть режим водителя'), findsOneWidget);
  });
}
