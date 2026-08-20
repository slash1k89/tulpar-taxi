import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/screens/auth/register_screen.dart';
import 'package:taxi_esil/screens/driver/driver_onboarding_screen.dart';
import 'package:taxi_esil/services/driver_agreement_service.dart';
import 'package:taxi_esil/services/driver_profile_service.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('register fields follow ${brightness.name} color scheme', (
      tester,
    ) async {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: Colors.amber,
        brightness: brightness,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: colorScheme),
          home: const RegisterScreen(),
        ),
      );

      const keys = [
        Key('register_name_field'),
        Key('register_phone_field'),
        Key('register_password_field'),
        Key('register_confirm_password_field'),
      ];
      for (final key in keys) {
        _expectThemeColors(_textField(tester, key), colorScheme);
      }

      await tester.enterText(
        find.byKey(keys.first),
        'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРІвЂћСћР В Р’В Р вЂ™Р’В Р В Р вЂ Р Р†Р вЂљРЎвЂєР Р†Р вЂљРІР‚СљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В¶Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦',
      );
      expect(
        find.text(
          'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРІвЂћСћР В Р’В Р вЂ™Р’В Р В Р вЂ Р Р†Р вЂљРЎвЂєР Р†Р вЂљРІР‚СљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В¶Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦',
        ),
        findsOneWidget,
      );
    });

    testWidgets('driver onboarding vehicle fields follow ${brightness.name}', (
      tester,
    ) async {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: Colors.amber,
        brightness: brightness,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: colorScheme),
          home: DriverOnboardingScreen(
            repository: _VehicleStepRepository(),
            userId: 'driver-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      const keys = [
        Key('driver_car_model_field'),
        Key('driver_car_color_field'),
        Key('driver_car_number_field'),
      ];
      for (final key in keys) {
        _expectThemeColors(_textField(tester, key), colorScheme);
      }
    });
  }
}

TextField _textField(WidgetTester tester, Key key) {
  return tester.widget<TextField>(
    find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
  );
}

void _expectThemeColors(TextField field, ColorScheme colorScheme) {
  final decoration = field.decoration!;
  expect(field.style?.color, colorScheme.onSurface);
  expect(field.cursorColor, colorScheme.primary);
  expect(field.cursorErrorColor, colorScheme.error);
  expect(decoration.labelStyle?.color, colorScheme.onSurfaceVariant);
  expect(decoration.hintStyle?.color, colorScheme.onSurfaceVariant);
  expect(decoration.errorStyle?.color, colorScheme.error);
  expect(decoration.fillColor, colorScheme.surfaceContainerHighest);
}

class _VehicleStepRepository implements DriverProfileRepository {
  @override
  Future<DriverProfile?> load(String userId) async {
    final now = DateTime.utc(2026, 8, 18);
    return DriverProfile(
      userId: userId,
      status: DriverProfileStatus.draft,
      carModel: '',
      carColor: '',
      carNumber: '',
      agreementVersion: DriverAgreementService.currentVersion,
      agreementAcceptedAt: now,
      subscriptionStatus: 'inactive',
      subscriptionValidUntil: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> acceptCurrentAgreement(String userId) async {}

  @override
  Future<void> submitVehicle({
    required String userId,
    required String carModel,
    required String carColor,
    required String carNumber,
  }) async {}
}
