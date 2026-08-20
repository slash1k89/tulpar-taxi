import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../chat/chat_screen.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/driver_location_marker_layer.dart';
import '../../widgets/app_drawer.dart';
import '../../app_routes.dart';
import '../../services/order_cancellation_controller.dart';
import '../../services/order_route_geometry_cache.dart';
import '../../services/order_offer_service.dart';
import '../../services/order_workflow_service.dart';
import '../../services/tulpar_api_client.dart';
import '../../widgets/order_route_polyline_layer.dart';

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
  });

  final Map<String, dynamic>? initialOrderData;
  final Stream<Map<String, dynamic>?>? orderDataStream;
  final OrderRouteLoader? routeLoader;
  final ValueNotifier<LatLng?>? driverLocationListenable;
  final Stream<List<DriverOffer>>? offersStream;
  final bool showMapTiles;

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
  String? _acceptingOfferDriverId;
  List<LatLng>? _routePendingFit;

  static const double _defaultZoom = 15.0;

  OrderOfferService get _offerService =>
      _offerServiceInstance ??= OrderOfferService();

  @override
  void initState() {
    super.initState();
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
        debugPrint('?????? ???????? ???????? ?????? ${widget.orderId}: $error');
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
        debugPrint("?????? ??????????? ?????: $e");
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
            '${offer.driverName}: ??????????? ${offer.price} ? ???????.',
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
        action: SnackBarAction(label: '???????', onPressed: () {}),
      ),
    );
    return _cancellationSnackBar!.closed.then<void>((_) {});
  }

  void _showCancellationError(Object error, StackTrace stackTrace) {
    debugPrint('?????? ?????? ?????? ${widget.orderId}: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (!mounted || _cancellationController.hasHandledCancellation) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '?? ??????? ???????? ?????. ????????? ?????????? ? ????????? ???????.',
        ),
      ),
    );
  }

  void _returnToCleanMap() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.map, (route) => false);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => RatingDialog(
            targetUserId: orderData['driverId']?.toString() ?? '',
            orderId: widget.orderId,
            isRatingDriver: true,
          ),
        );
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
        title: const Text('??? ?????'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
      drawer: const AppDrawer(mode: AppMode.passenger),
      body: _isReturningToMap
          ? const Center(child: Text('????? ???????'))
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
                    child: Text('?????? ???????? ?????? ??????'),
                  );
                }

                final orderData = snapshot.data;
                if (orderData == null) {
                  return const Center(
                    child: Text('?????? ???????? ?????? ??????'),
                  );
                }
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
                    child: Text('???????????? ?????????? ??????'),
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
                        onMapReady: () {
                          _isMapReady = true;
                          _fitRouteOnceIfReady();
                        },
                      ),
                      children: [
                        if (widget.showMapTiles)
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.tulpar_taxi',
                          ),
                        OrderRoutePolylineLayer(
                          routeFuture: routeFuture,
                          onRouteReady: _rememberRouteForFit,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              key: const Key('order_route_start_marker'),
                              point: passengerFrom,
                              width: 45,
                              height: 45,
                              child: const Icon(
                                Icons.person_pin_circle,
                                color: Colors.green,
                                size: 45,
                              ),
                            ),
                            Marker(
                              key: const Key('order_route_destination_marker'),
                              point: passengerTo,
                              width: 45,
                              height: 45,
                              child: const Icon(
                                Icons.flag,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                        DriverLocationMarkerLayer(
                          positionListenable: _driverLocationNotifier,
                          marker: const Icon(
                            Icons.local_taxi,
                            color: Colors.amber,
                            size: 40,
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
                          child: _buildStatusWidget(
                            context,
                            status,
                            orderData,
                            driverId,
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
    switch (status) {
      case 'searching':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.amber),
            const SizedBox(height: 12),
            const Text(
              '????? ?????????? ????????...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      ? '??????...'
                      : '???????? ?????',
                ),
              ),
            ),
          ],
        );

      case 'accepted':
        return _buildDriverCardWithFallback(
          context,
          title: '???????? ???? ? ???',
          titleColor: Colors.blue,
          orderData: orderData,
          driverId: driverId,
        );

      case 'driver_arrived':
      case 'arrived':
        return _buildDriverCardWithFallback(
          context,
          title: '???????? ?? ????? ? ??????? ???!',
          titleColor: Colors.green,
          orderData: orderData,
          driverId: driverId,
          isArrived: true,
        );

      case 'in_progress':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car, color: Colors.green, size: 40),
            const SizedBox(height: 8),
            const Text(
              '??????? ? ????????',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text('???????????: ${orderData['toAddress'] ?? '????? ?? ??????'}'),
          ],
        );

      case 'completed':
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 8),
            Text(
              '??????? ?????????!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              '????? ???????',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        );

      default:
        return Text('?????? ??????: $status');
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
  }) {
    final finalDriverName =
        driverName ?? orderData['driverName']?.toString() ?? '????????';
    final finalCarModel =
        carModel ?? orderData['carModel']?.toString() ?? '??????????';
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
        if (isArrived) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '??????????, ???????? ? ??????????',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const Divider(height: 20),
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
                        ? '?????? ?????? ???????????...'
                        : carDetails,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat),
                label: const Text('???'),
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
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('????????'),
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
        ),
      ],
    );
  }
}
