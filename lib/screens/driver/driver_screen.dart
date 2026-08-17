import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../chat/chat_screen.dart';
import 'driver_map_screen.dart';
import '../../services/order_workflow_service.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isOnline = false;
  bool _isUpdatingAvailability = false;

  Future<void> _setOnline(bool value) async {
    setState(() => _isUpdatingAvailability = true);
    try {
      await OrderWorkflowService().setDriverOnline(value);
      if (mounted) setState(() => _isOnline = value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingAvailability = false);
    }
  }

  @override
  void dispose() {
    if (_isOnline) {
      OrderWorkflowService().setDriverOnline(false);
    }
    super.dispose();
  }

  Future<void> _acceptOrder(String orderId) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await OrderWorkflowService().acceptOrder(orderId);

      messenger.showSnackBar(
        const SnackBar(content: Text('Заказ принят! Направляйтесь к клиенту.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ошибка при принятии заказа: $e')),
      );
    }
  }

  double _calculateDistance(double fromLat, double fromLng, double toLat, double toLng) {
    if (fromLat == 0 || toLat == 0) return 0.0;
    final meters = const Distance().as(
      LengthUnit.Meter,
      LatLng(fromLat, fromLng),
      LatLng(toLat, toLng),
    );
    return meters / 1000;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Ошибка: Водитель не авторизован')),
      );
    }

    // 1. Автоматический вывод активного заказа для водителя
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('driverId', isEqualTo: _currentUserId)
          .where('status', whereIn: [
            'accepted',
            'arrived',
            'in_progress',
          ])
          .snapshots(),
      builder: (context, activeSnapshot) {
        if (activeSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }

        // Если есть активный заказ — переключаем на карту водителя со всеми данными заказа
        if (activeSnapshot.hasData && activeSnapshot.data!.docs.isNotEmpty) {
          final activeOrderDoc = activeSnapshot.data!.docs.first;
          final orderData = activeOrderDoc.data() as Map<String, dynamic>? ?? {};
          return DriverMapScreen(orderId: activeOrderDoc.id, orderData: orderData);
        }

        // 2. Если активного заказа нет — показываем список поиска
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            title: const Text('Заказы для водителя'),
            backgroundColor: const Color(0xFF1E1E1E),
            foregroundColor: Colors.amber,
            actions: [
              Row(
                children: [
                  const Text('На линии'),
                  Switch(
                    value: _isOnline,
                    onChanged: _isUpdatingAvailability ? null : _setOnline,
                  ),
                ],
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('status', isEqualTo: 'searching')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.amber));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Пока нет доступных заказов',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                );
              }

              final orders = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final doc = orders[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};

                  final double fromLat = (data['fromLat'] ?? 0.0).toDouble();
                  final double fromLng = (data['fromLng'] ?? 0.0).toDouble();
                  final double toLat = (data['toLat'] ?? 0.0).toDouble();
                  final double toLng = (data['toLng'] ?? 0.0).toDouble();

                  final double distanceKm = _calculateDistance(fromLat, fromLng, toLat, toLng);

                  return Card(
                    color: const Color(0xFF1E1E1E),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                data['passengerName'] ?? 'Пассажир',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                '${data['price'] ?? 500} ₸',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.my_location, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data['fromAddress'] ?? '',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data['toAddress'] ?? '',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.route, color: Colors.amber, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${distanceKm.toStringAsFixed(1)} км',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chat, color: Colors.amber),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            orderId: doc.id,
                                            peerName: data['passengerName'] ?? 'Пассажир',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _acceptOrder(doc.id),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text('Принять'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
