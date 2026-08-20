import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../../services/driver_tracking_service.dart';
import '../../services/order_workflow_service.dart';
import '../../services/tulpar_api_client.dart';

class DriverOrderScreen extends StatefulWidget {
  const DriverOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<DriverOrderScreen> createState() => _DriverOrderScreenState();
}

class _DriverOrderScreenState extends State<DriverOrderScreen> {
  bool _isUpdating = false;

  final DriverTrackingService _tracking = DriverTrackingService();
  final TulparApiClient _apiClient = TulparApiClient();

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
    if (_isUpdating) return;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('шибка обновления статуса: $e')));
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
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _apiClient.watchOrderDetails(widget.orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              title: const Text('аказ'),
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: Colors.amber,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'е удалось загрузить заказ.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;

        if (data == null || data.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(
              child: Text(
                'аказ не найден',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final status = data['status']?.toString() ?? 'accepted';

        String statusTitle = 'дем к клиенту';
        String buttonText = 'а месте';
        String nextStatus = 'arrived';
        Color buttonColor = Colors.amber;
        bool showStatusButton = true;

        if (status == 'arrived' || status == 'driver_arrived') {
          statusTitle = 'жидание клиента';
          buttonText = 'ачать поездку';
          nextStatus = 'in_progress';
          buttonColor = Colors.green;
        } else if (status == 'in_progress') {
          statusTitle = 'оездка в процессе';
          buttonText = 'авершить поездку';
          nextStatus = 'completed';
          buttonColor = Colors.redAccent;
        } else if (status == 'completed') {
          statusTitle = 'оездка завершена';
          showStatusButton = false;
        } else if (status == 'cancelled') {
          statusTitle = 'аказ отменён';
          showStatusButton = false;
        } else if (status == 'searching') {
          statusTitle = 'оиск водителя';
          showStatusButton = false;
        }

        final passengerName = data['passengerName']?.toString().trim() ?? '';

        final passengerPhone = data['passengerPhone']?.toString().trim() ?? '';

        final fromAddress =
            (data['fromAddress'] ?? data['pickupAddress'])?.toString().trim() ??
            '';

        final toAddress =
            (data['toAddress'] ?? data['destinationAddress'])
                ?.toString()
                .trim() ??
            '';

        final price =
            data['price'] ?? data['agreedPrice'] ?? data['passengerPrice'] ?? 0;

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
                        peerName: passengerName.isNotEmpty
                            ? passengerName
                            : 'ассажир',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ассажир: ${passengerName.isNotEmpty ? passengerName : 'ассажир'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (passengerPhone.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Тел: $passengerPhone',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          children: [
                            const Icon(
                              Icons.my_location,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ткуда: $fromAddress',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'уда: $toAddress',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
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
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '$price ₸',
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
                if (showStatusButton)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isUpdating
                          ? null
                          : () => _updateStatus(nextStatus),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isUpdating
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
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
