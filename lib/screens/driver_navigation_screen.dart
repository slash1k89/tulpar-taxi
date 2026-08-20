import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/navigation_step.dart';
import '../services/route_service.dart';
import '../widgets/navigation_overlay.dart';

class DriverNavigationScreen extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;

  const DriverNavigationScreen({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
  });

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  List<NavigationStep> _steps = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initRoute();
  }

  Future<void> _initRoute() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Необходимо разрешение на доступ к GPS';
            _isLoading = false;
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<NavigationStep> fetchedSteps = await RouteService.fetchSteps(
        startLat: position.latitude,
        startLng: position.longitude,
        destLat: widget.destinationLat,
        destLng: widget.destinationLng,
      );

      setState(() {
        _steps = fetchedSteps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _recalculateRoute() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Перестраиваем маршрут...'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );

      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<NavigationStep> newSteps = await RouteService.fetchSteps(
        startLat: currentPosition.latitude,
        startLng: currentPosition.longitude,
        destLat: widget.destinationLat,
        destLng: widget.destinationLng,
      );

      setState(() {
        _steps = newSteps;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка перерасчета: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Навигация заказа'),
        backgroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.grey[900],
            child: const Center(
              child: Text(
                'Карта отображается здесь',
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.amber)),

          if (_errorMessage.isNotEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                color: Colors.redAccent,
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),

          if (!_isLoading && _steps.isNotEmpty)
            NavigationOverlay(steps: _steps, onOffRoute: _recalculateRoute),
        ],
      ),
    );
  }
}
