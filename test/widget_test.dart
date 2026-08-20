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
      title: 'Р•СЃРёР»СЊ РўР°РєСЃРё',
      debugShowCheckedModeBanner:
          false, // РЈР±РёСЂР°РµРј РєСЂР°СЃРЅСѓСЋ Р»РµРЅС‚РѕС‡РєСѓ "DEBUG"
      theme: ThemeData(
        primarySwatch: Colors.amber, // Р¤РёСЂРјРµРЅРЅС‹Р№ С†РІРµС‚ С‚Р°РєСЃРё
        scaffoldBackgroundColor: Colors.white,
      ),
      // РўРµРїРµСЂСЊ РїРµСЂРІС‹Рј РѕС‚РєСЂС‹РІР°РµС‚СЃСЏ СЌРєСЂР°РЅ Р·Р°СЃС‚Р°РІРєРё
      home: const SplashScreen(),
    );
  }
}

// --- Р­РљР РђРќ 1: Р—РђРЎРўРђР’РљРђ (Splash Screen) ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Р–РґРµРј 2.5 СЃРµРєСѓРЅРґС‹ Рё РїРµСЂРµС…РѕРґРёРј РЅР° СЌРєСЂР°РЅ РІС…РѕРґР°
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
      backgroundColor: Colors.amber, // Р–РµР»С‚С‹Р№ С„РѕРЅ
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_taxi, size: 100, color: Colors.black87),
            const SizedBox(height: 20),
            const Text(
              'Р•РЎРР›Р¬ РўРђРљРЎР',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const CircularProgressIndicator(
              color: Colors.black54,
            ), // РљСЂСѓС‚РёР»РєР° Р·Р°РіСЂСѓР·РєРё
          ],
        ),
      ),
    );
  }
}

// --- Р­РљР РђРќ 2: Р’РҐРћР” / Р Р•Р“РРЎРўР РђР¦РРЇ ---
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
              const Icon(
                Icons.account_circle,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                'Р’С…РѕРґ РІ СЃРёСЃС‚РµРјСѓ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // РџРѕР»Рµ РґР»СЏ С‚РµР»РµС„РѕРЅР°
              TextField(
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone),
                  labelText: 'РќРѕРјРµСЂ С‚РµР»РµС„РѕРЅР°',
                  hintText: '+7 (700) 000-00-00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // РџРѕР»Рµ РґР»СЏ РїР°СЂРѕР»СЏ РёР»Рё РЎРњРЎ-РєРѕРґР°
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  labelText: 'РџР°СЂРѕР»СЊ / SMS РєРѕРґ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // РљРЅРѕРїРєР° РІС…РѕРґР°
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
                    // РџРѕРєР° РјС‹ РїСЂРѕСЃС‚Рѕ СЃРёРјСѓР»РёСЂСѓРµРј СѓСЃРїРµС€РЅС‹Р№ РІС…РѕРґ Рё РѕС‚РєСЂС‹РІР°РµРј РєР°СЂС‚Сѓ
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Р’РѕР№С‚Рё',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // РљРЅРѕРїРєР° СЂРµРіРёСЃС‚СЂР°С†РёРё
              TextButton(
                onPressed: () {
                  // Р—РґРµСЃСЊ РїРѕР·Р¶Рµ СЃРґРµР»Р°РµРј РѕС‚РґРµР»СЊРЅС‹Р№ СЌРєСЂР°РЅ СЂРµРіРёСЃС‚СЂР°С†РёРё
                },
                child: const Text(
                  'РќРµС‚ Р°РєРєР°СѓРЅС‚Р°? Р—Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°С‚СЊСЃСЏ',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Р­РљР РђРќ 3: РљРђР РўРђ (РќР°С€ СЃС‚Р°СЂС‹Р№ РєРѕРґ) ---
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(
    text: "1500",
  );

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
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'esil_taxi_app'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['address'] != null) {
          final road = data['address']['road'] ?? '';
          final houseNumber = data['address']['house_number'] ?? '';

          if (road.isNotEmpty) {
            return houseNumber.isNotEmpty ? '$road, $houseNumber' : road;
          }
          return data['display_name'] ?? 'РђРґСЂРµСЃ РЅРµ РЅР°Р№РґРµРЅ';
        }
      }
    } catch (e) {
      debugPrint('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ Р°РґСЂРµСЃР°: $e');
    }
    return "РљРѕРѕСЂРґРёРЅР°С‚С‹: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
  }

  Future<void> _getRoute() async {
    if (_fromPoint == null || _toPoint == null) return;

    setState(() => _routePoints = []);

    try {
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${_fromPoint!.longitude},${_fromPoint!.latitude};${_toPoint!.longitude},${_toPoint!.latitude}?geometries=geojson',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;

        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry']['coordinates'] as List;
          setState(() {
            _routePoints = geometry
                .map((coord) => LatLng(coord[1], coord[0]))
                .toList();
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('РћС€РёР±РєР° РїРѕСЃС‚СЂРѕРµРЅРёСЏ РјР°СЂС€СЂСѓС‚Р°: $e');
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
      _fromController.text =
          "РћРїСЂРµРґРµР»СЏРµРј РјРµСЃС‚РѕРїРѕР»РѕР¶РµРЅРёРµ...";
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
        _fromController.text = "Р—Р°РіСЂСѓР·РєР° Р°РґСЂРµСЃР°...";
        _isSelectingFrom = false;
      } else {
        _toPoint = tappedPoint;
        _toController.text = "Р—Р°РіСЂСѓР·РєР° Р°РґСЂРµСЃР°...";
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
        const SnackBar(
          content: Text(
            'РџРѕР¶Р°Р»СѓР№СЃС‚Р°, СѓРєР°Р¶РёС‚Рµ С‚РѕС‡РєРё В«РћС‚РєСѓРґР°В» Рё В«РљСѓРґР°В»',
          ),
        ),
      );
      return;
    }

    String price = _priceController.text.trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Р—Р°РєР°Р· СЃРѕР·РґР°РЅ!'),
        content: Text(
          'РњР°СЂС€СЂСѓС‚: ${_fromController.text} \nвћ” ${_toController.text}\n\nР¦РµРЅР°: $price в‚ё\n\nРС‰РµРј РІРѕРґРёС‚РµР»СЏ...',
        ),
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
        title: const Text('Р—Р°РєР°Р· С‚Р°РєСЃРё'),
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
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
                      ),
                      alignment: Alignment.topCenter,
                    ),
                  if (_toPoint != null)
                    Marker(
                      point: _toPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.flag,
                        color: Colors.red,
                        size: 40,
                      ),
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
                      ? "1. РЈРєР°Р¶РёС‚Рµ С‚РѕС‡РєСѓ РћРўРљРЈР”Рђ"
                      : "2. РЈРєР°Р¶РёС‚Рµ С‚РѕС‡РєСѓ РљРЈР”Рђ",
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
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
                          color: _isSelectingFrom
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isSelectingFrom
                                ? Colors.blue
                                : Colors.transparent,
                          ),
                        ),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _fromController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.my_location,
                                color: Colors.blue,
                              ),
                              labelText: 'РћС‚РєСѓРґР° РµРґРµРј?',
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
                          color: !_isSelectingFrom
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !_isSelectingFrom
                                ? Colors.red
                                : Colors.transparent,
                          ),
                        ),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _toController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.location_on,
                                color: Colors.red,
                              ),
                              labelText: 'РљСѓРґР° РµРґРµРј?',
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
                              labelText: 'Р’Р°С€Р° С†РµРЅР° (в‚ё)',
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
                        child: const Text(
                          'РџСЂРµРґР»РѕР¶РёС‚СЊ С†РµРЅСѓ Рё РІС‹Р·РІР°С‚СЊ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
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
