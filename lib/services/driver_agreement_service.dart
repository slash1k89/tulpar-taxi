import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DriverAgreementAcceptance {
  const DriverAgreementAcceptance({
    required this.version,
    required this.acceptedAt,
  });

  final String version;
  final DateTime acceptedAt;
}

class DriverAgreementService {
  static const String currentVersion = '1.0';
  static const String _keyPrefix = 'driver_agreement_acceptance_';

  Future<bool> hasAcceptedCurrentAgreement(String userId) async {
    final acceptance = await getAcceptance(userId);
    return acceptance?.version == currentVersion;
  }

  Future<DriverAgreementAcceptance?> getAcceptance(String userId) async {
    if (userId.trim().isEmpty) return null;

    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString('$_keyPrefix$userId');
    if (encoded == null) return null;

    try {
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic>) return null;

      final version = data['version'];
      final acceptedAt = DateTime.tryParse(
        data['acceptedAt']?.toString() ?? '',
      );
      if (version is! String || acceptedAt == null) return null;

      return DriverAgreementAcceptance(
        version: version,
        acceptedAt: acceptedAt,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> acceptCurrentAgreement(
    String userId, {
    DateTime? acceptedAt,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User ID cannot be empty.');
    }

    final acceptance = <String, String>{
      'version': currentVersion,
      'acceptedAt': (acceptedAt ?? DateTime.now().toUtc()).toIso8601String(),
    };
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      '$_keyPrefix$userId',
      jsonEncode(acceptance),
    );
    if (!saved) {
      throw StateError('Driver agreement acceptance was not saved.');
    }
  }
}
