import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/chat_screen.dart';
import '../../services/order_workflow_service.dart';
import '../../services/driver_tracking_service.dart';

class DriverOrderScreen extends StatefulWidget {
  final String orderId;

  const DriverOrderScreen({super.key, required this.orderId});

  @override
  State<DriverOrderScreen> createState() => _DriverOrderScreenState();
}

class _DriverOrderScreenState extends State<DriverOrderScreen> {
  bool _isUpdating = false;
  final DriverTrackingService _tracking = DriverTrackingService();
  String? _trackingMessage;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    final result = await _tracking.startLocationUpdates(widget.orderId);
    if (mounted && !result.isStarted) {
      setState(() => _trackingMessage = result.message);
    }
  }

  @override
  void dispose() {
    _tracking.stopLocationUpdates(widget.orderId);
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await OrderWorkflowService().transitionOrderStatus(
        orderId: widget.orderId,
        nextStatus: newStatus,
      );
      if (newStatus == 'completed') {
        await _tracking.stopLocationUpdates(widget.orderId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления статуса: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(
              child: Text('Заказ не найден', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final status = data['status'] ?? 'accepted';

        String statusTitle = 'Едем к клиенту';
        String buttonText = 'На месте';
        String nextStatus = 'arrived';
        Color buttonColor = Colors.amber;

        if (status == 'arrived') {
          statusTitle = 'Ожидание клиента';
          buttonText = 'Начать поездку';
          nextStatus = 'in_progress';
          buttonColor = Colors.green;
        } else if (status == 'in_progress') {
          statusTitle = 'Поездка в процессе';
          buttonText = 'Завершить поездку';
          nextStatus = 'completed';
          buttonColor = Colors.redAccent;
        }

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            title: Text(statusTitle),
            backgroundColor: const Color(0xFF1E1E1E),
            foregroundColor: Colors.amber,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        orderId: widget.orderId,
                        peerName: data['passengerName'] ?? 'Пассажир',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_trackingMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _trackingMessage!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                Card(
                  color: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Пассажир: ${data['passengerName'] ?? 'Пассажир'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if ((data['passengerPhone'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Тел: ${data['passengerPhone']}',
                            style: const TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                        ],
                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          children: [
                            const Icon(Icons.my_location, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Откуда: ${data['fromAddress'] ?? ''}',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Куда: ${data['toAddress'] ?? ''}',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Стоимость:',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            Text(
                              '${data['price'] ?? 500} ₸',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : () => _updateStatus(nextStatus),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isUpdating
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            buttonText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
