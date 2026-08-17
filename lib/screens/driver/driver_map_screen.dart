import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../screens/chat/chat_screen.dart';
import '../../widgets/rating_dialog.dart';
import '../../services/route_service.dart'; // Переиспользуем сервис
import '../../services/order_workflow_service.dart';
import '../../services/driver_tracking_service.dart';

class DriverMapScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const DriverMapScreen({super.key, required this.orderId, required this.orderData});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  List<LatLng> _routePoints = [];
  final DriverTrackingService _tracking = DriverTrackingService();
  String? _trackingMessage;
  StreamSubscription<Position>? _mapPositionSubscription;

  @override
  void initState() {
    super.initState();
    _trackDriverAndBuildRoute();
    _startTracking();
    _mapPositionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (mounted) setState(() => _driverLocation = LatLng(position.latitude, position.longitude));
    }, onError: (_) {});
  }

  Future<void> _startTracking() async {
    final result = await _tracking.startLocationUpdates(widget.orderId);
    if (mounted && !result.isStarted) {
      setState(() => _trackingMessage = result.message);
    }
  }

  @override
  void dispose() {
    _mapPositionSubscription?.cancel();
    _tracking.stopLocationUpdates(widget.orderId);
    super.dispose();
  }

  Future<void> _trackDriverAndBuildRoute() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      LatLng driverPos = LatLng(pos.latitude, pos.longitude);
      LatLng passengerFrom = LatLng(widget.orderData['fromLat'], widget.orderData['fromLng']);

      if (!mounted) return;
      setState(() => _driverLocation = driverPos);
      _mapController.move(driverPos, 14.0);

      // Исправлено: получение геометрии через единый RouteService
      final points = await RouteService.fetchRouteGeometry(
        startLat: driverPos.latitude,
        startLng: driverPos.longitude,
        destLat: passengerFrom.latitude,
        destLng: passengerFrom.longitude,
      );

      if (mounted) {
        setState(() {
          _routePoints = points;
        });
      }
    } catch (e) {
      debugPrint('Ошибка получения маршрута: $e');
    }
  }

  Future<void> _advanceOrder(String currentStatus) async {
    final nextStatus = {
      'accepted': 'arrived',
      'arrived': 'in_progress',
      'in_progress': 'completed',
    }[currentStatus];
    if (nextStatus == null) return;

    try {
      await OrderWorkflowService().transitionOrderStatus(
        orderId: widget.orderId,
        nextStatus: nextStatus,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (nextStatus == 'completed') {
      await _tracking.stopLocationUpdates(widget.orderId);
    }

    if (mounted && nextStatus == 'completed') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => RatingDialog(
          targetUserId: widget.orderData['passengerId'],
          orderId: widget.orderId,
          isRatingDriver: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.orderData['status']?.toString() ?? 'accepted';
    final actionLabel = {
      'accepted': 'Я на месте',
      'arrived': 'Начать поездку',
      'in_progress': 'Завершить поездку',
    }[status];
    LatLng passengerFrom = LatLng(widget.orderData['fromLat'], widget.orderData['fromLng']);
    LatLng passengerTo = LatLng(widget.orderData['toLat'], widget.orderData['toLng']);

    return Scaffold(
      appBar: AppBar(title: const Text('Выполнение заказа'), backgroundColor: Colors.green),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: passengerFrom, initialZoom: 14.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.esil_taxi',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [Polyline(points: _routePoints, color: Colors.green, strokeWidth: 5)]),
              MarkerLayer(markers: [
                if (_driverLocation != null)
                  Marker(point: _driverLocation!, child: const Icon(Icons.navigation, color: Colors.blue, size: 40)),
                Marker(point: passengerFrom, child: const Icon(Icons.person_pin_circle, color: Colors.green, size: 45)),
                Marker(point: passengerTo, child: const Icon(Icons.flag, color: Colors.red, size: 40)),
              ]),
            ],
          ),
          Positioned(
            bottom: 20, left: 15, right: 15,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_trackingMessage != null)
                      Text(
                        _trackingMessage!,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    Text('Клиент ожидает: ${widget.orderData['fromAddress']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.chat),
                            label: const Text('Чат'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChatScreen(orderId: widget.orderId, peerName: 'Пассажир')),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (actionLabel != null)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: status == 'in_progress'
                                    ? Colors.red
                                    : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _advanceOrder(status),
                              child: Text(actionLabel),
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
