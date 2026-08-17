import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../chat/chat_screen.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/driver_location_marker_layer.dart';
import '../../widgets/app_drawer.dart';
import '../../app_routes.dart';
import '../../services/order_cancellation_controller.dart';
import '../../services/order_workflow_service.dart';
import '../../utils/single_key_future_cache.dart';

const _useCloudFunctions = bool.fromEnvironment('USE_CLOUD_FUNCTIONS');

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final MapController _mapController = MapController();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _orderStream;

  StreamSubscription<DatabaseEvent>? _driverLocationSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _firestoreDriverLocationSub;
  final ValueNotifier<LatLng?> _driverLocationNotifier = ValueNotifier(null);
  final SingleKeyFutureCache<String, DocumentSnapshot<Map<String, dynamic>>>
  _driverProfileCache = SingleKeyFutureCache();
  late final OrderCancellationController _cancellationController;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
  _cancellationSnackBar;
  bool _isMapReady = false;
  bool _hasShownRating = false;
  bool _isReturningToMap = false;
  bool _isCancelConfirmationOpen = false;

  static const double _defaultZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots();
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

  void _listenToDriverLocation(String driverId) {
    _driverLocationSub?.cancel();
    _firestoreDriverLocationSub?.cancel();
    if (!_useCloudFunctions) {
      _firestoreDriverLocationSub = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .collection('tracking')
          .doc('current')
          .snapshots()
          .listen((snapshot) {
            final data = snapshot.data();
            if (data == null) return;
            final lat = _toDouble(data['lat'], 0.0);
            final lng = _toDouble(data['lng'], 0.0);
            if (lat != 0.0 && lng != 0.0 && mounted) {
              _driverLocationNotifier.value = LatLng(lat, lng);
            }
          });
      return;
    }
    _driverLocationSub = FirebaseDatabase.instance
        .ref('active_order_locations/${widget.orderId}/$driverId')
        .onValue
        .listen((event) {
          if (event.snapshot.exists && event.snapshot.value != null) {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            final lat = _toDouble(data['lat'], 0.0);
            final lng = _toDouble(data['lng'], 0.0);

            if (lat != 0.0 && lng != 0.0 && mounted) {
              _driverLocationNotifier.value = LatLng(lat, lng);
            }
          }
        });
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

  void _stopTrackingAndClearCancelledOrder() {
    _driverLocationSub?.cancel();
    _driverLocationSub = null;
    _firestoreDriverLocationSub?.cancel();
    _firestoreDriverLocationSub = null;
    _driverLocationNotifier.value = null;
    _driverProfileCache.clear();
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
    _driverLocationSub?.cancel();
    _firestoreDriverLocationSub?.cancel();
    _driverLocationNotifier.dispose();
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
      drawer: const AppDrawer(mode: AppMode.passenger),
      body: _isReturningToMap
          ? const Center(child: Text('Заказ отменён'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _orderStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    !snapshot.data!.exists) {
                  return const Center(
                    child: Text('Ошибка загрузки данных заказа'),
                  );
                }

                final orderData = snapshot.data!.data() ?? {};
                final status = orderData['status']?.toString() ?? 'searching';
                final driverId = orderData['driverId']?.toString();

                if (driverId != null &&
                    driverId.isNotEmpty &&
                    _driverLocationSub == null &&
                    _firestoreDriverLocationSub == null) {
                  _listenToDriverLocation(driverId);
                }

                if (status == 'completed') {
                  _handleCompletion(orderData);
                }
                if (status == 'cancelled') {
                  _handleRemoteCancellation();
                }
                if (status == 'completed' || status == 'cancelled') {
                  _driverLocationSub?.cancel();
                  _driverLocationSub = null;
                  _firestoreDriverLocationSub?.cancel();
                  _firestoreDriverLocationSub = null;
                  _driverLocationNotifier.value = null;
                }

                final double fromLat = _toDouble(orderData['fromLat'], 51.9555);
                final double fromLng = _toDouble(orderData['fromLng'], 66.4032);
                final double toLat = _toDouble(orderData['toLat'], 51.9555);
                final double toLng = _toDouble(orderData['toLng'], 66.4032);

                final LatLng passengerFrom = LatLng(fromLat, fromLng);
                final LatLng passengerTo = LatLng(toLat, toLng);

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            _driverLocationNotifier.value ?? passengerFrom,
                        initialZoom: _defaultZoom,
                        onMapReady: () {
                          _isMapReady = true;
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.tulpar_taxi',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
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
              'Поиск свободного водителя...',
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
          title: 'Водитель едет к вам',
          titleColor: Colors.blue,
          orderData: orderData,
          driverId: driverId,
        );

      case 'arrived':
        return _buildDriverCardWithFallback(
          context,
          title: 'Водитель на месте и ожидает вас!',
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
              'Поездка в процессе',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text('Направление: ${orderData['toAddress'] ?? 'Адрес не указан'}'),
          ],
        );

      case 'completed':
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 8),
            Text(
              'Поездка завершена!',
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
              'Заказ отменен',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        );

      default:
        return Text('Статус заказа: $status');
    }
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

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _driverProfileCache.get(
        driverId,
        () =>
            FirebaseFirestore.instance.collection('users').doc(driverId).get(),
      ),
      builder: (context, snapshot) {
        String? driverName = orderData['driverName']?.toString();
        String? carModel;
        String? carColor;
        String? carNumber;

        if (snapshot.hasData && snapshot.data!.exists) {
          final profile = snapshot.data!.data() ?? {};
          driverName = profile['name'] ?? profile['fullName'] ?? driverName;
          carModel = profile['carModel'] ?? profile['car'];
          carColor = profile['carColor'];
          carNumber = profile['carNumber'] ?? profile['plate'];
        }

        return _buildDriverInfoCard(
          context,
          title: title,
          titleColor: titleColor,
          orderData: orderData,
          driverName: driverName,
          carModel: carModel,
          carColor: carColor,
          carNumber: carNumber,
          isArrived: isArrived,
        );
      },
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
        driverName ?? orderData['driverName']?.toString() ?? 'Водитель';
    final finalCarModel =
        carModel ?? orderData['carModel']?.toString() ?? 'Автомобиль';
    final finalCarColor = carColor ?? orderData['carColor']?.toString() ?? '';
    final finalCarNumber =
        carNumber ?? orderData['carNumber']?.toString() ?? '';

    final String carDetails = [
      finalCarModel,
      finalCarColor,
      finalCarNumber,
    ].where((element) => element.trim().isNotEmpty).join(' • ');

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
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Пожалуйста, выходите к автомобилю',
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
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Отменить'),
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
