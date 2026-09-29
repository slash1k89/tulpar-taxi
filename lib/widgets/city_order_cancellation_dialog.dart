import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

typedef CityCancellationReason = ({String code, String? text});

Future<CityCancellationReason?> showCityCancellationDialog(
  BuildContext context, {
  required bool isDriver,
}) async {
  final l10n = AppLocalizations.of(context);
  final choices = isDriver
      ? <String, String>{
          'car_breakdown': l10n.cityCancelReasonCarBreakdown,
          'road_incident': l10n.cityCancelReasonRoadIncident,
          'passenger_requested': l10n.cityCancelReasonPassengerRequested,
          'passenger_problem': l10n.cityCancelReasonPassengerProblem,
          'emergency': l10n.cityCancelReasonEmergency,
          'other': l10n.cityCancelReasonOther,
        }
      : <String, String>{
          'plans_changed': l10n.cityCancelReasonPlansChanged,
          'car_problem': l10n.cityCancelReasonCarProblem,
          'driver_problem': l10n.cityCancelReasonDriverProblem,
          'emergency': l10n.cityCancelReasonEmergency,
          'other': l10n.cityCancelReasonOther,
        };
  String? selected;
  String details = '';
  bool showError = false;
  final reason = await showDialog<CityCancellationReason>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(l10n.cityCancelTripTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.cityCancelTripWarning),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.cityCancelReasonLabel,
                  errorText: showError ? l10n.cityCancelReasonRequired : null,
                ),
                items: choices.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() {
                  selected = value;
                  showError = false;
                }),
              ),
              if (selected == 'other') ...[
                const SizedBox(height: 12),
                TextField(
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: l10n.cityCancelReasonDetails,
                  ),
                  onChanged: (value) => details = value,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () {
              if (selected == null) {
                setDialogState(() => showError = true);
                return;
              }
              Navigator.pop(dialogContext, (
                code: selected!,
                text: selected == 'other' && details.trim().isNotEmpty
                    ? details.trim()
                    : null,
              ));
            },
            child: Text(l10n.yesCancel),
          ),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return null;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.cityCancelTripTitle),
      content: Text(l10n.cityCancelFinalConfirmation),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.no),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.yesCancel),
        ),
      ],
    ),
  );
  return confirmed == true ? reason : null;
}
