import 'package:flutter/material.dart';

import '../../models/order_service_type.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/tulpar_api_client.dart';
import '../../services/address_label_service.dart';
import '../../widgets/app_drawer.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.historyLoader});

  final Future<List<Map<String, dynamic>>> Function()? historyLoader;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  TulparApiClient? _api;

  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<Map<String, dynamic>>> _loadHistory() =>
      widget.historyLoader?.call() ??
      (_api ??= TulparApiClient()).getOrderHistory();

  Future<void> _refresh() async {
    final future = _loadHistory();

    setState(() {
      _historyFuture = future;
    });

    await future;
  }

  String _price(Map<String, dynamic> order) {
    final value =
        order['price'] ?? order['agreedPrice'] ?? order['passengerPrice'] ?? 0;

    return value.toString();
  }

  String _address(Map<String, dynamic> order, List<String> keys) {
    final text = AddressLabelService.fromOrder(
      order,
      Localizations.localeOf(context),
      keys,
    );
    return text.isEmpty ? AppLocalizations.of(context).historyNoAddress : text;
  }

  String _dateText(Map<String, dynamic> order) {
    final raw =
        order['completedAt'] ?? order['cancelledAt'] ?? order['createdAt'];

    if (raw == null) return '';

    final date = DateTime.tryParse(raw.toString())?.toLocal();

    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.$year  $hour:$minute';
  }

  String _roleText(Map<String, dynamic> order) {
    return order['role'] == 'driver'
        ? AppLocalizations.of(context).historyDriverRole
        : AppLocalizations.of(context).historyPassengerRole;
  }

  @override
  Widget build(BuildContext context) {
    final mode = appModeFromRoute(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).historyTitle)),
      drawer: AppDrawer(mode: mode),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).historyLoadFailed,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: Text(AppLocalizations.of(context).retry),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? const [];

          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  const Icon(Icons.history, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(AppLocalizations.of(context).historyEmpty),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];

                final status = order['status']?.toString() ?? '';
                final isCompleted = status == 'completed';
                final serviceType = OrderServiceType.fromValue(
                  order['serviceType'],
                );

                final from = _address(order, const [
                  'fromAddress',
                  'pickupAddress',
                ]);
                final to = _address(order, const [
                  'toAddress',
                  'destinationAddress',
                ]);
                final date = _dateText(order);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(serviceType.icon, color: Colors.amber, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                serviceType.localizedTitle(
                                  AppLocalizations.of(context),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$from → $to',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).historyPrice(_price(order)),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _roleText(order),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              if (date.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  date,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCompleted
                              ? AppLocalizations.of(context).historyCompleted
                              : status == 'cancelled'
                              ? AppLocalizations.of(context).historyCancelled
                              : status,
                          style: TextStyle(
                            color: isCompleted ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
