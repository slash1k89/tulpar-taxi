import 'package:flutter/material.dart';

import '../models/intercity_pickup_draft.dart';
import '../screens/map/destination_picker_screen.dart';
import '../screens/map/intercity_place_picker_screens.dart';
import '../services/geocoding_service.dart';
import '../l10n/generated/app_localizations.dart';

typedef IntercityPickupPicker =
    Future<IntercityPickupDraft?> Function(
      BuildContext context,
      KazakhstanSettlement settlement,
      IntercityPickupDraft? current,
    );

Future<IntercityPickupDraft?> showIntercityPickupPicker(
  BuildContext context,
  KazakhstanSettlement settlement,
  IntercityPickupDraft? current,
) async {
  final selection = await Navigator.push<MapPointSelection>(
    context,
    MaterialPageRoute(
      builder: (_) => IntercityAddressPickerScreen(
        settlement: settlement,
        purpose: MapPointPurpose.pickup,
        initialSelection: current == null
            ? null
            : MapPointSelection(point: current.point, address: current.address),
      ),
    ),
  );
  if (selection == null) return null;
  return IntercityPickupDraft(
    address: selection.address.trim(),
    latitude: selection.point.latitude,
    longitude: selection.point.longitude,
    passengerComment: current?.passengerComment,
  );
}

class IntercityPickupField extends StatelessWidget {
  const IntercityPickupField({
    super.key,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final IntercityPickupDraft? value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final pickup = value;
    return InkWell(
      key: const Key('intercity_pickup_field'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).intercityPickupPoint,
          prefixIcon: const Icon(Icons.my_location_outlined),
          suffixIcon: Icon(
            pickup == null ? Icons.chevron_right : Icons.edit_outlined,
          ),
        ),
        child: Text(
          pickup?.address ?? AppLocalizations.of(context).intercityPickupPrompt,
          key: const Key('intercity_pickup_address'),
          style: pickup == null
              ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }
}
