import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_esil/services/splash_startup_service.dart';
import 'package:taxi_esil/services/user_profile_recovery_service.dart';

void main() {
  const identity = UserProfileIdentity(
    uid: 'driver-uid',
    displayName: 'РРІР°РЅ',
    phoneNumber: '+77001234567',
  );

  test(
    'legacy users profile requires admin migration and is never written',
    () async {
      final repository = _MemoryRecoveryRepository({
        'isDriver': true,
        'driverActiveUntil': DateTime.utc(2026, 8, 17),
        'carModel': 'Toyota',
        'carColor': 'Р‘РµР»С‹Р№',
        'carNumber': '123ABC01',
      });
      final service = UserProfileRecoveryService(
        repository: repository,
        identityLoader: () => identity,
      );

      final result = await service.inspectAndRepair();

      expect(result.state, UserProfileRecoveryState.requiresAdminMigration);
      expect(
        result.missingFields,
        containsAll(UserProfileRecoveryPlanner.canonicalFields),
      );
      expect(result.adminMigrationFields, containsAll(result.missingFields));
      expect(result.safeClientUpdate, isEmpty);
      expect(result.legacyFieldsPresent, isTrue);
      expect(repository.updateCalls, 0);
    },
  );

  test('legacy isDriver never becomes a canonical driver role', () {
    final result = const UserProfileRecoveryPlanner().assess(
      identity: identity,
      data: {
        'isDriver': true,
        'driverActiveUntil': 'legacy-value',
        'carModel': 'Toyota',
        'carColor': 'Р‘РµР»С‹Р№',
        'carNumber': '123ABC01',
      },
    );

    expect(result.adminMigrationFields, contains('role'));
    expect(result.safeClientUpdate.containsKey('role'), isFalse);
    expect(result.allowsAppAccess, isFalse);
  });

  test(
    'missing phone is repaired only from Firebase Auth phoneNumber',
    () async {
      final repository = _MemoryRecoveryRepository({
        'uid': identity.uid,
        'name': 'РРІР°РЅ',
        'role': 'passenger',
        'rating': UserProfileRecoveryPlanner.defaultRating,
        'createdAt': DateTime.utc(2026, 8, 17),
      });
      final service = UserProfileRecoveryService(
        repository: repository,
        identityLoader: () => identity,
      );

      final result = await service.inspectAndRepair();

      expect(result.state, UserProfileRecoveryState.repaired);
      expect(repository.lastUpdate, {'phone': identity.phoneNumber});
      expect(repository.updateCalls, 1);
    },
  );

  test('synthetic email is not available as a phone recovery source', () async {
    final repository = _MemoryRecoveryRepository({
      'uid': identity.uid,
      'name': 'РРІР°РЅ',
      'role': 'passenger',
      'rating': UserProfileRecoveryPlanner.defaultRating,
      'createdAt': DateTime.utc(2026, 8, 17),
    });
    final service = UserProfileRecoveryService(
      repository: repository,
      identityLoader: () => const UserProfileIdentity(uid: 'driver-uid'),
    );

    final result = await service.inspectAndRepair();

    expect(result.state, UserProfileRecoveryState.requiresAdminMigration);
    expect(result.adminMigrationFields, contains('phone'));
    expect(repository.updateCalls, 0);
  });

  test(
    'missing name can be confirmed by the user when canonical base is valid',
    () async {
      final repository = _MemoryRecoveryRepository({
        'uid': identity.uid,
        'phone': '+77001234567',
        'role': 'passenger',
        'rating': UserProfileRecoveryPlanner.defaultRating,
        'createdAt': DateTime.utc(2026, 8, 17),
      });
      final service = UserProfileRecoveryService(
        repository: repository,
        identityLoader: () => const UserProfileIdentity(uid: 'driver-uid'),
      );

      final beforeConfirmation = await service.inspectAndRepair();
      expect(beforeConfirmation.state, UserProfileRecoveryState.needsName);
      expect(repository.updateCalls, 0);

      final repaired = await service.inspectAndRepair(
        userProvidedName: '  РќРѕРІРѕРµ РёРјСЏ  ',
      );
      expect(repaired.state, UserProfileRecoveryState.repaired);
      expect(repository.lastUpdate, {'name': 'РќРѕРІРѕРµ РёРјСЏ'});
      expect(repository.updateCalls, 1);
    },
  );

  test(
    'rating defaults to 5 only as an admin migration recommendation',
    () async {
      expect(UserProfileRecoveryPlanner.defaultRating, 5.0);
      final repository = _MemoryRecoveryRepository({
        'uid': identity.uid,
        'name': 'РРІР°РЅ',
        'phone': '+77001234567',
        'role': 'passenger',
        'createdAt': DateTime.utc(2026, 8, 17),
      });
      final service = UserProfileRecoveryService(
        repository: repository,
        identityLoader: () => identity,
      );

      final result = await service.inspectAndRepair();

      expect(result.adminMigrationFields, contains('rating'));
      expect(result.safeClientUpdate.containsKey('rating'), isFalse);
      expect(repository.updateCalls, 0);
    },
  );

  test(
    'startup blocks an incomplete profile before loading active orders',
    () async {
      var activeOrderLoads = 0;
      const recovery = UserProfileRecoveryResult(
        state: UserProfileRecoveryState.requiresAdminMigration,
        missingFields: ['uid', 'name', 'phone', 'role', 'rating', 'createdAt'],
        adminMigrationFields: [
          'uid',
          'name',
          'phone',
          'role',
          'rating',
          'createdAt',
        ],
        safeClientUpdate: {},
        legacyFieldsPresent: true,
      );
      final startup = SplashStartupService(
        authLoader: () async => true,
        profileRecoveryLoader: () async => recovery,
        activeOrderLoader: () async {
          activeOrderLoads++;
          return null;
        },
      );

      final destination = await startup.loadDestination();

      expect(destination.target, SplashTarget.profileRecovery);
      expect(activeOrderLoads, 0);
    },
  );
}

class _MemoryRecoveryRepository implements UserProfileRecoveryRepository {
  _MemoryRecoveryRepository(Map<String, dynamic>? initialData)
    : _data = initialData;

  final Map<String, dynamic>? _data;
  int updateCalls = 0;
  Map<String, Object>? lastUpdate;

  @override
  Future<Map<String, dynamic>?> load(String userId) async => _data;

  @override
  Future<void> update(String userId, Map<String, Object> data) async {
    updateCalls++;
    lastUpdate = Map<String, Object>.from(data);
  }
}
