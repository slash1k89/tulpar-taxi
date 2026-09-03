import 'dart:async';

import 'driver_agreement_service.dart';
import 'tulpar_api_client.dart';

enum DriverProfileStatus { draft, pending, approved, suspended }

enum DriverOnboardingStep { agreement, vehicle, pending, approved, suspended }

class DriverProfileException implements Exception {
  const DriverProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DriverProfile {
  const DriverProfile({
    required this.userId,
    required this.status,
    required this.carModel,
    required this.carColor,
    required this.carNumber,
    required this.agreementVersion,
    required this.agreementAcceptedAt,
    required this.subscriptionStatus,
    required this.subscriptionValidUntil,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final DriverProfileStatus status;
  final String carModel;
  final String carColor;
  final String carNumber;
  final String agreementVersion;
  final DateTime? agreementAcceptedAt;
  final String subscriptionStatus;
  final DateTime? subscriptionValidUntil;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasAcceptedCurrentAgreement =>
      agreementVersion == DriverAgreementService.currentVersion &&
      agreementAcceptedAt != null;

  bool get hasCompleteVehicle =>
      carModel.trim().isNotEmpty &&
      carColor.trim().isNotEmpty &&
      carNumber.trim().isNotEmpty;

  factory DriverProfile.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final normalized = Map<String, dynamic>.from(data);

    normalized['userId'] ??= documentId;

    return DriverProfile.fromApi(normalized);
  }
  factory DriverProfile.fromApi(Map<String, dynamic> data) {
    final userId = data['userId']?.toString() ?? '';
    final status = _parseStatus(data['status']);
    final carModel = data['carModel']?.toString() ?? '';
    final carColor = data['carColor']?.toString() ?? '';
    final carNumber = data['carNumber']?.toString() ?? '';
    final agreementVersion = data['agreementVersion']?.toString() ?? '';

    if (userId.isEmpty || status == null) {
      throw const DriverProfileException(
        'Профиль водителя поврежден. Обратитесь к администратору.',
      );
    }

    return DriverProfile(
      userId: userId,
      status: status,
      carModel: carModel,
      carColor: carColor,
      carNumber: carNumber,
      agreementVersion: agreementVersion,
      agreementAcceptedAt: _readDate(data['agreementAcceptedAt']),
      subscriptionStatus: data['subscriptionStatus']?.toString() ?? 'inactive',
      subscriptionValidUntil: _readDate(data['subscriptionValidUntil']),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  static DriverProfileStatus? _parseStatus(Object? value) {
    return switch (value?.toString()) {
      'draft' => DriverProfileStatus.draft,
      'pending' => DriverProfileStatus.pending,

      // VPS использует статус active,
      // а Flutter UI исторически ожидает approved.
      'active' => DriverProfileStatus.approved,
      'approved' => DriverProfileStatus.approved,

      'suspended' => DriverProfileStatus.suspended,
      _ => null,
    };
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}

DriverOnboardingStep resolveDriverOnboardingStep(DriverProfile? profile) {
  if (profile == null || !profile.hasAcceptedCurrentAgreement) {
    return DriverOnboardingStep.agreement;
  }

  return switch (profile.status) {
    DriverProfileStatus.draft => DriverOnboardingStep.vehicle,
    DriverProfileStatus.pending => DriverOnboardingStep.pending,
    DriverProfileStatus.approved => DriverOnboardingStep.approved,
    DriverProfileStatus.suspended => DriverOnboardingStep.suspended,
  };
}

abstract interface class DriverProfileRepository {
  Future<DriverProfile?> load(String userId);

  Future<void> acceptCurrentAgreement(String userId);

  Future<DriverProfile> submitVehicle({
    required String userId,
    required String carModel,
    required String carColor,
    required String carNumber,
  });
}

class ApiDriverProfileRepository implements DriverProfileRepository {
  ApiDriverProfileRepository({
    TulparApiClient? apiClient,
    DriverAgreementService? localAgreementCache,
  }) : _apiClient = apiClient ?? TulparApiClient(),
       _localAgreementCache = localAgreementCache ?? DriverAgreementService();

  final TulparApiClient _apiClient;
  final DriverAgreementService _localAgreementCache;

  @override
  Future<DriverProfile?> load(String userId) async {
    if (userId.trim().isEmpty) {
      return null;
    }

    try {
      final raw = await _apiClient.getCurrentDriverProfile().timeout(
        const Duration(seconds: 10),
      );

      if (raw == null) {
        return null;
      }

      return DriverProfile.fromApi(raw);
    } on TimeoutException {
      rethrow;
    } on TulparApiException catch (error) {
      throw DriverProfileException(_messageForApiError(error));
    }
  }

  @override
  Future<void> acceptCurrentAgreement(String userId) async {
    if (userId.trim().isEmpty) {
      throw const DriverProfileException(
        'Войдите в аккаунт, чтобы включить режим водителя.',
      );
    }

    try {
      var profile = await _apiClient.getCurrentDriverProfile().timeout(
        const Duration(seconds: 10),
      );

      if (profile == null) {
        await _apiClient.createCurrentDriverDraft().timeout(
          const Duration(seconds: 10),
        );
      }

      await _apiClient.acceptCurrentDriverAgreement().timeout(
        const Duration(seconds: 10),
      );

      try {
        await _localAgreementCache.acceptCurrentAgreement(userId);
      } catch (_) {
        // Локальный кэш не является источником истины.
      }
    } on TimeoutException {
      rethrow;
    } on TulparApiException catch (error) {
      throw DriverProfileException(_messageForApiError(error));
    }
  }

  @override
  Future<DriverProfile> submitVehicle({
    required String userId,
    required String carModel,
    required String carColor,
    required String carNumber,
  }) async {
    final normalizedModel = carModel.trim();
    final normalizedColor = carColor.trim();
    final normalizedNumber = carNumber.trim().toUpperCase();

    if (userId.trim().isEmpty) {
      throw const DriverProfileException(
        'Войдите в аккаунт, чтобы включить режим водителя.',
      );
    }

    if (normalizedModel.isEmpty ||
        normalizedColor.isEmpty ||
        normalizedNumber.isEmpty) {
      throw const DriverProfileException(
        'Заполните марку, цвет и государственный номер автомобиля.',
      );
    }

    try {
      final submitted = await _apiClient
          .submitCurrentDriverVehicle(
            carModel: normalizedModel,
            carColor: normalizedColor,
            carNumber: normalizedNumber,
          )
          .timeout(const Duration(seconds: 10));
      final refreshed = await _apiClient.getCurrentDriverProfile().timeout(
        const Duration(seconds: 10),
      );
      return DriverProfile.fromApi(refreshed ?? submitted);
    } on TimeoutException {
      rethrow;
    } on TulparApiException catch (error) {
      throw DriverProfileException(_messageForApiError(error));
    }
  }

  String _messageForApiError(TulparApiException error) {
    if (error.statusCode == 401) {
      return 'Сессия завершена. Войдите в аккаунт снова.';
    }

    if (error.statusCode == 404) {
      return 'Профиль водителя не найден.';
    }

    if (error.statusCode == 409) {
      return error.message;
    }

    if (error.statusCode >= 500) {
      return 'Сервер временно недоступен. Попробуйте ещё раз.';
    }

    return error.message;
  }
}

// Оставляем старое имя, чтобы не переделывать экран онбординга.
class FirebaseDriverProfileRepository extends ApiDriverProfileRepository {
  FirebaseDriverProfileRepository({super.apiClient, super.localAgreementCache});
}
