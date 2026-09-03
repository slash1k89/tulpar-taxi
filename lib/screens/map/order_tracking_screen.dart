import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/order_service_type.dart';
import '../chat/chat_screen.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/driver_location_marker_layer.dart';
import '../../widgets/app_drawer.dart';
import '../../app_routes.dart';
import '../../services/order_cancellation_controller.dart';
import '../../services/order_route_geometry_cache.dart';
import '../../services/order_offer_service.dart';
import '../../services/order_workflow_service.dart';
import '../../services/rating_service.dart';
import '../../services/tulpar_api_client.dart';
import '../../widgets/order_route_polyline_layer.dart';
import '../../widgets/delivery_details_view.dart';
import '../../widgets/intercity_details_view.dart';
import '../../widgets/tulpar_map_tile_layer.dart';
import '../../widgets/tulpar_map_visuals.dart';
import '../profile/driver_public_profile_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrderData,
    this.orderDataStream,
    this.routeLoader,
    this.driverLocationListenable,
    this.offersStream,
    this.showMapTiles = true,
    this.ratingService,
  });

  final Map<String, dynamic>? initialOrderData;
  final Stream<Map<String, dynamic>?>? orderDataStream;
  final OrderRouteLoader? routeLoader;
  final ValueNotifier<LatLng?>? driverLocationListenable;
  final Stream<List<DriverOffer>>? offersStream;
  final bool showMapTiles;
  final RatingService? ratingService;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final MapController _mapController = MapController();
  late final Stream<Map<String, dynamic>?> _orderStream;
  late final Stream<List<DriverOffer>> _offersStream;

  late final ValueNotifier<LatLng?> _driverLocationNotifier;
  late final bool _ownsDriverLocationNotifier;
  late final OrderRouteGeometryCache _routeGeometryCache;
  late final OrderCancellationController _cancellationController;
  OrderOfferService? _offerServiceInstance;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _cancellationSnackBar;
  bool _isMapReady = false;
  bool _hasShownRating = false;
  bool _isReturningToMap = false;
  bool _isCancelConfirmationOpen = false;
  bool _hasFittedRoute = false;
  bool _isOrderPanelExpanded = true;
  String? _acceptingOfferDriverId;
  List<LatLng>? _routePendingFit;
  late OrderServiceType _currentServiceType;

  static const double _defaultZoom = 15.0;

  OrderOfferService get _offerService =>
      _offerServiceInstance ??= OrderOfferService();

  @override
  void initState() {
    super.initState();
    _currentServiceType = OrderServiceType.fromValue(
      widget.initialOrderData?['serviceType'],
    );
    _orderStream =
        widget.orderDataStream ??
        TulparApiClient().watchOrderDetails(widget.orderId);
    _offersStream =
        widget.offersStream ?? _offerService.watchPendingOffers(widget.orderId);
    _driverLocationNotifier =
        widget.driverLocationListenable ?? ValueNotifier<LatLng?>(null);
    _ownsDriverLocationNotifier = widget.driverLocationListenable == null;
    _routeGeometryCache = OrderRouteGeometryCache(
      loader: widget.routeLoader,
      onFailure: (error, stackTrace) {
        debugPrint('Ошибка загрузки маршрута заказа ${widget.orderId}: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
    _cancellationController = OrderCancellationController(
      onCleanup: _stopTrackingAndClearCancelledOrder,
      onShowMessage: _showCancellationMessage,
      onNavigate: _returnToCleanMap,
      onError: _showCancellationError,
      onStateChanged: () {
        if (mounted && !_isReturningToMap) setState(() {});
      },
    );
  }

  double _toDouble(dynamic value, double fallback) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  void _updateDriverLocationFromOrder(Map<String, dynamic> orderData) {
    if (widget.driverLocationListenable != null) {
      return;
    }

    final lat = _toDouble(orderData['driverLat'], 0.0);

    final lng = _toDouble(orderData['driverLng'], 0.0);

    if (lat == 0.0 || lng == 0.0) {
      return;
    }

    final next = LatLng(lat, lng);
    final current = _driverLocationNotifier.value;

    if (current == null ||
        current.latitude != next.latitude ||
        current.longitude != next.longitude) {
      _driverLocationNotifier.value = next;
    }
  }

  void _safeMoveMap(LatLng pos) {
    if (_isMapReady && mounted) {
      try {
        _mapController.move(pos, _defaultZoom);
      } catch (e) {
        debugPrint("Ошибка перемещения карты: $e");
      }
    }
  }

  Future<void> _cancelOrder() async {
    await _cancellationController.cancel(
      () => OrderWorkflowService().cancelOrder(widget.orderId),
    );
  }

  Future<void> _confirmCancelOrder(BuildContext context) async {
    if (_isCancelConfirmationOpen || _cancellationController.isCancelling) {
      return;
    }
    _isCancelConfirmationOpen = true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отмена заказа'),
        content: const Text('Вы уверены, что хотите отменить заказ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );
    _isCancelConfirmationOpen = false;

    if (confirm == true && mounted) {
      await _cancelOrder();
    }
  }

  Future<void> _acceptDriverOffer(DriverOffer offer) async {
    if (_acceptingOfferDriverId != null) return;
    setState(() => _acceptingOfferDriverId = offer.driverId);
    try {
      await _offerService.acceptOffer(
        orderId: widget.orderId,
        driverId: offer.driverId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${offer.driverName}: предложение ${offer.price} ₸ принято.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _acceptingOfferDriverId = null);
    }
  }

  void _stopTrackingAndClearCancelledOrder() {
    _driverLocationNotifier.value = null;
    _routeGeometryCache.clear();
    _routePendingFit = null;
    _isMapReady = false;

    if (mounted && !_isReturningToMap) {
      setState(() => _isReturningToMap = true);
    }
  }

  Future<void> _showCancellationMessage(String message) {
    if (!mounted) return Future<void>.value();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    _cancellationSnackBar = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(days: 1),
        action: SnackBarAction(label: 'Закрыть', onPressed: () {}),
      ),
    );
    return _cancellationSnackBar!.closed.then<void>((_) {});
  }

  void _showCancellationError(Object error, StackTrace stackTrace) {
    debugPrint('Ошибка отмены заказа ${widget.orderId}: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (!mounted || _cancellationController.hasHandledCancellation) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Не удалось отменить заказ. Проверьте соединение и повторите попытку.',
        ),
      ),
    );
  }

  void _returnToCleanMap() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).pushNamedAndRemoveUntil(switch (_currentServiceType) {
      OrderServiceType.delivery => AppRoutes.delivery,
      OrderServiceType.intercity => AppRoutes.intercity,
      OrderServiceType.city => AppRoutes.map,
    }, (route) => false);
  }

  void _handleRemoteCancellation() {
    if (_cancellationController.hasHandledCancellation) return;
    final requestedLocally = _cancellationController.isCancelling;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cancellationController.handleObservedCancellation(
        requestedLocally: requestedLocally,
      );
    });
  }

  void _rememberRouteForFit(List<LatLng> points) {
    if (!mounted || _hasFittedRoute || points.length < 2) return;
    _routePendingFit = points;
    _fitRouteOnceIfReady();
  }

  void _fitRouteOnceIfReady() {
    final points = _routePendingFit;
    if (_hasFittedRoute || !_isMapReady || points == null) return;
    _hasFittedRoute = true;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(40, 80, 40, 280),
          maxZoom: 16,
        ),
      );
    } catch (error) {
      debugPrint('Ошибка загрузки данных водителя: $error');
    }
  }

  void _handleCompletion(Map<String, dynamic> orderData) {
    if (_hasShownRating) return;
    _hasShownRating = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final submitted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => RatingDialog(
            targetUserId: orderData['driverId']?.toString() ?? '',
            orderId: widget.orderId,
            isRatingDriver: true,
            targetLabel:
                OrderServiceType.fromValue(orderData['serviceType']).isDelivery
                ? 'курьера'
                : null,
            ratingService: widget.ratingService,
          ),
        );
        if (!mounted || submitted != true) return;
        _driverLocationNotifier.value = null;
        _routeGeometryCache.clear();
        _routePendingFit = null;
        _returnToCleanMap();
      }
    });
  }

  @override
  void dispose() {
    _cancellationController.dispose();
    _cancellationSnackBar?.close();
    if (_ownsDriverLocationNotifier) _driverLocationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ваш заказ'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
      drawer: AppDrawer(
        mode: AppMode.passenger,
        selectedServiceType: _currentServiceType,
      ),
      body: _isReturningToMap
          ? const Center(child: Text('Заказ отменён'))
          : StreamBuilder<Map<String, dynamic>?>(
              stream: _orderStream,
              initialData: widget.initialOrderData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }

                if (snapshot.hasError && !snapshot.hasData) {
                  return const Center(
                    child: Text('Ошибка загрузки данных заказа'),
                  );
                }

                final orderData = snapshot.data;
                if (orderData == null) {
                  return const Center(
                    child: Text('Ошибка загрузки данных заказа'),
                  );
                }
                _currentServiceType = OrderServiceType.fromValue(
                  orderData['serviceType'],
                );
                final status = orderData['status']?.toString() ?? 'searching';
                final driverId = orderData['driverId']?.toString();

                if (driverId != null && driverId.isNotEmpty) {
                  _updateDriverLocationFromOrder(orderData);
                }

                if (status == 'completed') {
                  _handleCompletion(orderData);
                }
                if (status == 'cancelled') {
                  _handleRemoteCancellation();
                }
                if (status == 'completed' || status == 'cancelled') {
                  _driverLocationNotifier.value = null;
                }

                final endpoints = OrderRouteEndpoints.fromOrderData(orderData);
                if (endpoints == null) {
                  return const Center(
                    child: Text('Некорректные координаты заказа'),
                  );
                }
                final passengerFrom = endpoints.start;
                final passengerTo = endpoints.destination;
                final routeFuture = _routeGeometryCache.load(endpoints);

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: passengerFrom,
                        initialZoom: _defaultZoom,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: LatLngBounds(
                            const LatLng(-90, -180),
                            const LatLng(90, 180),
                          ),
                        ),
                        onMapReady: () {
                          _isMapReady = true;
                          _fitRouteOnceIfReady();
                        },
                      ),
                      children: [
                        if (widget.showMapTiles) const TulparMapTileLayer(),
                        OrderRoutePolylineLayer(
                          routeFuture: routeFuture,
                          onRouteReady: _rememberRouteForFit,
                        ),
                        MarkerLayer(
                          markers: [
                            TulparMapVisuals.endpointMarker(
                              key: const Key('order_route_start_marker'),
                              point: passengerFrom,
                              endpoint: TulparMapEndpoint.pickup,
                            ),
                            TulparMapVisuals.endpointMarker(
                              key: const Key('order_route_destination_marker'),
                              point: passengerTo,
                              endpoint: TulparMapEndpoint.destination,
                            ),
                          ],
                        ),
                        DriverLocationMarkerLayer(
                          positionListenable: _driverLocationNotifier,
                          width: TulparMapVisuals.vehicleMarkerSize,
                          height: TulparMapVisuals.vehicleMarkerSize,
                          marker: TulparVehicleMarker(
                            key: const Key('passenger_driver_marker'),
                            isDelivery: _currentServiceType.isDelivery,
                          ),
                        ),
                      ],
                    ),
                    if (status == 'searching')
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: SafeArea(
                          bottom: false,
                          child: Material(
                            elevation: 10,
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFF1E1E1E),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _buildDriverOffers(),
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      bottom: 20,
                      left: 15,
                      right: 15,
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                key: const Key(
                                  'passenger_tracking_panel_toggle',
                                ),
                                onTap: () => setState(
                                  () => _isOrderPanelExpanded =
                                      !_isOrderPanelExpanded,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${status == 'queued' ? 'Водитель завершает предыдущую поездку' : OrderServiceType.fromValue(orderData['serviceType']).passengerAcceptedText} · ${orderData['toAddress'] ?? ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _isOrderPanelExpanded
                                          ? Icons.keyboard_arrow_down
                                          : Icons.keyboard_arrow_up,
                                    ),
                                  ],
                                ),
                              ),
                              if (_isOrderPanelExpanded) ...[
                                const SizedBox(height: 8),
                                if (DeliveryDetailsView.isDelivery(
                                  orderData,
                                )) ...[
                                  DeliveryDetailsView(orderData: orderData),
                                  const Divider(),
                                ],
                                if (IntercityDetailsView.isIntercity(
                                  orderData,
                                )) ...[
                                  IntercityDetailsView(orderData: orderData),
                                  const Divider(),
                                ],
                                _buildStatusWidget(
                                  context,
                                  status,
                                  orderData,
                                  driverId,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 250,
                      child: ValueListenableBuilder<LatLng?>(
                        valueListenable: _driverLocationNotifier,
                        builder: (context, driverLocation, child) {
                          if (driverLocation == null) {
                            return const SizedBox.shrink();
                          }
                          return FloatingActionButton(
                            backgroundColor: Colors.white,
                            mini: true,
                            onPressed: () => _safeMoveMap(driverLocation),
                            child: child,
                          );
                        },
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildStatusWidget(
    BuildContext context,
    String status,
    Map<String, dynamic> orderData,
    String? driverId,
  ) {
    final serviceType = OrderServiceType.fromValue(orderData['serviceType']);
    switch (status) {
      case 'searching':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.amber),
            const SizedBox(height: 12),
            Text(
              serviceType.passengerSearchingText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancellationController.isCancelling
                    ? null
                    : () => _confirmCancelOrder(context),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: Text(
                  _cancellationController.isCancelling
                      ? 'Отмена...'
                      : 'Отменить поиск',
                ),
              ),
            ),
          ],
        );

      case 'accepted':
        return _buildDriverCardWithFallback(
          context,
          title: serviceType.passengerAcceptedText,
          titleColor: Colors.blue,
          orderData: orderData,
          driverId: driverId,
        );

      case 'queued':
        return _buildDriverCardWithFallback(
          context,
          title: 'Водитель завершает предыдущую поездку',
          subtitle: 'После завершения водитель сразу направится к вам.',
          titleColor: Colors.blue,
          orderData: orderData,
          driverId: driverId,
          cancelLabel: 'Отменить заказ',
          showOwnOrderSummary: true,
        );

      case 'driver_arrived':
      case 'arrived':
        return _buildDriverCardWithFallback(
          context,
          title: serviceType.passengerArrivedText,
          titleColor: Colors.green,
          orderData: orderData,
          driverId: driverId,
          isArrived: true,
        );

      case 'in_progress':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              serviceType.isDelivery
                  ? Icons.local_shipping
                  : Icons.directions_car,
              color: Colors.green,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              serviceType.passengerInProgressText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              serviceType.isDelivery
                  ? 'Адрес получателя: ${orderData['toAddress'] ?? 'Адрес не указан'}'
                  : 'Направление: ${orderData['toAddress'] ?? 'Адрес не указан'}',
            ),
          ],
        );

      case 'completed':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 8),
            Text(
              serviceType.passengerCompletedText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        );

      case 'cancelled':
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 48),
            SizedBox(height: 8),
            Text(
              'Заказ отменен',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        );

      default:
        return Text('Статус заказа: $status');
    }
  }

  Widget _buildDriverOffers() {
    return StreamBuilder<List<DriverOffer>>(
      stream: _offersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[OrderOffers] failed to load ${widget.orderId}: ${snapshot.error}',
          );
          return const Text(
            '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u043f\u0440\u0435\u0434\u043b\u043e\u0436\u0435\u043d\u0438\u044f \u0432\u043e\u0434\u0438\u0442\u0435\u043b\u0435\u0439.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.redAccent),
          );
        }

        final offers = snapshot.data ?? const <DriverOffer>[];
        if (offers.isEmpty) return const SizedBox.shrink();

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: offers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final offer = offers[index];
              final isAccepting = _acceptingOfferDriverId == offer.driverId;

              final vehicle = [
                offer.carModel,
                offer.carColor,
              ].where((value) => value.isNotEmpty).join(' \u00b7 ');

              final driverName = offer.driverName.trim().isEmpty
                  ? '\u0412\u043e\u0434\u0438\u0442\u0435\u043b\u044c'
                  : offer.driverName.trim();

              return Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            child: Icon(Icons.local_taxi),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        driverName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      offer.driverRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (vehicle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                if (offer.carNumber.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.pin,
                                        color: Colors.white54,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          offer.carNumber,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _acceptingOfferDriverId == null
                            ? () => _acceptDriverOffer(offer)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(46),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        child: isAccepting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '\u041f\u0440\u0438\u043d\u044f\u0442\u044c \u0437\u0430 ${offer.price} \u20b8',
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
    );
  }

  Widget _buildDriverCardWithFallback(
    BuildContext context, {
    required String title,
    required Color titleColor,
    required Map<String, dynamic> orderData,
    required String? driverId,
    bool isArrived = false,
    String? subtitle,
    bool showCancel = true,
    String cancelLabel = 'Отменить',
    bool showOwnOrderSummary = false,
  }) {
    final hasCarDataInOrder =
        orderData['carModel'] != null || orderData['carNumber'] != null;

    if (hasCarDataInOrder || driverId == null || driverId.isEmpty) {
      return _buildDriverInfoCard(
        context,
        title: title,
        titleColor: titleColor,
        orderData: orderData,
        driverName: orderData['driverName']?.toString(),
        carModel: orderData['carModel']?.toString(),
        carColor: orderData['carColor']?.toString(),
        carNumber: orderData['carNumber']?.toString(),
        isArrived: isArrived,
        subtitle: subtitle,
        showCancel: showCancel,
        cancelLabel: cancelLabel,
        showOwnOrderSummary: showOwnOrderSummary,
      );
    }

    return _buildDriverInfoCard(
      context,
      title: title,
      titleColor: titleColor,
      orderData: orderData,
      driverName: orderData['driverName']?.toString(),
      carModel: orderData['carModel']?.toString(),
      carColor: orderData['carColor']?.toString(),
      carNumber: orderData['carNumber']?.toString(),
      isArrived: isArrived,
      subtitle: subtitle,
      showCancel: showCancel,
      cancelLabel: cancelLabel,
      showOwnOrderSummary: showOwnOrderSummary,
    );
  }

  Widget _buildDriverInfoCard(
    BuildContext context, {
    required String title,
    required Color titleColor,
    required Map<String, dynamic> orderData,
    String? driverName,
    String? carModel,
    String? carColor,
    String? carNumber,
    bool isArrived = false,
    String? subtitle,
    bool showCancel = true,
    String cancelLabel = 'Отменить',
    bool showOwnOrderSummary = false,
  }) {
    final serviceType = OrderServiceType.fromValue(orderData['serviceType']);
    final finalDriverName =
        driverName ??
        orderData['driverName']?.toString() ??
        (serviceType.isDelivery ? 'Курьер' : 'Водитель');
    final finalCarModel =
        carModel ?? orderData['carModel']?.toString() ?? 'Автомобиль';
    final finalCarColor = carColor ?? orderData['carColor']?.toString() ?? '';
    final finalCarNumber =
        carNumber ?? orderData['carNumber']?.toString() ?? '';

    final String carDetails = [
      finalCarModel,
      finalCarColor,
      finalCarNumber,
    ].where((element) => element.trim().isNotEmpty).join(' ? ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center),
        ],
        if (isArrived) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              serviceType.passengerArrivedHint,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const Divider(height: 20),
        if (showOwnOrderSummary) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Откуда: ${orderData['fromAddress'] ?? ''}'),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Куда: ${orderData['toAddress'] ?? ''}'),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Стоимость: ${orderData['agreedPrice'] ?? orderData['price'] ?? orderData['passengerPrice'] ?? ''} ₸',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 20),
        ],
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.amber,
              child: Icon(Icons.person, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    finalDriverName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    carDetails.isEmpty
                        ? 'Данные машины загружаются...'
                        : carDetails,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (orderData['driverId']?.toString().isNotEmpty == true &&
            const {
              'accepted',
              'driver_arrived',
              'arrived',
              'in_progress',
              'completed',
              'queued',
            }.contains(orderData['status']))
          TextButton.icon(
            key: const Key('assigned_driver_profile'),
            icon: const Icon(Icons.person_outline),
            label: const Text('Профиль водителя'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    DriverPublicProfileScreen(orderId: widget.orderId),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat),
                label: const Text('Чат'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        orderId: widget.orderId,
                        peerName: finalDriverName,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (showCancel) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(cancelLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: _cancellationController.isCancelling
                      ? null
                      : () => _confirmCancelOrder(context),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
