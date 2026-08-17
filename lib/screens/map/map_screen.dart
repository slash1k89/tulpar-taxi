import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '/models/city.dart';
import '/models/address_suggestion.dart';
import '/services/city_service.dart';
import '/services/order_creation_service.dart';
import '/services/route_service.dart';
import '/services/geocoding_service.dart';
import '/widgets/app_drawer.dart';
import '/widgets/city_selection_modal.dart';
import '/widgets/order_creation_error_snackbar.dart';
import 'order_tracking_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.orderCreationService});

  final OrderCreationService? orderCreationService;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late final OrderCreationService _orderCreationService;

  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();

  City _selectedCity = availableCities.first;
  LatLng _mapCenter = availableCities.first.center;
  double _mapZoom = availableCities.first.mapZoom;

  LatLng? _fromPoint;
  LatLng? _toPoint;
  List<LatLng> _routePoints = [];

  final TextEditingController _fromAddressController = TextEditingController();
  final TextEditingController _toAddressController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(
    text: '500',
  );

  List<AddressSuggestion> _fromSuggestions = [];
  List<AddressSuggestion> _toSuggestions = [];
  Timer? _debounceFrom;
  Timer? _debounceTo;

  bool _isSelectingFrom = true;
  bool _isLoadingRoute = false;
  bool _isCreatingOrder = false;

  @override
  void initState() {
    super.initState();
    _orderCreationService =
        widget.orderCreationService ?? OrderCreationService();
    _fromFocusNode.addListener(_selectFromPoint);
    _toFocusNode.addListener(_selectToPoint);
    _loadSavedCity();
  }

  @override
  void dispose() {
    _fromAddressController.dispose();
    _toAddressController.dispose();
    _priceController.dispose();
    _fromFocusNode.removeListener(_selectFromPoint);
    _toFocusNode.removeListener(_selectToPoint);
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    _debounceFrom?.cancel();
    _debounceTo?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedCity() async {
    final cityId = await CityService.getSelectedCity();
    if (!mounted) return;

    final savedCity = availableCities.firstWhere(
      (city) => city.id == cityId,
      orElse: () => availableCities.first,
    );

    setState(() {
      _selectedCity = savedCity;
      _mapCenter = savedCity.center;
      _mapZoom = savedCity.mapZoom;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(savedCity.center, savedCity.mapZoom);
      }
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position pos = await Geolocator.getCurrentPosition();
    LatLng userPos = LatLng(pos.latitude, pos.longitude);

    if (mounted) {
      setState(() {
        _mapCenter = userPos;
        _mapZoom = 15.0;
      });
      _mapController.move(userPos, 15.0);
    }
  }

  void _selectFromPoint() {
    if (_fromFocusNode.hasFocus && !_isSelectingFrom) {
      setState(() => _isSelectingFrom = true);
    }
  }

  void _selectToPoint() {
    if (_toFocusNode.hasFocus && _isSelectingFrom) {
      setState(() => _isSelectingFrom = false);
    }
  }

  Future<void> _openCitySelector() async {
    final newCity = await showCitySelectionModal(
      context,
      currentCityId: _selectedCity.id,
    );
    if (newCity == null) return;

    await CityService.setSelectedCity(newCity.id);
    if (!mounted) return;

    setState(() {
      _selectedCity = newCity;
      _mapCenter = newCity.center;
      _mapZoom = newCity.mapZoom;
      _fromPoint = null;
      _toPoint = null;
      _routePoints.clear();
      _fromAddressController.clear();
      _toAddressController.clear();
      _fromSuggestions.clear();
      _toSuggestions.clear();
    });
    _mapController.move(newCity.center, newCity.mapZoom);
  }

  void _onMapTap(TapPosition tapPos, LatLng point) async {
    if (_isSelectingFrom) {
      setState(() {
        _fromPoint = point;
        _fromAddressController.text = 'Определение адреса...';
        _fromSuggestions.clear();
        _isSelectingFrom = false;
      });

      final address = await GeocodingService.reverseGeocode(
        point.latitude,
        point.longitude,
      );

      if (mounted) {
        setState(() {
          _fromAddressController.text = address;
        });
      }
    } else {
      setState(() {
        _toPoint = point;
        _toAddressController.text = 'Определение адреса...';
        _toSuggestions.clear();
      });

      final address = await GeocodingService.reverseGeocode(
        point.latitude,
        point.longitude,
      );

      if (mounted) {
        setState(() {
          _toAddressController.text = address;
        });
      }
    }

    if (_fromPoint != null && _toPoint != null) {
      _buildRoute();
    }
  }

  Future<void> _buildRoute() async {
    if (_fromPoint == null || _toPoint == null) return;

    setState(() => _isLoadingRoute = true);
    try {
      final points = await RouteService.fetchRouteGeometry(
        startLat: _fromPoint!.latitude,
        startLng: _fromPoint!.longitude,
        destLat: _toPoint!.latitude,
        destLng: _toPoint!.longitude,
      );

      if (mounted) {
        setState(() {
          _routePoints = points;
        });
        _mapController.move(_fromPoint!, 13.5);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка построения маршрута: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _submitOrder() async {
    if (_isCreatingOrder) return;

    if (_fromPoint == null || _toPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите точки A и B на карте или выберите из списка'),
        ),
      );
      return;
    }

    final priceInt =
        int.tryParse(_priceController.text.replaceAll(RegExp(r'\D'), '')) ??
        500;

    setState(() => _isCreatingOrder = true);
    late final String orderId;

    try {
      orderId = await _orderCreationService
          .createOrder(
            fromAddress: _fromAddressController.text.isEmpty
                ? 'Точка A'
                : _fromAddressController.text,
            toAddress: _toAddressController.text.isEmpty
                ? 'Точка B'
                : _toAddressController.text,
            price: priceInt,
            fromPoint: _fromPoint!,
            toPoint: _toPoint!,
            cityId: _selectedCity.id,
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('[OrderCreation] timeout: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нет ответа от сервера. Попробуйте ещё раз.'),
          ),
        );
      }
      return;
    } catch (error, stackTrace) {
      debugPrint(
        '[OrderCreation] UI failure type=${error.runtimeType} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        showOrderCreationError(context, error);
      }
      return;
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: orderId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _openCitySelector,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 20, color: Colors.amber),
                const SizedBox(width: 6),
                Text(
                  _selectedCity.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        centerTitle: true,
      ),
      drawer: const AppDrawer(mode: AppMode.passenger),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _mapZoom,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tulpar_taxi',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: Colors.amber,
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
                        color: Colors.green,
                        size: 40,
                      ),
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
                    ),
                ],
              ),
            ],
          ),

          if (_isLoadingRoute)
            const Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),

          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Поле Откуда
                      TextField(
                        controller: _fromAddressController,
                        focusNode: _fromFocusNode,
                        onTap: _selectFromPoint,
                        decoration: InputDecoration(
                          labelText: 'Откуда',
                          prefixIcon: const Icon(
                            Icons.my_location,
                            color: Colors.green,
                          ),
                          suffixIcon: _fromAddressController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _fromAddressController.clear();
                                    setState(() {
                                      _fromSuggestions.clear();
                                      _fromPoint = null;
                                      _routePoints.clear();
                                    });
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (val) {
                          _debounceFrom?.cancel();
                          _debounceFrom = Timer(
                            const Duration(milliseconds: 350),
                            () async {
                              if (val.trim().length >= 2) {
                                final results =
                                    await GeocodingService.searchAddress(
                                      query: val,
                                      cityName: _selectedCity.name,
                                      cityLat: _mapCenter.latitude,
                                      cityLng: _mapCenter.longitude,
                                    );
                                if (mounted) {
                                  setState(() => _fromSuggestions = results);
                                }
                              } else {
                                if (mounted) {
                                  setState(() => _fromSuggestions.clear());
                                }
                              }
                            },
                          );
                        },
                      ),

                      // Список подсказок для поля Откуда
                      if (_fromSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.amber.shade400,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _fromSuggestions.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _fromSuggestions[index];
                              return ListTile(
                                dense: true,
                                tileColor: Colors.white,
                                leading: const Icon(
                                  Icons.location_on,
                                  size: 18,
                                  color: Colors.amber,
                                ),
                                title: Text(
                                  item.displayName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _fromPoint = LatLng(item.lat, item.lng);
                                    _fromAddressController.text =
                                        item.displayName;
                                    _fromSuggestions.clear();
                                  });
                                  _fromFocusNode.unfocus();
                                  _mapController.move(_fromPoint!, 15.0);
                                  if (_fromPoint != null && _toPoint != null) {
                                    _buildRoute();
                                  }
                                },
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Поле Куда
                      TextField(
                        controller: _toAddressController,
                        focusNode: _toFocusNode,
                        onTap: _selectToPoint,
                        decoration: InputDecoration(
                          labelText: 'Куда',
                          prefixIcon: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                          ),
                          suffixIcon: _toAddressController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _toAddressController.clear();
                                    setState(() {
                                      _toSuggestions.clear();
                                      _toPoint = null;
                                      _routePoints.clear();
                                    });
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (val) {
                          _debounceTo?.cancel();
                          _debounceTo = Timer(
                            const Duration(milliseconds: 350),
                            () async {
                              if (val.trim().length >= 2) {
                                final results =
                                    await GeocodingService.searchAddress(
                                      query: val,
                                      cityName: _selectedCity.name,
                                      cityLat: _mapCenter.latitude,
                                      cityLng: _mapCenter.longitude,
                                    );
                                if (mounted) {
                                  setState(() => _toSuggestions = results);
                                }
                              } else {
                                if (mounted) {
                                  setState(() => _toSuggestions.clear());
                                }
                              }
                            },
                          );
                        },
                      ),

                      // Список подсказок для поля Куда
                      if (_toSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.amber.shade400,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _toSuggestions.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _toSuggestions[index];
                              return ListTile(
                                dense: true,
                                tileColor: Colors.white,
                                leading: const Icon(
                                  Icons.location_on,
                                  size: 18,
                                  color: Colors.amber,
                                ),
                                title: Text(
                                  item.displayName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _toPoint = LatLng(item.lat, item.lng);
                                    _toAddressController.text =
                                        item.displayName;
                                    _toSuggestions.clear();
                                  });
                                  _toFocusNode.unfocus();
                                  _mapController.move(_toPoint!, 15.0);
                                  if (_fromPoint != null && _toPoint != null) {
                                    _buildRoute();
                                  }
                                },
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ваша цена (₸)',
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: Colors.amber,
                          ),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isCreatingOrder ? null : _submitOrder,
                          child: _isCreatingOrder
                              ? const CircularProgressIndicator(
                                  color: Colors.black,
                                )
                              : const Text(
                                  'Заказать такси',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 295),
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.white,
          onPressed: _determinePosition,
          child: const Icon(Icons.my_location, color: Colors.black),
        ),
      ),
    );
  }
}
