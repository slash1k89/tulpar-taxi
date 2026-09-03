import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:latlong2/latlong.dart';

import '../../models/order_service_type.dart';
import '../chat/chat_screen.dart';
import 'driver_map_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../services/order_offer_service.dart';
import '../../services/order_price_service.dart';
import '../../services/order_workflow_service.dart';
import '../../services/tulpar_api_client.dart';
import '../../services/new_order_arrival_tracker.dart';
import '../../services/navigation_audio_service.dart';
import '../../services/navigation_voice_service.dart';
import '../../utils/restartable_stream.dart';
import '../../widgets/delivery_details_view.dart';
import '../../widgets/intercity_details_view.dart';
import '../../services/app_identity_service.dart';
import '../../services/driver_orders_poll_controller.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({
    super.key,
    this.serviceType = OrderServiceType.city,
    this.userId,
    this.activeOrdersStream,
    this.availableOrdersStream,
    this.activeOrderBuilder,
    this.orderOfferService,
    this.availableOrdersLoader,
    this.activeOrderLoader,
  });

  final OrderServiceType serviceType;
  final String? userId;
  final Stream<Map<String, dynamic>?>? activeOrdersStream;
  final Stream<List<Map<String, dynamic>>>? availableOrdersStream;
  final Widget Function(Map<String, dynamic> order)? activeOrderBuilder;
  final OrderOfferService? orderOfferService;
  final Future<List<Map<String, dynamic>>> Function()? availableOrdersLoader;
  final Future<Map<String, dynamic>?> Function()? activeOrderLoader;

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen>
    with WidgetsBindingObserver {
  late final String _currentUserId;
  OrderOfferService? _offerServiceInstance;
  final Map<String, Stream<DriverOffer?>> _ownOfferStreams = {};
  bool _isOnline = false;
  bool _isUpdatingAvailability = false;
  late DriverOrdersPollController<Map<String, dynamic>?> _activeOrders;
  late DriverOrdersPollController<List<Map<String, dynamic>>> _availableOrders;
  TulparApiClient? _ordersApi;
  bool _routeIsCurrent = true;
  TulparApiClient get _api => _ordersApi ??= TulparApiClient();
  final NewOrderArrivalTracker _newOrderTracker = NewOrderArrivalTracker();
  bool _appIsActive = true;
  bool _newOrderSoundScheduled = false;
  late final NavigationAudioOutput _newOrderVoice = NavigationAudioService(
    fallbackSpeaker: SystemNavigationVoiceSpeaker(),
  );

  OrderOfferService get _offerService =>
      _offerServiceInstance ??= widget.orderOfferService ?? OrderOfferService();

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.userId ?? AppIdentityService().currentUserId ?? '';
    WidgetsBinding.instance.addObserver(this);
    _appIsActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _newOrderTracker.setActive(_appIsActive);
    _initializeOrderStreams();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    _newOrderTracker.setActive(_appIsActive);
    _syncPollingLifecycle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _syncPollingLifecycle();
  }

  void _syncPollingLifecycle() {
    if (_routeIsCurrent && _appIsActive && _currentUserId.isNotEmpty) {
      _activeOrders.start();
      final status = _activeOrders.value?['status'];
      if (const {
        'accepted',
        'driver_arrived',
        'arrived',
        'in_progress',
      }.contains(status)) {
        _availableOrders.stop();
      } else {
        _availableOrders.start();
      }
    } else {
      _activeOrders.stop();
      _availableOrders.stop();
      _ordersApi?.close();
      _ordersApi = null;
    }
  }

  @override
  void didUpdateWidget(covariant DriverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceType != widget.serviceType) {
      _ownOfferStreams.clear();
      _newOrderTracker.reset();
      _availableOrders.dispose();
      _activeOrders.stop();
      _ordersApi?.close();
      _ordersApi = null;
      _availableOrders = _createAvailableOrdersPoll();
      _syncPollingLifecycle();
    }
  }

  void _initializeOrderStreams() {
    _activeOrders = DriverOrdersPollController(
      label: 'active/driver',
      load: () =>
          widget.activeOrderLoader?.call() ?? _api.getActiveDriverOrder(),
      source: widget.activeOrdersStream,
    );
    _availableOrders = _createAvailableOrdersPoll();
    _activeOrders.addListener(_syncPollingLifecycle);
  }

  DriverOrdersPollController<List<Map<String, dynamic>>>
  _createAvailableOrdersPoll() {
    final serviceType = widget.serviceType;
    return DriverOrdersPollController(
      label: 'available/${serviceType.apiValue}',
      load: () async => filterAvailableOrdersForService(
        await (widget.availableOrdersLoader?.call() ??
            _api.getAvailableOrders(
              serviceType: serviceType.isIntercity
                  ? serviceType.apiValue
                  : null,
            )),
        serviceType,
      ),
      source: widget.availableOrdersStream?.map(
        (orders) => filterAvailableOrdersForService(orders, serviceType),
      ),
    );
  }

  void _retryActiveOrders() {
    unawaited(_activeOrders.refresh());
  }

  void _retryAvailableOrders() {
    unawaited(_availableOrders.refresh());
  }

  Future<void> _setOnline(bool value) async {
    setState(() => _isUpdatingAvailability = true);
    try {
      if (value) {
        await _availableOrders.refresh();
        if (_availableOrders.error != null) throw _availableOrders.error!;
      }
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
    _activeOrders.dispose();
    _availableOrders.dispose();
    _ordersApi?.close();
    WidgetsBinding.instance.removeObserver(this);
    _newOrderTracker.dispose();
    unawaited(_newOrderVoice.dispose());
    if (_isOnline) {
      OrderWorkflowService().setDriverOnline(false);
    }
    super.dispose();
  }

  void _handleAvailableOrders(List<Map<String, dynamic>> orders) {
    final ids = orders.map((order) => order['id']?.toString() ?? '').toList();
    final shouldPlay = _newOrderTracker.process(ids);
    if (kDebugMode) {
      debugPrint(
        '[DriverOrders] ids=${ids.join(',')} '
        'voice=${shouldPlay ? 'triggered' : 'skipped'}',
      );
    }
    if (!shouldPlay || _newOrderSoundScheduled) return;
    final newTypes = orders
        .where(
          (o) => _newOrderTracker.lastNewOrderIds.contains(o['id']?.toString()),
        )
        .map((o) => OrderServiceType.fromValue(o['serviceType']))
        .toSet();
    final message = newTypes
        .map((type) => type.newDriverOrderMessage)
        .join('\n');
    _newOrderSoundScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newOrderSoundScheduled = false;
      if (!mounted || !_appIsActive) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      unawaited(_newOrderVoice.play(newOrderVoiceCue));
    });
  }

  Future<void> _acceptOrder(
    String orderId,
    OrderServiceType serviceType,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await OrderWorkflowService().acceptOrder(orderId);

      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (serviceType) {
            OrderServiceType.delivery =>
              'Доставка принята! Направляйтесь за посылкой.',
            OrderServiceType.intercity =>
              'Междугородняя поездка принята! Направляйтесь к пассажиру.',
            OrderServiceType.city => 'Заказ принят! Направляйтесь к клиенту.',
          }),
        ),
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
      () => restartableStream(() => _offerService.watchOwnOffer(orderId)),
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
    return AnimatedBuilder(
      animation: Listenable.merge([_activeOrders, _availableOrders]),
      builder: (context, _) {
        // Если есть активный заказ — переключаем на карту водителя со всеми данными заказа
        final activeOrder = _activeOrders.value;

        if (activeOrder != null) {
          final status = activeOrder['status']?.toString();

          if (status == 'accepted' ||
              status == 'driver_arrived' ||
              status == 'arrived' ||
              status == 'in_progress') {
            final orderId = activeOrder['id']?.toString() ?? '';

            if (orderId.isNotEmpty) {
              if (widget.activeOrderBuilder != null) {
                return widget.activeOrderBuilder!(activeOrder);
              }
              return DriverMapScreen(orderId: orderId, orderData: activeOrder);
            }
          }
        }

        // 2. Если активного заказа нет — показываем список поиска.
        return _buildAvailableOrdersScaffold(
          activeStreamError: _activeOrders.error,
        );
      },
    );
  }

  Widget _buildAvailableOrdersScaffold({Object? activeStreamError}) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          widget.serviceType.isIntercity
              ? widget.serviceType.driverSectionTitle
              : 'Такси и доставка',
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.amber,
        actions: [
          Row(
            children: [
              const Text('На линии'),
              Switch(
                key: const Key('driver_online_switch'),
                value: _isOnline,
                onChanged: _isUpdatingAvailability ? null : _setOnline,
              ),
            ],
          ),
        ],
      ),
      drawer: AppDrawer(
        mode: AppMode.driver,
        selectedServiceType: widget.serviceType,
      ),
      body: Column(
        children: [
          if (activeStreamError != null)
            MaterialBanner(
              key: const Key('driver_active_order_error'),
              content: const Text(
                'Не удалось проверить текущий заказ. Проверка повторяется автоматически.',
              ),
              actions: [
                TextButton(
                  onPressed: _retryActiveOrders,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          if (_availableOrders.error != null)
            MaterialBanner(
              key: const Key('driver_available_orders_error'),
              content: Text(_messageForLoadError(_availableOrders.error)),
              actions: [
                TextButton(
                  onPressed: _retryAvailableOrders,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (!_availableOrders.hasData &&
                    _availableOrders.error == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }

                if (_availableOrders.hasData) {
                  _handleAvailableOrders(_availableOrders.value!);
                }

                if (!_availableOrders.hasData ||
                    _availableOrders.value!.isEmpty) {
                  return const Center(
                    child: Text(
                      'Пока нет доступных заказов',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  );
                }

                final orders = _availableOrders.value!;

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
                            Chip(
                              label: Text(
                                OrderServiceType.fromValue(
                                  data['serviceType'],
                                ).driverOrderLabel,
                              ),
                              avatar: Icon(
                                OrderServiceType.fromValue(
                                  data['serviceType'],
                                ).icon,
                                size: 18,
                              ),
                              backgroundColor: Colors.amber,
                              labelStyle: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                            if (DeliveryDetailsView.isDelivery(data)) ...[
                              const SizedBox(height: 12),
                              DeliveryDetailsView(orderData: data),
                            ],
                            if (IntercityDetailsView.isIntercity(data)) ...[
                              const SizedBox(height: 12),
                              IntercityDetailsView(
                                orderData: data,
                                showRouteAndPrice: false,
                              ),
                            ],
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
                              serviceType: OrderServiceType.fromValue(
                                data['serviceType'],
                              ),
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
    required OrderServiceType serviceType,
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
                    pendingOffer == null ? 'Предложить цену' : 'Изменить цену',
                  ),
                ),
                ElevatedButton(
                  onPressed: passengerPrice <= 0
                      ? null
                      : () => _acceptOrder(orderId, serviceType),
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
        'Не удалось обновить доступные заказы: сервер не ответил вовремя. Повторяем автоматически.',
      _ => 'Не удалось обновить доступные заказы. Повторяем автоматически.',
    };
  }
}

List<Map<String, dynamic>> filterAvailableOrdersForService(
  Iterable<Map<String, dynamic>> orders,
  OrderServiceType serviceType,
) {
  return orders
      .where(
        (order) => serviceType.isIntercity
            ? OrderServiceType.fromValue(order['serviceType']).isIntercity
            : !OrderServiceType.fromValue(order['serviceType']).isIntercity,
      )
      .toList(growable: false);
}
