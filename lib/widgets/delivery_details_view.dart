import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/formatters.dart';

class DeliveryDetailsView extends StatelessWidget {
  const DeliveryDetailsView({
    super.key,
    required this.orderData,
    this.showLabel = true,
    this.enableRecipientCall = false,
  });

  final Map<String, dynamic> orderData;
  final bool showLabel;
  final bool enableRecipientCall;

  static bool isDelivery(Map<String, dynamic> orderData) =>
      orderData['serviceType']?.toString() == 'delivery';

  @override
  Widget build(BuildContext context) {
    if (!isDelivery(orderData)) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    final rawDelivery = orderData['delivery'];
    final delivery = rawDelivery is Map
        ? Map<String, dynamic>.from(rawDelivery)
        : const <String, dynamic>{};
    final description = delivery['itemDescription']?.toString().trim() ?? '';
    final recipientName = delivery['recipientName']?.toString().trim() ?? '';
    final recipientPhone = delivery['recipientPhone']?.toString().trim() ?? '';
    final destinationApartment =
        delivery['destinationApartment']?.toString().trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
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
                Icon(
                  Icons.local_shipping_outlined,
                  size: 17,
                  color: colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  'Доставка',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (description.isNotEmpty)
          _DetailRow(
            icon: Icons.inventory_2_outlined,
            label: 'Посылка: $description',
            color: colorScheme.onSurface,
          ),
        if (recipientName.isNotEmpty)
          _DetailRow(
            icon: Icons.person_outline,
            label: 'Получатель: $recipientName',
            color: colorScheme.onSurfaceVariant,
          ),
        if (recipientPhone.isNotEmpty)
          _DetailRow(
            icon: Icons.phone_outlined,
            label: 'Телефон: $recipientPhone',
            color: colorScheme.onSurfaceVariant,
            trailing: enableRecipientCall
                ? IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Позвонить получателю',
                    icon: const Icon(Icons.phone),
                    onPressed: () => _openDialer(context, recipientPhone),
                  )
                : null,
          ),
        if (destinationApartment.isNotEmpty)
          _DetailRow(
            icon: Icons.apartment_outlined,
            label: 'Квартира: $destinationApartment',
            color: colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }

  Future<void> _openDialer(BuildContext context, String phone) async {
    final normalizedPhone = normalizeRuPhone(phone);
    if (normalizedPhone.isEmpty) return;

    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: normalizedPhone),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть приложение звонков.')),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.color,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: color)),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}
