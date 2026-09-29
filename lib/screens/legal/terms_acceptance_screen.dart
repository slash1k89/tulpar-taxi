import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class TermsAcceptanceScreen extends StatefulWidget {
  const TermsAcceptanceScreen({
    super.key,
    required this.version,
    required this.onAccept,
  });

  final String version;
  final Future<Object?> Function() onAccept;

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  bool _confirmed = false;
  bool _submitting = false;

  Future<void> _accept() async {
    if (!_confirmed || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onAccept();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).termsAcceptFailed)),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.termsTitle)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(l10n.termsBody(widget.version)),
                  ),
                ),
                CheckboxListTile(
                  value: _confirmed,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _confirmed = value ?? false),
                  title: Text(l10n.termsConfirm),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _confirmed && !_submitting ? _accept : null,
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.termsAccept),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
