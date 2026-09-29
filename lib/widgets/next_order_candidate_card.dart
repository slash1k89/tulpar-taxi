import 'package:flutter/material.dart';

import '../models/next_order.dart';
import '../services/address_label_service.dart';
import '../l10n/generated/app_localizations.dart';

class NextOrderCandidateCard extends StatelessWidget {
  const NextOrderCandidateCard({
    super.key,
    required this.candidate,
    required this.isAccepting,
    required this.onAccept,
    required this.onOffer,
  });

  final NextOrderCandidate candidate;
  final bool isAccepting;
  final VoidCallback onAccept;
  final VoidCallback onOffer;

  String _price(int value) {
    final digits = value.toString();
    return digits.replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+$)'), (_) => ' ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('next_order_candidate_card'),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).nextOrderNearby,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              AppLocalizations.of(context).fromAddress(
                AddressLabelService.format(
                  candidate.pickupAddress,
                  Localizations.localeOf(context),
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              AppLocalizations.of(context).toAddress(
                AddressLabelService.format(
                  candidate.destinationAddress,
                  Localizations.localeOf(context),
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_price(candidate.passengerPrice)} ₸',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (candidate.distanceToCurrentDestinationMeters > 0)
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context).nextOrderDistance(
                        candidate.distanceToCurrentDestinationMeters,
                      ),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('next_order_offer_button'),
                    onPressed: isAccepting ? null : onOffer,
                    child: Text(AppLocalizations.of(context).nextOrderOwnPrice),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('next_order_accept_button'),
                    onPressed: isAccepting ? null : onAccept,
                    child: isAccepting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(AppLocalizations.of(context).nextOrderAccept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
