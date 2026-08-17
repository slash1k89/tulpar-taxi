import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TaxiApp());
}

class TaxiApp extends StatelessWidget {
  const TaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Есиль Такси',
      debugShowCheckedModeBanner: false, // Убираем красную ленточку "DEBUG"
      theme: ThemeData(
        primarySwatch: Colors.amber, // Фирменный цвет такси
        scaffoldBackgroundColor: Colors.white,
      ),
      // Теперь первым открывается экран заставки
      home: const SplashScreen(), 
    );
  }
}

// --- ЭКРАН 1: ЗАСТАВКА (Splash Screen) ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Ждем 2.5 секунды и переходим на экран входа
    Future.delayed(const Duration(milliseconds: 2500), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber, // Желтый фон
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_taxi, size: 100, color: Colors.black87),
            const SizedBox(height: 20),
            const Text(
              'ЕСИЛЬ ТАКСИ',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: Colors.black54), // Крутилка загрузки
          ],
        ),
      ),
    );
  }
}

// --- ЭКРАН 2: ВХОД / РЕГИСТРАЦИЯ ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.account_circle, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                'Вход в систему',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              // Поле для телефона
              TextField(
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone),
                  labelText: 'Номер телефона',
                  hintText: '+7 (700) 000-00-00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Поле для пароля или СМС-кода
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  labelText: 'Пароль / SMS код',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Кнопка входа
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    // Пока мы просто симулируем успешный вход и открываем карту
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MapScreen()),
                    );
                  },
                  child: const Text(
                    'Войти',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Кнопка регистрации
              TextButton(
                onPressed: () {
                  // Здесь позже сделаем отдельный экран регистрации
                },
                child: const Text('Нет аккаунта? Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ЭКРАН 3: КАРТА (Наш старый код) ---
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(text: "1500");

  LatLng? _fromPoint;
  LatLng? _toPoint;
  List<LatLng> _routePoints = [];
  bool _isSelectingFrom = true; 

  @override
  void initState() {
    super.initState();
    _getMyLocation();
  }

  Future<String> _getAddressFromLatLng(LatLng point) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1'
      );
      final response = await http.get(url, headers: {'User-Agent': 'esil_taxi_app'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['address'] != null) {
          final road = data['address']['road'] ?? '';
          final houseNumber = data['address']['house_number'] ?? '';
          
          if (road.isNotEmpty) {
            return houseNumber.isNotEmpty ? '$road, $houseNumber' : road;
          }
          return data['display_name'] ?? 'Адрес не найден';
        }
      }
    } catch (e) {
      debugPrint('Ошибка получения адреса: $e');
    }
    return "Координаты: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
  }

  Future<void> _getRoute() async {
    if (_fromPoint == null || _toPoint == null) return;
    
    setState(() => _routePoints = []);

    try {
      final url = Uri.parse(
          'http://router.project-osrm.org/route/v1/driving/${_fromPoint!.longitude},${_fromPoint!.latitude};${_toPoint!.longitude},${_toPoint!.latitude}?geometries=geojson'
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry']['coordinates'] as List;
          setState(() {
            _routePoints = geometry.map((coord) => LatLng(coord[1], coord[0])).toList();
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Ошибка построения маршрута: $e');
    }

    setState(() {
      _routePoints = [_fromPoint!, _toPoint!];
    });
  }

  Future<void> _getMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    setState(() {
      _fromController.text = "Определяем местоположение...";
    });

    Position position = await Geolocator.getCurrentPosition();
    LatLng myLoc = LatLng(position.latitude, position.longitude);
    
    setState(() {
      _fromPoint = myLoc;
      _isSelectingFrom = false; 
    });
    
    _mapController.move(myLoc, 15.0);

    String address = await _getAddressFromLatLng(myLoc);
    setState(() {
      _fromController.text = address;
    });
    
    if (_toPoint != null) {
      _getRoute();
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng tappedPoint) async {
    bool isFrom = _isSelectingFrom;

    setState(() {
      if (isFrom) {
        _fromPoint = tappedPoint;
        _fromController.text = "Загрузка адреса...";
        _isSelectingFrom = false;
      } else {
        _toPoint = tappedPoint;
        _toController.text = "Загрузка адреса...";
      }
    });

    String address = await _getAddressFromLatLng(tappedPoint);

    setState(() {
      if (isFrom) {
        _fromController.text = address;
      } else {
        _toController.text = address;
      }
    });

    if (_fromPoint != null && _toPoint != null) {
      _getRoute();
    }
  }

  void _createOrder() {
    if (_fromPoint == null || _toPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, укажите точки «Откуда» и «Куда»')),
      );
      return;
    }

    String price = _priceController.text.trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заказ создан!'),
        content: Text('Маршрут: ${_fromController.text} \n➔ ${_toController.text}\n\nЦена: $price ₸\n\nИщем водителя...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заказ такси'),
        backgroundColor: Colors.amber,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(51.9555, 66.4032),
              initialZoom: 14.0,
              onTap: _handleMapTap,
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
                      color: Colors.blue,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  if (_fromPoint != null)
                    Marker(
                      point: _fromPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                      alignment: Alignment.topCenter,
                    ),
                  if (_toPoint != null)
                    Marker(
                      point: _toPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flag, color: Colors.red, size: 40),
                      alignment: Alignment.topCenter,
                    ),
                ],
              ),
            ],
          ),

          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Card(
              color: _isSelectingFrom ? Colors.blue[100] : Colors.red[100],
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  _isSelectingFrom 
                      ? "1. Укажите точку ОТКУДА" 
                      : "2. Укажите точку КУДА",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isSelectingFrom = true),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isSelectingFrom ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isSelectingFrom ? Colors.blue : Colors.transparent),
                        ),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _fromController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.my_location, color: Colors.blue),
                              labelText: 'Откуда едем?',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    GestureDetector(
                      onTap: () => setState(() => _isSelectingFrom = false),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: !_isSelectingFrom ? Colors.red.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: !_isSelectingFrom ? Colors.red : Colors.transparent),
                        ),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _toController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.location_on, color: Colors.red),
                              labelText: 'Куда едем?',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Row(
                      children: [
                        const Icon(Icons.payments, color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ваша цена (₸)',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _createOrder,
                        child: const Text('Предложить цену и вызвать', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _getMyLocation();
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}