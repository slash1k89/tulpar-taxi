import 'package:flutter/material.dart';

import '../../services/tulpar_api_client.dart';
import '../../widgets/app_drawer.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TulparApiClient _api = TulparApiClient();

  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _api.getOrderHistory();
  }

  Future<void> _refresh() async {
    final future = _api.getOrderHistory();

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

  String _address(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '???? ?? ??????' : text;
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
    return order['role'] == 'driver' ? '? ? ????????' : '? ? ????????';
  }

  @override
  Widget build(BuildContext context) {
    final mode = appModeFromRoute(context);

    return Scaffold(
      appBar: AppBar(title: const Text('?????? ???????')),
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
                    const Text(
                      '? ??????? ????????? ??????? ???????.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('????????'),
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
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.history, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(child: Text('? ??? ???? ??? ??????????? ???????')),
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

                final isCompleted = order['status'] == 'completed';

                final from = _address(order['fromAddress']);
                final to = _address(order['toAddress']);
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
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.cancel,
                          color: isCompleted ? Colors.green : Colors.red,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$from ? $to',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '${_price(order)} ?',
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
                          isCompleted ? '???????' : '??????',
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
