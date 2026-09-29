import 'package:flutter/material.dart';

import '../screens/legal/terms_acceptance_screen.dart';
import 'tulpar_api_client.dart';

class TermsAcceptanceService {
  TermsAcceptanceService({TulparApiClient? apiClient})
    : _apiClient = apiClient ?? TulparApiClient();

  final TulparApiClient _apiClient;

  Future<bool> ensureAccepted(BuildContext context) async {
    final status = await _apiClient.getTermsStatus();
    if (status['accepted'] == true) return true;
    final version = status['currentVersion']?.toString();
    if (version == null || version.isEmpty || !context.mounted) return false;
    return await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => TermsAcceptanceScreen(
              version: version,
              onAccept: () => _apiClient.acceptTerms(version),
            ),
          ),
        ) ??
        false;
  }
}
