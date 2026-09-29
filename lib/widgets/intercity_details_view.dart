import 'package:flutter/material.dart';

import '../utils/intercity_ride_formatters.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/address_label_service.dart';

class IntercityDetailsView extends StatelessWidget {
  const IntercityDetailsView({
    super.key,
    required this.orderData,
    this.showRouteAndPrice = true,
    this.onDarkCard = false,
  });

  final Map<String, dynamic> orderData;
  final bool showRouteAndPrice;
  final bool onDarkCard;

  static bool isIntercity(Map<String, dynamic> orderData) =>
      orderData['serviceType']?.toString() == 'intercity';

  @override
  Widget build(BuildContext context) {
    if (!isIntercity(orderData)) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = onDarkCard ? Colors.white : colorScheme.onSurface;
    final raw = orderData['intercity'];
    final details = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    final scheduledAt = formatIntercityScheduledAt(
      details['departureAt'] ?? details['scheduledAt'],
    );
    final passengerCount = details['passengerCount'];
    final hasLuggage = details['hasLuggage'] == true;
    final comment = details['comment']?.toString().trim() ?? '';
    final price =
        orderData['agreedPrice'] ??
        orderData['passengerPrice'] ??
        orderData['price'];

    return DefaultTextStyle.merge(
      style: TextStyle(color: primaryColor),
      child: Column(
        key: const Key('intercity_details'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route, size: 17, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context).serviceIntercity,
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (showRouteAndPrice) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.my_location,
              label: AddressLabelService.fromOrder(
                orderData,
                Localizations.localeOf(context),
                const ['fromAddress', 'pickupAddress'],
              ),
            ),
            _DetailRow(
              icon: Icons.location_on,
              label: AddressLabelService.fromOrder(
                orderData,
                Localizations.localeOf(context),
                const ['toAddress', 'destinationAddress'],
              ),
            ),
          ],
          if (scheduledAt.isNotEmpty)
            _DetailRow(
              key: const Key('intercity_scheduled_at'),
              icon: Icons.event,
              label: AppLocalizations.of(
                context,
              ).intercityKazakhstanTime(scheduledAt),
            ),
          if (passengerCount is num)
            _DetailRow(
              icon: Icons.people_outline,
              label: AppLocalizations.of(
                context,
              ).intercityPassengers(passengerCount.toInt()),
            ),
          if (hasLuggage)
            _DetailRow(
              icon: Icons.luggage,
              label: AppLocalizations.of(context).intercityHasLuggage,
            ),
          if (comment.isNotEmpty)
            _DetailRow(
              icon: Icons.comment_outlined,
              label: AppLocalizations.of(context).intercityComment(comment),
            ),
          if (showRouteAndPrice && price is num)
            _DetailRow(
              icon: Icons.payments_outlined,
              label: AppLocalizations.of(context).intercityPrice(price.toInt()),
            ),
        ],
      ),
    );
  }
}

String formatIntercityScheduledAt(Object? raw) {
  final value = raw is DateTime
      ? raw
      : raw is String
      ? DateTime.tryParse(raw)
      : null;
  if (value == null) return '';
  return formatKazakhstanDateTime(value);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
