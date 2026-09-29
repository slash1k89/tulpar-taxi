import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:latlong2/latlong.dart';

import '../../models/order_service_type.dart';
import '../../models/city.dart';
import '../../l10n/generated/app_localizations.dart';
import '../chat/chat_screen.dart';
import '../../widgets/chat_unread_badge.dart';
import '../../widgets/order_stops_view.dart';
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
import '../../widgets/city_selection_modal.dart';
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
    this.initialWorkCity,
    this.workCityUpdater,
    this.workCitiesLoader,
  });

  final OrderServiceType serviceType;
  final String? userId;
  final Stream<Map<String, dynamic>?>? activeOrdersStream;
  final Stream<List<Map<String, dynamic>>>? availableOrdersStream;
  final Widget Function(Map<String, dynamic> order)? activeOrderBuilder;
  final OrderOfferService? orderOfferService;
  final Future<List<Map<String, dynamic>>> Function()? availableOrdersLoader;
  final Future<Map<String, dynamic>?> Function()? activeOrderLoader;
  final City? initialWorkCity;
  final Future<String> Function(String cityId)? workCityUpdater;
  final Future<List<City>> Function()? workCitiesLoader;

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
  City? _workCity;
  bool _isUpdatingWorkCity = false;
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
    _workCity = widget.initialWorkCity;
    WidgetsBinding.instance.addObserver(this);
    _appIsActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _newOrderTracker.setActive(_appIsActive);
    _initializeOrderStreams();
    if (_workCity == null &&
        !widget.serviceType.isIntercity &&
        widget.availableOrdersLoader == null &&
        widget.availableOrdersStream == null) {
      unawaited(_loadWorkCity());
    }
  }

  Future<void> _loadWorkCity() async {
    final api = TulparApiClient();
    try {
      final profile = await api.getCurrentDriverProfile();
      if (!mounted) return;
      final cityId = profile?['workCityId']?.toString();
      setState(
        () => _workCity = availableCities
            .where((city) => city.id == cityId)
            .firstOrNull,
      );
    } catch (_) {
      // The order list independently reports its own server error.
    } finally {
      api.close();
    }
  }

  Future<void> _chooseWorkCity() async {
    if (_isUpdatingWorkCity || _workCity == null) return;
    final chosen = await showCitySelectionModal(
      context,
      currentCityId: _workCity!.id,
      citiesLoader: widget.workCitiesLoader,
    );
    if (chosen == null || chosen.id == _workCity!.id || !mounted) return;
    setState(() => _isUpdatingWorkCity = true);
    try {
      await (widget.workCityUpdater?.call(chosen.id) ??
          _api.updateDriverWorkCity(chosen.id));
      if (!mounted) return;
      _availableOrders.dispose();
      _availableOrders = _createAvailableOrdersPoll();
      setState(() {
        _workCity = chosen;
        _isOnline = false;
      });
      _newOrderTracker.reset();
      _syncPollingLifecycle();
      await _availableOrders.refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).driverWorkCityChangeFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingWorkCity = false);
    }
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
        ).showSnackBar(SnackBar(content: Text(_messageForLoadError(error))));
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
    final l10n = AppLocalizations.of(context);
    final message = newTypes
        .map(
          (type) =>
              l10n.driverNewOrder(type.localizedTitle(l10n).toUpperCase()),
        )
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
    final l10n = AppLocalizations.of(context);

    try {
      await OrderWorkflowService().acceptOrder(orderId);

      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (serviceType) {
            OrderServiceType.delivery => l10n.driverAcceptDelivery,
            OrderServiceType.intercity => l10n.driverAcceptIntercity,
            OrderServiceType.city => l10n.driverAcceptCity,
          }),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.driverAcceptFailed)));
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
                ? AppLocalizations.of(dialogContext).driverProposePrice
                : AppLocalizations.of(dialogContext).driverChangeOffer,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(
                    dialogContext,
                  ).driverPassengerPrice(passengerPrice),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: enteredPrice,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(
                      dialogContext,
                    ).driverYourPrice,
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
              child: Text(AppLocalizations.of(dialogContext).cancel),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(enteredPrice.trim());

                if (value == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(
                          dialogContext,
                        ).driverEnterWholeAmount,
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
                } on OrderOfferException {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        value <= passengerPrice
                            ? AppLocalizations.of(
                                dialogContext,
                              ).driverOfferAbovePrice
                            : AppLocalizations.of(
                                dialogContext,
                              ).driverOfferTooHigh,
                      ),
                    ),
                  );
                }
              },
              child: Text(AppLocalizations.of(dialogContext).driverSendOffer),
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
          content: Text(AppLocalizations.of(context).driverOfferSent(price)),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).driverOfferFailed)),
      );
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
      return Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context).driverNotAuthenticated),
        ),
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
              ? widget.serviceType.localizedDriverSectionTitle(
                  AppLocalizations.of(context),
                )
              : AppLocalizations.of(context).taxiAndDelivery,
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.amber,
        actions: [
          if (!widget.serviceType.isIntercity)
            TextButton.icon(
              key: const Key('driver_work_city_selector'),
              onPressed: _workCity == null || _isUpdatingWorkCity || _isOnline
                  ? null
                  : _chooseWorkCity,
              icon: const Icon(Icons.location_city),
              label: Text(
                _workCity?.localizedName(
                      Localizations.localeOf(context).languageCode,
                    ) ??
                    AppLocalizations.of(context).driverWorkCity,
              ),
            ),
          Row(
            children: [
              Text(AppLocalizations.of(context).driverOnline),
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
              content: Text(
                AppLocalizations.of(context).driverActiveCheckFailed,
              ),
              actions: [
                TextButton(
                  onPressed: _retryActiveOrders,
                  child: Text(AppLocalizations.of(context).retry),
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
                  child: Text(AppLocalizations.of(context).retry),
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
                  return Center(
                    child: Text(
                      AppLocalizations.of(context).driverNoOrders,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
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
                                OrderServiceType.fromValue(data['serviceType'])
                                    .localizedTitle(
                                      AppLocalizations.of(context),
                                    )
                                    .toUpperCase(),
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
                                  data['passengerName'] ??
                                      AppLocalizations.of(context).passenger,
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
                            OrderStopsView(
                              orderData: data,
                              textColor: Colors.white70,
                            ),
                            if (DeliveryDetailsView.isDelivery(data)) ...[
                              const SizedBox(height: 12),
                              DeliveryDetailsView(
                                orderData: data,
                                onDarkCard: true,
                              ),
                            ],
                            if (IntercityDetailsView.isIntercity(data)) ...[
                              const SizedBox(height: 12),
                              IntercityDetailsView(
                                orderData: data,
                                showRouteAndPrice: false,
                                onDarkCard: true,
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
                                  AppLocalizations.of(
                                    context,
                                  ).distanceKilometers(
                                    distanceKm.toStringAsFixed(1),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (distanceKm > 0) ...[
                                  const Spacer(),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    ).pricePerKilometer(
                                      (passengerPrice / distanceKm).round(),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white70,
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
                                  AppLocalizations.of(context).passenger,
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
                AppLocalizations.of(
                  context,
                ).driverYouOffered(pendingOffer.price),
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
                  tooltip: AppLocalizations.of(context).chat,
                  color: Colors.white,
                  icon: ChatUnreadBadge(orderId: orderId),
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
                        ? AppLocalizations.of(context).driverProposePrice
                        : AppLocalizations.of(context).driverChangePrice,
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
                  child: Text(
                    AppLocalizations.of(
                      context,
                    ).driverAcceptForPrice(passengerPrice),
                  ),
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
      FirebaseException(code: 'permission-denied') => AppLocalizations.of(
        context,
      ).driverOrdersForbidden,
      FirebaseException(code: 'failed-precondition') => AppLocalizations.of(
        context,
      ).driverOrdersConfigFailed,
      TimeoutException() => AppLocalizations.of(context).driverOrdersTimeout,
      _ => AppLocalizations.of(context).driverOrdersLoadFailed,
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
