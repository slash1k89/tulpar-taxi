import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import '../chat/chat_screen.dart';
import 'driver_map_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../services/order_offer_service.dart';
import '../../services/order_price_service.dart';
import '../../services/order_workflow_service.dart';
import '../../services/tulpar_api_client.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final OrderOfferService _offerService = OrderOfferService();
  final Map<String, Stream<DriverOffer?>> _ownOfferStreams = {};
  bool _isOnline = false;
  bool _isUpdatingAvailability = false;
  late Stream<Map<String, dynamic>?> _activeOrders;
  late Stream<List<Map<String, dynamic>>> _availableOrders;

  @override
  void initState() {
    super.initState();
    _initializeOrderStreams();
  }

  void _initializeOrderStreams() {
    _activeOrders = _createActiveOrdersStream();
    _availableOrders = _createAvailableOrdersStream();
  }

  Stream<Map<String, dynamic>?> _createActiveOrdersStream() {
    return _withInitialTimeout(
      TulparApiClient().watchActiveDriverOrder(),
      'Timed out while loading active driver order.',
    );
  }

  Stream<List<Map<String, dynamic>>> _createAvailableOrdersStream() {
    return _withInitialTimeout(
      TulparApiClient().watchAvailableOrders(),
      'Timed out while loading available driver orders.',
    );
  }

  Stream<T> _withInitialTimeout<T>(Stream<T> source, String message) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Timer? initialTimer;

    controller = StreamController<T>(
      onListen: () {
        initialTimer = Timer(const Duration(seconds: 12), () async {
          if (controller.isClosed) return;
          controller.addError(TimeoutException(message));
          await subscription?.cancel();
          if (!controller.isClosed) await controller.close();
        });
        subscription = source.listen(
          (event) {
            initialTimer?.cancel();
            if (!controller.isClosed) controller.add(event);
          },
          onError: (Object error, StackTrace stackTrace) {
            initialTimer?.cancel();
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
          onDone: () async {
            initialTimer?.cancel();
            if (!controller.isClosed) await controller.close();
          },
        );
      },
      onCancel: () async {
        initialTimer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  void _retryActiveOrders() {
    setState(() => _activeOrders = _createActiveOrdersStream());
  }

  void _retryAvailableOrders() {
    setState(() => _availableOrders = _createAvailableOrdersStream());
  }

  Future<void> _setOnline(bool value) async {
    setState(() => _isUpdatingAvailability = true);
    try {
      await OrderWorkflowService().setDriverOnline(value);
      if (mounted) setState(() => _isOnline = value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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

  Future<void> _showOfferDialog({
    required String orderId,
    required int passengerPrice,
    DriverOffer? existingOffer,
  }) async {
    var enteredPrice = (existingOffer?.price ?? passengerPrice + 100)
        .toString();

    final price = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            existingOffer == null
                ? '\u041f\u0440\u0435\u0434\u043b\u043e\u0436\u0438\u0442\u044c \u0446\u0435\u043d\u0443'
                : '\u0418\u0437\u043c\u0435\u043d\u0438\u0442\u044c \u043f\u0440\u0435\u0434\u043b\u043e\u0436\u0435\u043d\u0438\u0435',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u0426\u0435\u043d\u0430 \u043f\u0430\u0441\u0441\u0430\u0436\u0438\u0440\u0430: $passengerPrice \u20b8',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: enteredPrice,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText:
                        '\u0412\u0430\u0448\u0430 \u0446\u0435\u043d\u0430, \u20b8',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    enteredPrice = value;
                  },
                  onFieldSubmitted: (value) {
                    enteredPrice = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('\u041e\u0442\u043c\u0435\u043d\u0430'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(enteredPrice.trim());

                if (value == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u0446\u0435\u043b\u0443\u044e \u0441\u0443\u043c\u043c\u0443.',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  OrderOfferService.validateOfferPrice(
                    value,
                    passengerPrice: passengerPrice,
                  );
                  Navigator.pop(dialogContext, value);
                } on OrderOfferException catch (error) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                }
              },
              child: const Text(
                '\u041e\u0442\u043f\u0440\u0430\u0432\u0438\u0442\u044c',
              ),
            ),
          ],
        );
      },
    );

    if (price == null || !mounted) return;

    try {
      await _offerService.submitOffer(orderId: orderId, price: price);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u041f\u0440\u0435\u0434\u043b\u043e\u0436\u0435\u043d\u0438\u0435 $price \u20b8 \u043e\u0442\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u043e \u043f\u0430\u0441\u0441\u0430\u0436\u0438\u0440\u0443.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  double _calculateDistance(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) {
    if (fromLat == 0 || toLat == 0) return 0.0;
    final meters = const Distance().as(
      LengthUnit.Meter,
      LatLng(fromLat, fromLng),
      LatLng(toLat, toLng),
    );
    return meters / 1000;
  }

  Stream<DriverOffer?> _ownOfferStream(String orderId) {
    return _ownOfferStreams.putIfAbsent(
      orderId,
      () => _offerService.watchOwnOffer(orderId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Ошибка: Водитель не авторизован')),
      );
    }

    // 1. Автоматический вывод активного заказа для водителя
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _activeOrders,
      builder: (context, activeSnapshot) {
        if (activeSnapshot.hasError) {
          debugPrint(
            '[DriverOrders] active-order stream failed: '
            '${activeSnapshot.error}',
          );
          return _buildAvailableOrdersScaffold(
            activeStreamError: activeSnapshot.error,
          );
        }

        if (activeSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }

        // Если есть активный заказ — переключаем на карту водителя со всеми данными заказа
        final activeOrder = activeSnapshot.data;

        if (activeOrder != null) {
          final status = activeOrder['status']?.toString();

          if (status == 'accepted' ||
              status == 'driver_arrived' ||
              status == 'arrived' ||
              status == 'in_progress') {
            final orderId = activeOrder['id']?.toString() ?? '';

            if (orderId.isNotEmpty) {
              return DriverMapScreen(orderId: orderId, orderData: activeOrder);
            }
          }
        }

        // 2. Если активного заказа нет — показываем список поиска.
        return _buildAvailableOrdersScaffold();
      },
    );
  }

  Widget _buildAvailableOrdersScaffold({Object? activeStreamError}) {
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
      drawer: const AppDrawer(mode: AppMode.driver),
      body: Column(
        children: [
          if (activeStreamError != null)
            MaterialBanner(
              content: Text(_messageForLoadError(activeStreamError)),
              actions: [
                TextButton(
                  onPressed: _retryActiveOrders,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _availableOrders,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint(
                    '[DriverOrders] available-orders stream failed: '
                    '${snapshot.error}',
                  );
                  return _buildLoadError(
                    snapshot.error,
                    onRetry: _retryAvailableOrders,
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Пока нет доступных заказов',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  );
                }

                final orders = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final data = orders[index];
                    final orderId = data['id']?.toString() ?? '';
                    final passengerPrice =
                        OrderPriceService.passengerPrice(data) ?? 0;

                    final double fromLat = (data['fromLat'] ?? 0.0).toDouble();
                    final double fromLng = (data['fromLng'] ?? 0.0).toDouble();
                    final double toLat = (data['toLat'] ?? 0.0).toDouble();
                    final double toLng = (data['toLng'] ?? 0.0).toDouble();

                    final double distanceKm = _calculateDistance(
                      fromLat,
                      fromLng,
                      toLat,
                      toLng,
                    );

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                                  '$passengerPrice ₸',
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
                                const Icon(
                                  Icons.my_location,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['fromAddress'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
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
                                    data['toAddress'] ?? '',
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
                              children: [
                                const Icon(
                                  Icons.route,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} км',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (distanceKm > 0) ...[
                                  const Spacer(),
                                  Text(
                                    '${(passengerPrice / distanceKm).round()} ₸/км',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildOrderActions(
                              orderId: orderId,
                              passengerName:
                                  data['passengerName']?.toString() ??
                                  'Пассажир',
                              passengerPrice: passengerPrice,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActions({
    required String orderId,
    required String passengerName,
    required int passengerPrice,
  }) {
    return StreamBuilder<DriverOffer?>(
      stream: _ownOfferStream(orderId),
      builder: (context, snapshot) {
        final offer = snapshot.data;
        final pendingOffer = offer?.isPending == true ? offer : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pendingOffer != null) ...[
              Text(
                'Вы предложили ${pendingOffer.price} ₸',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Чат',
                  icon: const Icon(Icons.chat, color: Colors.amber),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          orderId: orderId,
                          peerName: passengerName,
                        ),
                      ),
                    );
                  },
                ),
                OutlinedButton(
                  onPressed: passengerPrice <= 0
                      ? null
                      : () => _showOfferDialog(
                          orderId: orderId,
                          passengerPrice: passengerPrice,
                          existingOffer: pendingOffer,
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                  ),
                  child: Text(
                    pendingOffer == null
                        ? 'Предложить цену'
                        : 'РР·РјРµРЅРёС‚СЊ С†РµРЅСѓ',
                  ),
                ),
                ElevatedButton(
                  onPressed: passengerPrice <= 0
                      ? null
                      : () => _acceptOrder(orderId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  child: Text('Принять за $passengerPrice ₸'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _messageForLoadError(Object? error) {
    return switch (error) {
      FirebaseException(code: 'permission-denied') =>
        'Нет доступа к заказам. Профиль водителя должен быть одобрен.',
      FirebaseException(code: 'failed-precondition') =>
        'Запрос заказов требует настройки Firestore. Проверьте технические логи.',
      TimeoutException() =>
        'Сервер не ответил за 12 секунд. Проверьте интернет и повторите попытку.',
      _ =>
        'Не удалось загрузить заказы. Проверьте интернет и повторите попытку.',
    };
  }

  Widget _buildLoadError(Object? error, {required VoidCallback onRetry}) {
    final message = _messageForLoadError(error);
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
    return content;
  }
}
