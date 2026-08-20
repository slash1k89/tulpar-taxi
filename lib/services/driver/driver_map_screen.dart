import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../order_workflow_service.dart';
import '../../screens/chat/chat_screen.dart';
import '../../widgets/rating_dialog.dart';

class DriverMapScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const DriverMapScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _trackDriverAndBuildRoute();
  }

  Future<void> _trackDriverAndBuildRoute() async {
    Position pos = await Geolocator.getCurrentPosition();
    LatLng driverPos = LatLng(pos.latitude, pos.longitude);
    LatLng passengerFrom = LatLng(
      widget.orderData['fromLat'],
      widget.orderData['fromLng'],
    );

    setState(() => _driverLocation = driverPos);
    _mapController.move(driverPos, 14.0);

    // Маршрут: Водитель -> Точка забора пассажира
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/${driverPos.longitude},${driverPos.latitude};${passengerFrom.longitude},${passengerFrom.latitude}?geometries=geojson',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        setState(() {
          _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
        });
      }
    } catch (_) {}
  }

  void _completeOrder() async {
    await OrderWorkflowService().transitionOrderStatus(
      orderId: widget.orderId,
      nextStatus: 'completed',
    );

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => RatingDialog(
          targetUserId: widget.orderData['passengerId'],
          orderId: widget.orderId,
          isRatingDriver: false, // Водитель оценивает пассажира
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng passengerFrom = LatLng(
      widget.orderData['fromLat'],
      widget.orderData['fromLng'],
    );
    LatLng passengerTo = LatLng(
      widget.orderData['toLat'],
      widget.orderData['toLng'],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выполнение заказа'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: passengerFrom,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.esil_taxi',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.green,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_driverLocation != null)
                    Marker(
                      point: _driverLocation!,
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  Marker(
                    point: passengerFrom,
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: Colors.green,
                      size: 45,
                    ),
                  ),
                  Marker(
                    point: passengerTo,
                    child: const Icon(Icons.flag, color: Colors.red, size: 40),
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Клиент ожидает: ${widget.orderData['fromAddress']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.chat),
                            label: const Text('Чат'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  orderId: widget.orderId,
                                  peerName: 'Пассажир',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _completeOrder,
                            child: const Text('Завершить'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
