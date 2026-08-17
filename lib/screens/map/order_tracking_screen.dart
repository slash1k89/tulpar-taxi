import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../chat/chat_screen.dart';
import '../../widgets/rating_dialog.dart';
import '../../services/order_workflow_service.dart';

const _useCloudFunctions = bool.fromEnvironment('USE_CLOUD_FUNCTIONS');

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final MapController _mapController = MapController();

  StreamSubscription<DatabaseEvent>? _driverLocationSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _firestoreDriverLocationSub;
  LatLng? _driverLocation;
  bool _isMapReady = false;
  bool _hasShownRating = false;

  static const double _defaultZoom = 15.0;

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
          setState(() => _driverLocation = LatLng(lat, lng));
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
          setState(() {
            _driverLocation = LatLng(lat, lng);
          });
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
    try {
      await OrderWorkflowService().cancelOrder(widget.orderId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отмены заказа: $e')),
        );
      }
    }
  }

  Future<void> _confirmCancelOrder(BuildContext context) async {
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

    if (confirm == true) {
      _cancelOrder();
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
    _driverLocationSub?.cancel();
    _firestoreDriverLocationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ваш заказ'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Ошибка загрузки данных заказа'));
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final status = orderData['status']?.toString() ?? 'searching';
          final driverId = orderData['driverId']?.toString();

          if (driverId != null && driverId.isNotEmpty &&
              _driverLocationSub == null && _firestoreDriverLocationSub == null) {
            _listenToDriverLocation(driverId);
          }

          if (status == 'completed') {
            _handleCompletion(orderData);
          }
          if (status == 'completed' || status == 'cancelled') {
            _driverLocationSub?.cancel();
            _driverLocationSub = null;
            _firestoreDriverLocationSub?.cancel();
            _firestoreDriverLocationSub = null;
            _driverLocation = null;
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
                  initialCenter: _driverLocation ?? passengerFrom,
                  initialZoom: _defaultZoom,
                  onMapReady: () {
                    _isMapReady = true;
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.tulpar_taxi',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: passengerFrom,
                        width: 45,
                        height: 45,
                        child: const Icon(Icons.person_pin_circle, color: Colors.green, size: 45),
                      ),
                      Marker(
                        point: passengerTo,
                        width: 45,
                        height: 45,
                        child: const Icon(Icons.flag, color: Colors.red, size: 40),
                      ),
                      if (_driverLocation != null)
                        Marker(
                          point: _driverLocation!,
                          width: 45,
                          height: 45,
                          child: const Icon(Icons.local_taxi, color: Colors.amber, size: 40),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 20,
                left: 15,
                right: 15,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildStatusWidget(context, status, orderData, driverId),
                  ),
                ),
              ),
              if (_driverLocation != null)
                Positioned(
                  right: 16,
                  bottom: 250,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    mini: true,
                    onPressed: () => _safeMoveMap(_driverLocation!),
                    child: const Icon(Icons.my_location, color: Colors.amber),
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
                onPressed: _cancelOrder,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Отменить поиск'),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
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
    final hasCarDataInOrder = orderData['carModel'] != null || orderData['carNumber'] != null;

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

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(driverId).get(),
      builder: (context, snapshot) {
        String? driverName = orderData['driverName']?.toString();
        String? carModel;
        String? carColor;
        String? carNumber;

        if (snapshot.hasData && snapshot.data!.exists) {
          final profile = snapshot.data!.data() as Map<String, dynamic>? ?? {};
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
    final finalDriverName = driverName ?? orderData['driverName']?.toString() ?? 'Водитель';
    final finalCarModel = carModel ?? orderData['carModel']?.toString() ?? 'Автомобиль';
    final finalCarColor = carColor ?? orderData['carColor']?.toString() ?? '';
    final finalCarNumber = carNumber ?? orderData['carNumber']?.toString() ?? '';

    final String carDetails = [finalCarModel, finalCarColor, finalCarNumber]
        .where((element) => element.trim().isNotEmpty)
        .join(' • ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.bold),
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
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    carDetails.isEmpty ? 'Данные машины загружаются...' : carDetails,
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
                onPressed: () => _confirmCancelOrder(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
