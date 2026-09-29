import 'package:flutter/material.dart';

import '../../config/store_release_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/legal_link_service.dart';

class AboutSupportScreen extends StatelessWidget {
  const AboutSupportScreen({
    super.key,
    this.linkService = const LegalLinkService(),
    this.supportEmail = StoreReleaseConfig.supportEmail,
    this.appVersion = StoreReleaseConfig.appVersion,
  });

  final LegalLinkService linkService;
  final String supportEmail;
  final String appVersion;

  Future<void> _open(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final opened = await action();
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).legalOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final configuredSupport = StoreReleaseConfig.isValidSupportEmail(
      supportEmail,
    )
        ? supportEmail.trim()
        : '';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutSupportTitle)),
      body: ListView(
        children: [
          ListTile(
            key: const Key('legal_terms_link'),
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.legalTerms),
            subtitle: Text(l10n.legalTermsHint),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _open(
              context,
              () => linkService.openHttps(StoreReleaseConfig.termsUrl),
            ),
          ),
          ListTile(
            key: const Key('legal_privacy_link'),
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.legalPrivacy),
            subtitle: Text(l10n.legalPrivacyHint),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _open(
              context,
              () => linkService.openHttps(StoreReleaseConfig.privacyUrl),
            ),
          ),
          ListTile(
            key: const Key('legal_account_deletion_link'),
            leading: const Icon(Icons.person_remove_outlined),
            title: Text(l10n.legalAccountDeletion),
            subtitle: Text(l10n.legalAccountDeletionHint),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _open(
              context,
              () => linkService.openHttps(
                StoreReleaseConfig.accountDeletionUrl,
              ),
            ),
          ),
          const Divider(),
          ListTile(
            key: const Key('legal_support_link'),
            leading: const Icon(Icons.support_agent_outlined),
            title: Text(l10n.legalSupport),
            subtitle: Text(
              configuredSupport.isEmpty
                  ? l10n.legalSupportPending
                  : configuredSupport,
            ),
            trailing: configuredSupport.isEmpty
                ? null
                : const Icon(Icons.open_in_new),
            onTap: configuredSupport.isEmpty
                ? null
                : () => _open(
                    context,
                    () => linkService.openSupportEmail(configuredSupport),
                  ),
          ),
          ListTile(
            key: const Key('app_version'),
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.legalVersion),
            subtitle: Text(appVersion),
          ),
        ],
      ),
    );
  }
}
