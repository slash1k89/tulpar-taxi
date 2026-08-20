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
        'РЎР‚Р С•РЎвЂћР С‘Р В»РЎРЉ Р Р†Р С•Р Т‘Р С‘РЎвЂљР ВµР В»РЎРЏ Р С—Р С•Р Р†РЎР‚Р ВµР В¶Р Т‘РЎвЂР Р…. Р В±РЎР‚Р В°РЎвЂљР С‘РЎвЂљР ВµРЎРѓРЎРЉ Р С” Р В°Р Т‘Р СР С‘Р Р…Р С‘РЎРѓРЎвЂљРЎР‚Р В°РЎвЂљР С•РЎР‚РЎС“.',
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

      // VPS Р С‘РЎРѓР С—Р С•Р В»РЎРЉР В·РЎС“Р ВµРЎвЂљ active,
      // Р В° Flutter UI Р С‘РЎРѓРЎвЂљР С•РЎР‚Р С‘РЎвЂЎР ВµРЎРѓР С”Р С‘ Р С•Р В¶Р С‘Р Т‘Р В°Р ВµРЎвЂљ approved.
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

  Future<void> submitVehicle({
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
        'Р С•Р в„–Р Т‘Р С‘РЎвЂљР Вµ Р Р† Р В°Р С”Р С”Р В°РЎС“Р Р…РЎвЂљ, РЎвЂЎРЎвЂљР С•Р В±РЎвЂ№ Р Р†Р С”Р В»РЎР‹РЎвЂЎР С‘РЎвЂљРЎРЉ РЎР‚Р ВµР В¶Р С‘Р С Р Р†Р С•Р Т‘Р С‘РЎвЂљР ВµР В»РЎРЏ.',
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
        // Р С•Р С”Р В°Р В»РЎРЉР Р…РЎвЂ№Р в„– Р С”РЎРЊРЎв‚¬ Р Р…Р Вµ РЎРЏР Р†Р В»РЎРЏР ВµРЎвЂљРЎРѓРЎРЏ Р С‘РЎРѓРЎвЂљР С•РЎвЂЎР Р…Р С‘Р С”Р С•Р С Р С‘РЎРѓРЎвЂљР С‘Р Р…РЎвЂ№.
      }
    } on TimeoutException {
      rethrow;
    } on TulparApiException catch (error) {
      throw DriverProfileException(_messageForApiError(error));
    }
  }

  @override
  Future<void> submitVehicle({
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
        'Р С•Р в„–Р Т‘Р С‘РЎвЂљР Вµ Р Р† Р В°Р С”Р С”Р В°РЎС“Р Р…РЎвЂљ, РЎвЂЎРЎвЂљР С•Р В±РЎвЂ№ Р Р†Р С”Р В»РЎР‹РЎвЂЎР С‘РЎвЂљРЎРЉ РЎР‚Р ВµР В¶Р С‘Р С Р Р†Р С•Р Т‘Р С‘РЎвЂљР ВµР В»РЎРЏ.',
      );
    }

    if (normalizedModel.isEmpty ||
        normalizedColor.isEmpty ||
        normalizedNumber.isEmpty) {
      throw const DriverProfileException(
        'Р В°Р С—Р С•Р В»Р Р…Р С‘РЎвЂљР Вµ Р СР В°РЎР‚Р С”РЎС“, РЎвЂ Р Р†Р ВµРЎвЂљ Р С‘ Р С–Р С•РЎРѓРЎС“Р Т‘Р В°РЎР‚РЎРѓРЎвЂљР Р†Р ВµР Р…Р Р…РЎвЂ№Р в„– Р Р…Р С•Р СР ВµРЎР‚ Р В°Р Р†РЎвЂљР С•Р СР С•Р В±Р С‘Р В»РЎРЏ.',
      );
    }

    try {
      await _apiClient
          .submitCurrentDriverVehicle(
            carModel: normalizedModel,
            carColor: normalizedColor,
            carNumber: normalizedNumber,
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      rethrow;
    } on TulparApiException catch (error) {
      throw DriverProfileException(_messageForApiError(error));
    }
  }

  String _messageForApiError(TulparApiException error) {
    if (error.statusCode == 401) {
      return 'Р РЋР ВµРЎРѓРЎРѓР С‘РЎРЏ Р В·Р В°Р Р†Р ВµРЎР‚РЎв‚¬Р ВµР Р…Р В°. Р С•Р в„–Р Т‘Р С‘РЎвЂљР Вµ Р Р† Р В°Р С”Р С”Р В°РЎС“Р Р…РЎвЂљ РЎРѓР Р…Р С•Р Р†Р В°.';
    }

    if (error.statusCode == 404) {
      return 'РЎР‚Р С•РЎвЂћР С‘Р В»РЎРЉ Р Р†Р С•Р Т‘Р С‘РЎвЂљР ВµР В»РЎРЏ Р Р…Р Вµ Р Р…Р В°Р в„–Р Т‘Р ВµР Р….';
    }

    if (error.statusCode == 409) {
      return error.message;
    }

    if (error.statusCode >= 500) {
      return 'Р РЋР ВµРЎР‚Р Р†Р ВµРЎР‚ Р Р†РЎР‚Р ВµР СР ВµР Р…Р Р…Р С• Р Р…Р ВµР Т‘Р С•РЎРѓРЎвЂљРЎС“Р С—Р ВµР Р…. Р С•Р С—РЎР‚Р С•Р В±РЎС“Р в„–РЎвЂљР Вµ Р ВµРЎвЂ°РЎвЂ РЎР‚Р В°Р В·.';
    }

    return error.message;
  }
}

// РЎРѓРЎвЂљР В°Р Р†Р В»РЎРЏР ВµР С РЎРѓРЎвЂљР В°РЎР‚Р С•Р Вµ Р С‘Р СРЎРЏ, РЎвЂЎРЎвЂљР С•Р В±РЎвЂ№ Р Р…Р Вµ Р С—Р ВµРЎР‚Р ВµР Т‘Р ВµР В»РЎвЂ№Р Р†Р В°РЎвЂљРЎРЉ РЎРЊР С”РЎР‚Р В°Р Р… Р С•Р Р…Р В±Р С•РЎР‚Р Т‘Р С‘Р Р…Р С–Р В° Р С‘ РЎвЂљР ВµРЎРѓРЎвЂљРЎвЂ№.
class FirebaseDriverProfileRepository extends ApiDriverProfileRepository {
  FirebaseDriverProfileRepository({super.apiClient, super.localAgreementCache});
}
