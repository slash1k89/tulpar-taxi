import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'tulpar_api_client.dart';

enum UserProfileRecoveryState {
  complete,
  repaired,
  needsName,
  requiresAdminMigration,
  missingDocument,
  unauthenticated,
}

class UserProfileIdentity {
  const UserProfileIdentity({
    required this.uid,
    this.displayName,
    this.phoneNumber,
    this.creationTime,
  });

  final String uid;
  final String? displayName;
  final String? phoneNumber;
  final DateTime? creationTime;
}

class UserProfileRecoveryResult {
  const UserProfileRecoveryResult({
    required this.state,
    required this.missingFields,
    required this.adminMigrationFields,
    required this.safeClientUpdate,
    required this.legacyFieldsPresent,
  });

  final UserProfileRecoveryState state;
  final List<String> missingFields;
  final List<String> adminMigrationFields;
  final Map<String, Object> safeClientUpdate;
  final bool legacyFieldsPresent;

  bool get allowsAppAccess =>
      state == UserProfileRecoveryState.complete ||
      state == UserProfileRecoveryState.repaired;

  bool get needsName => state == UserProfileRecoveryState.needsName;

  bool get requiresTrustedMigration =>
      state == UserProfileRecoveryState.requiresAdminMigration ||
      state == UserProfileRecoveryState.missingDocument;

  UserProfileRecoveryResult asRepaired() {
    return UserProfileRecoveryResult(
      state: UserProfileRecoveryState.repaired,
      missingFields: missingFields,
      adminMigrationFields: const [],
      safeClientUpdate: safeClientUpdate,
      legacyFieldsPresent: legacyFieldsPresent,
    );
  }
}

abstract interface class UserProfileRecoveryRepository {
  Future<Map<String, dynamic>?> load(String userId);

  Future<void> update(String userId, Map<String, Object> data);
}

class VpsUserProfileRecoveryRepository
    implements UserProfileRecoveryRepository {
  VpsUserProfileRecoveryRepository({TulparApiClient? apiClient})
    : _apiClient = apiClient ?? TulparApiClient();

  final TulparApiClient _apiClient;

  @override
  Future<Map<String, dynamic>?> load(String userId) async {
    // ??????????? ??????? ???????????? ? PostgreSQL.
    await _apiClient.syncCurrentUser();

    final data = await _apiClient.getCurrentUserProfile();

    if (data.isEmpty) {
      return null;
    }

    final firebaseUid = data['firebaseUid']?.toString() ?? userId;

    return <String, dynamic>{
      // ??????, ??????? ??? ???????? ???????????? RecoveryPlanner.
      'uid': firebaseUid,
      'name': data['name'],
      'phone': data['phone'],

      // ? PostgreSQL ???? ???????????? ?????? ?? ???????? ? users.
      // ???????? ???????????? ????????? driver_profiles.
      // ??? ??????? recovery planner ????????? ??????? ???? ?????????.
      'role': 'passenger',

      'rating': data['rating'] ?? 5.0,
      'createdAt': data['createdAt'],
    };
  }

  @override
  Future<void> update(String userId, Map<String, Object> data) async {
    final name = data['name'];

    if (name is String && name.trim().isNotEmpty) {
      await _apiClient.updateCurrentUserProfile(name: name);
    }
  }
}

class UserProfileRecoveryPlanner {
  static const canonicalFields = {
    'uid',
    'name',
    'phone',
    'role',
    'rating',
    'createdAt',
  };

  static const protectedFields = {'uid', 'role', 'rating', 'createdAt'};

  static const legacyFields = {
    'isDriver',
    'driverActiveUntil',
    'carModel',
    'carColor',
    'carNumber',
  };

  static const double defaultRating = 5.0;

  const UserProfileRecoveryPlanner();

  UserProfileRecoveryResult assess({
    required UserProfileIdentity identity,
    required Map<String, dynamic>? data,
    String? userProvidedName,
  }) {
    if (identity.uid.isEmpty) {
      return const UserProfileRecoveryResult(
        state: UserProfileRecoveryState.unauthenticated,
        missingFields: [],
        adminMigrationFields: [],
        safeClientUpdate: {},
        legacyFieldsPresent: false,
      );
    }
    if (data == null) {
      return const UserProfileRecoveryResult(
        state: UserProfileRecoveryState.missingDocument,
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
        legacyFieldsPresent: false,
      );
    }

    final missing = <String>[];
    final admin = <String>[];
    final legacyPresent = legacyFields.any(data.containsKey);

    final uidIsValid = data['uid'] == identity.uid;
    if (!uidIsValid) {
      missing.add('uid');
      admin.add('uid');
    }

    final roleIsValid = data['role'] == 'passenger';
    if (!roleIsValid) {
      missing.add('role');
      admin.add('role');
    }

    final rating = data['rating'];
    final ratingIsValid =
        rating is num && rating >= 0 && rating <= defaultRating;
    if (!ratingIsValid) {
      missing.add('rating');
      // The current Rules do not allow an owner to add or change rating.
      admin.add('rating');
    }

    final createdAtIsValid = _validDate(data['createdAt']);
    if (!createdAtIsValid) {
      missing.add('createdAt');
      admin.add('createdAt');
    }

    final existingName = _validString(data['name'], 80);
    final trustedAuthName = _normalizedString(identity.displayName, 80);
    final confirmedName = _normalizedString(userProvidedName, 80);
    final resolvedName = existingName
        ? (data['name'] as String).trim()
        : trustedAuthName ?? confirmedName;
    if (!existingName) missing.add('name');

    final existingPhone = _validString(data['phone'], 20);
    // Do not infer a phone number from the synthetic @tulpar.kz email.
    final trustedAuthPhone = _normalizedString(identity.phoneNumber, 20);
    final resolvedPhone = existingPhone
        ? (data['phone'] as String).trim()
        : trustedAuthPhone;
    if (!existingPhone) missing.add('phone');

    if (!existingPhone && trustedAuthPhone == null) {
      admin.add('phone');
    }

    if (admin.isNotEmpty) {
      // A legacy document without immutable canonical fields cannot pass the
      // current owner-update rule at all. Repair every missing canonical field
      // in one trusted migration instead of attempting a partial client write.
      for (final field in missing) {
        if (!admin.contains(field)) admin.add(field);
      }
      return UserProfileRecoveryResult(
        state: UserProfileRecoveryState.requiresAdminMigration,
        missingFields: List.unmodifiable(missing),
        adminMigrationFields: List.unmodifiable(admin),
        safeClientUpdate: const {},
        legacyFieldsPresent: legacyPresent,
      );
    }

    if (resolvedName == null) {
      return UserProfileRecoveryResult(
        state: UserProfileRecoveryState.needsName,
        missingFields: List.unmodifiable(missing),
        adminMigrationFields: const [],
        safeClientUpdate: const {},
        legacyFieldsPresent: legacyPresent,
      );
    }

    if (resolvedPhone == null) {
      return UserProfileRecoveryResult(
        state: UserProfileRecoveryState.requiresAdminMigration,
        missingFields: List.unmodifiable(missing),
        adminMigrationFields: const ['phone'],
        safeClientUpdate: const {},
        legacyFieldsPresent: legacyPresent,
      );
    }

    final safeUpdate = <String, Object>{};
    if (!existingName) safeUpdate['name'] = resolvedName;
    if (!existingPhone) safeUpdate['phone'] = resolvedPhone;

    return UserProfileRecoveryResult(
      state: safeUpdate.isEmpty
          ? UserProfileRecoveryState.complete
          : UserProfileRecoveryState.repaired,
      missingFields: List.unmodifiable(missing),
      adminMigrationFields: const [],
      safeClientUpdate: Map.unmodifiable(safeUpdate),
      legacyFieldsPresent: legacyPresent,
    );
  }

  static bool _validDate(Object? value) {
    if (value is DateTime) return true;

    if (value is String) {
      return DateTime.tryParse(value) != null;
    }

    try {
      final dynamic legacyValue = value;
      return legacyValue?.toDate() is DateTime;
    } catch (_) {
      return false;
    }
  }

  bool _validString(Object? value, int maximumLength) {
    return value is String &&
        value.trim().isNotEmpty &&
        value.trim().length <= maximumLength;
  }

  String? _normalizedString(String? value, int maximumLength) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty || normalized.length > maximumLength) return null;
    return normalized;
  }
}

class UserProfileRecoveryService {
  UserProfileRecoveryService({
    UserProfileRecoveryRepository? repository,
    UserProfileIdentity? Function()? identityLoader,
    UserProfileRecoveryPlanner planner = const UserProfileRecoveryPlanner(),
  }) : _repository = repository ?? VpsUserProfileRecoveryRepository(),
       _identityLoader = identityLoader ?? _firebaseIdentity,
       _planner = planner;

  final UserProfileRecoveryRepository _repository;
  final UserProfileIdentity? Function() _identityLoader;
  final UserProfileRecoveryPlanner _planner;

  Future<UserProfileRecoveryResult> inspectAndRepair({
    String? userProvidedName,
  }) async {
    final identity = _identityLoader();
    if (identity == null) {
      return const UserProfileRecoveryResult(
        state: UserProfileRecoveryState.unauthenticated,
        missingFields: [],
        adminMigrationFields: [],
        safeClientUpdate: {},
        legacyFieldsPresent: false,
      );
    }

    final data = await _repository.load(identity.uid);
    final result = _planner.assess(
      identity: identity,
      data: data,
      userProvidedName: userProvidedName,
    );
    _log(identity.uid, result);

    if (result.state == UserProfileRecoveryState.repaired &&
        result.safeClientUpdate.isNotEmpty) {
      await _repository.update(identity.uid, result.safeClientUpdate);
      return result.asRepaired();
    }
    return result;
  }

  static UserProfileIdentity? _firebaseIdentity() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return UserProfileIdentity(
      uid: user.uid,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      creationTime: user.metadata.creationTime,
    );
  }

  void _log(String uid, UserProfileRecoveryResult result) {
    if (!kDebugMode) return;
    debugPrint('[UserProfileRecovery]');
    debugPrint('uid=$uid');
    debugPrint('state=${result.state.name}');
    debugPrint('missingFields=${result.missingFields.join(',')}');
    debugPrint('adminMigrationFields=${result.adminMigrationFields.join(',')}');
    debugPrint('legacyFieldsPresent=${result.legacyFieldsPresent}');
  }
}
