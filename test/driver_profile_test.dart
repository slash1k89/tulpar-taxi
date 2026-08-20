import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/screens/driver/driver_onboarding_screen.dart';
import 'package:taxi_esil/services/driver_agreement_service.dart';
import 'package:taxi_esil/services/driver_profile_service.dart';

void main() {
  test('driver profile parser and flow do not depend on users.role', () {
    final profile = DriverProfile.fromFirestore('user-1', {
      'userId': 'user-1',
      'status': 'approved',
      'carModel': 'Toyota Camry',
      'carColor':
          'Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РЎС›Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РЎС›Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В»Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљРІвЂћвЂ“Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В РІР‚В Р В Р вЂ Р В РІР‚С™Р РЋРІР‚С”Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎС™Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р В РІР‚В Р В Р’В Р Р†Р вЂљРЎв„ўР В Р Р‹Р Р†Р вЂљРЎвЂќР В Р’В Р В РІР‚В Р В Р’В Р Р†Р вЂљРЎв„ўР В Р вЂ Р В РІР‚С™Р РЋРЎв„ў',
      'carNumber': '777 ABC 01',
      'agreementVersion': DriverAgreementService.currentVersion,
      'agreementAcceptedAt': DateTime.utc(2026, 8, 17),
      'subscriptionStatus': 'inactive',
      'subscriptionValidUntil': null,
      'createdAt': DateTime.utc(2026, 8, 17),
      'updatedAt': DateTime.utc(2026, 8, 17),
    });

    expect(profile.status, DriverProfileStatus.approved);
    expect(profile.hasCompleteVehicle, isTrue);
    expect(resolveDriverOnboardingStep(profile), DriverOnboardingStep.approved);
  });

  test('outdated agreement version returns user to agreement step', () {
    final current = _profile(DriverProfileStatus.approved);
    final outdated = DriverProfile(
      userId: current.userId,
      status: current.status,
      carModel: current.carModel,
      carColor: current.carColor,
      carNumber: current.carNumber,
      agreementVersion: '0.9',
      agreementAcceptedAt: current.agreementAcceptedAt,
      subscriptionStatus: current.subscriptionStatus,
      subscriptionValidUntil: current.subscriptionValidUntil,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );

    expect(
      resolveDriverOnboardingStep(outdated),
      DriverOnboardingStep.agreement,
    );
  });

  testWidgets(
    'new user accepts agreement, enters vehicle and becomes pending',
    (tester) async {
      final repository = _FakeDriverProfileRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: DriverOnboardingScreen(
            repository: repository,
            userId: 'user-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsOneWidget);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('driver_car_model_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('driver_car_model_field')),
        'Toyota Camry',
      );

      await tester.enterText(
        find.byKey(const Key('driver_car_color_field')),
        'White',
      );

      await tester.enterText(
        find.byKey(const Key('driver_car_number_field')),
        '777 abc 01',
      );

      await tester.tap(
        find.byKey(const Key('submit_driver_application_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.hourglass_top), findsOneWidget);

      expect(repository.lastCarNumber, '777 ABC 01');
    },
  );
  testWidgets('pending profile skips agreement and vehicle form', (
    tester,
  ) async {
    final repository = _FakeDriverProfileRepository(
      initialProfile: _profile(DriverProfileStatus.pending),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DriverOnboardingScreen(repository: repository, userId: 'user-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);

    expect(find.byType(CheckboxListTile), findsNothing);

    expect(find.byKey(const Key('driver_car_model_field')), findsNothing);
  });
  testWidgets('approved profile opens driver destination immediately', (
    tester,
  ) async {
    final repository = _FakeDriverProfileRepository(
      initialProfile: _profile(DriverProfileStatus.approved),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DriverOnboardingScreen(
          repository: repository,
          userId: 'user-1',
          driverDestinationBuilder: (_) =>
              const Scaffold(body: Text('Driver orders ready')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Driver orders ready'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('suspended profile shows notice and blocks driver destination', (
    tester,
  ) async {
    final repository = _FakeDriverProfileRepository(
      initialProfile: _profile(DriverProfileStatus.suspended),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DriverOnboardingScreen(
          repository: repository,
          userId: 'user-1',
          driverDestinationBuilder: (_) =>
              const Scaffold(body: Text('Driver orders ready')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.text('Driver orders ready'), findsNothing);
  });
}

DriverProfile _profile(DriverProfileStatus status) {
  final now = DateTime.utc(2026, 8, 17);
  return DriverProfile(
    userId: 'user-1',
    status: status,
    carModel: 'Toyota Camry',
    carColor:
        'Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РЎС›Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РЎС›Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В»Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљРІвЂћвЂ“Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В РІР‚В Р В Р вЂ Р В РІР‚С™Р РЋРІР‚С”Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎС™Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р В РІР‚В Р В Р’В Р Р†Р вЂљРЎв„ўР В Р Р‹Р Р†Р вЂљРЎвЂќР В Р’В Р В РІР‚В Р В Р’В Р Р†Р вЂљРЎв„ўР В Р вЂ Р В РІР‚С™Р РЋРЎв„ў',
    carNumber: '777 ABC 01',
    agreementVersion: DriverAgreementService.currentVersion,
    agreementAcceptedAt: now,
    subscriptionStatus: 'inactive',
    subscriptionValidUntil: null,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeDriverProfileRepository implements DriverProfileRepository {
  _FakeDriverProfileRepository({DriverProfile? initialProfile})
    : profile = initialProfile;

  DriverProfile? profile;
  String? lastCarNumber;

  @override
  Future<DriverProfile?> load(String userId) async => profile;

  @override
  Future<void> acceptCurrentAgreement(String userId) async {
    final now = DateTime.utc(2026, 8, 17);
    profile = DriverProfile(
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
  Future<void> submitVehicle({
    required String userId,
    required String carModel,
    required String carColor,
    required String carNumber,
  }) async {
    lastCarNumber = carNumber.trim().toUpperCase();
    final now = DateTime.utc(2026, 8, 17);
    profile = DriverProfile(
      userId: userId,
      status: DriverProfileStatus.pending,
      carModel: carModel.trim(),
      carColor: carColor.trim(),
      carNumber: lastCarNumber!,
      agreementVersion: DriverAgreementService.currentVersion,
      agreementAcceptedAt: now,
      subscriptionStatus: 'inactive',
      subscriptionValidUntil: null,
      createdAt: now,
      updatedAt: now,
    );
  }
}
