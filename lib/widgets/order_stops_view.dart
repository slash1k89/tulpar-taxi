import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/order_stops.dart';
import '../services/address_label_service.dart';

class OrderStopsView extends StatelessWidget {
  const OrderStopsView({super.key, required this.orderData, this.textColor});

  final Map<String, dynamic> orderData;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context);
    final pickup = AddressLabelService.fromOrder(orderData, locale, const [
      'fromAddress',
      'pickupAddress',
    ]);
    final stops = orderStopsFromData(orderData);
    final nextIndex = stops.indexWhere((stop) => !stop.isReached);
    final inProgress = orderData['status']?.toString() == 'in_progress';

    Widget row({
      required Key key,
      required String label,
      required IconData icon,
      required Color color,
      bool highlighted = false,
      bool reached = false,
    }) => Row(
      key: key,
      children: [
        Icon(icon, color: reached ? Colors.grey : color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: reached ? Colors.grey : textColor,
              fontSize: 14,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.normal,
              decoration: reached ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );

    final rows = <Widget>[];
    if (pickup.isNotEmpty) {
      rows.add(
        row(
          key: const Key('order_pickup'),
          label: pickup,
          icon: Icons.my_location,
          color: Colors.green,
        ),
      );
    }
    for (var index = 0; index < stops.length; index++) {
      final stop = stops[index];
      final localized = AddressLabelService.format(stop.raw, locale);
      if (rows.isNotEmpty) {
        rows.add(
          const Padding(
            padding: EdgeInsets.only(left: 3),
            child: Icon(Icons.arrow_downward, size: 14, color: Colors.grey),
          ),
        );
      }
      rows.add(
        row(
          key: Key('order_stop_${stop.sequence}'),
          label: stop.isFinal
              ? (localized.isEmpty ? stop.address : localized)
              : '${l10n.mapStopNumber(index + 1)} · ${localized.isEmpty ? stop.address : localized}',
          icon: stop.isReached
              ? Icons.check_circle_outline
              : stop.isFinal
              ? Icons.location_on
              : Icons.more_vert,
          color: stop.isFinal ? Colors.red : Colors.orange,
          highlighted: inProgress && index == nextIndex,
          reached: stop.isReached,
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 190),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('order_stops_view'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }
}
