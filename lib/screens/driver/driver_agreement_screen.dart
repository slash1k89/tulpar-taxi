import 'package:flutter/material.dart';

import '../../services/driver_agreement_service.dart';
import '../../l10n/generated/app_localizations.dart';

class DriverAgreementScreen extends StatefulWidget {
  const DriverAgreementScreen({
    super.key,
    required this.userId,
    this.agreementService,
    this.onAccept,
    this.onAccepted,
  });

  final String userId;
  final DriverAgreementService? agreementService;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onAccepted;

  @override
  State<DriverAgreementScreen> createState() => _DriverAgreementScreenState();
}

class _DriverAgreementScreenState extends State<DriverAgreementScreen> {
  bool _isConfirmed = false;
  bool _isSaving = false;

  Future<void> _acceptAgreement() async {
    if (!_isConfirmed || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      if (widget.onAccept != null) {
        await widget.onAccept!();
      } else {
        await (widget.agreementService ?? DriverAgreementService())
            .acceptCurrentAgreement(widget.userId);
      }
      if (!mounted) return;
      if (widget.onAccepted != null) {
        await widget.onAccepted!();
      } else {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).agreementSaveFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).agreementRulesTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context).agreementVersion(
                  DriverAgreementService.currentVersion.toString(),
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    AppLocalizations.of(context).agreementBody,
                    style: const TextStyle(fontSize: 16, height: 1.35),
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isConfirmed,
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() => _isConfirmed = value ?? false);
                      },
                title: Text(AppLocalizations.of(context).agreementConfirm),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isConfirmed && !_isSaving ? _acceptAgreement : null,
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        AppLocalizations.of(context).agreementAcceptContinue,
                      ),
              ),
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context).cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
