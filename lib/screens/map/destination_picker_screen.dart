import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '/models/city.dart';
import '/models/address_suggestion.dart';
import '/services/geocoding_service.dart';
import '/services/map_point_address_resolver.dart';
import '/widgets/tulpar_map_tile_layer.dart';
import '/widgets/tulpar_map_visuals.dart';

enum MapPointPurpose { pickup, destination }

class MapPointSelection {
  const MapPointSelection({required this.point, required this.address});

  final LatLng point;
  final String address;
}

class MapPointPickerScreen extends StatefulWidget {
  const MapPointPickerScreen({
    super.key,
    required this.initialCenter,
    required this.purpose,
    this.initialAddress,
    this.addressResolver,
    this.restrictedCity,
    this.cityPointValidator,
    this.locationProvider,
    this.showMapTiles = true,
  });

  final LatLng initialCenter;
  final MapPointPurpose purpose;
  final String? initialAddress;
  final MapPointAddressResolver? addressResolver;
  final City? restrictedCity;
  final Future<bool> Function(LatLng point, City city)? cityPointValidator;
  final Future<LatLng?> Function()? locationProvider;
  final bool showMapTiles;

  @override
  State<MapPointPickerScreen> createState() => _MapPointPickerScreenState();
}

class _MapPointPickerScreenState extends State<MapPointPickerScreen> {
  final MapController _mapController = MapController();
  late final MapPointAddressResolver _addressResolver;
  late LatLng _selectedPoint;
  LatLng? _userLocation;
  late String _selectedAddress;
  bool _isResolvingAddress = false;
  bool _isValidatingPoint = false;
  bool _isLocating = false;
  String? _validationMessage;
  int _reverseGeocodeRequestId = 0;
  int _validationRequestId = 0;
  int _locationRequestId = 0;
  Timer? _reverseGeocodeDebounce;

  @override
  void initState() {
    super.initState();
    _addressResolver = widget.addressResolver ?? MapPointAddressResolver();
    _selectedPoint = widget.initialCenter;
    _selectedAddress = widget.initialAddress?.trim().isNotEmpty == true
        ? widget.initialAddress!.trim()
        : 'Определение адреса...';
    final hasResolvedInitialAddress =
        _selectedAddress != 'Определение адреса...' &&
        !_selectedAddress.startsWith('Точка на карте');
    if (!hasResolvedInitialAddress) {
      unawaited(_selectPoint(widget.initialCenter));
    }
  }

  @override
  void dispose() {
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeRequestId++;
    _validationRequestId++;
    _locationRequestId++;
    super.dispose();
  }

  Future<void> _selectPoint(LatLng point) async {
    final requestId = ++_reverseGeocodeRequestId;
    _validationRequestId++;
    setState(() {
      _selectedPoint = point;
      _selectedAddress = 'Определение адреса...';
      _isResolvingAddress = true;
      _isValidatingPoint = false;
      _validationMessage = null;
    });

    try {
      final resolved = await _addressResolver
          .resolve(point)
          .timeout(const Duration(seconds: 10));
      if (!mounted || requestId != _reverseGeocodeRequestId) return;
      setState(() {
        _selectedAddress = AddressSuggestion.shortAddressFromDisplayName(
          resolved.address,
        );
        if (resolved.address.startsWith('Точка на карте')) {
          _validationMessage =
              'Не удалось определить адрес. Координаты сохранены.';
        }
      });
    } on TimeoutException {
      if (!mounted || requestId != _reverseGeocodeRequestId) return;
      setState(() {
        _selectedAddress = _coordinateFallback(point);
        _validationMessage =
            'Сервис адресов не отвечает. Координаты сохранены.';
      });
    } catch (_) {
      if (!mounted || requestId != _reverseGeocodeRequestId) return;
      setState(() {
        _selectedAddress = _coordinateFallback(point);
        _validationMessage =
            'Не удалось определить адрес. Координаты сохранены.';
      });
    } finally {
      if (mounted && requestId == _reverseGeocodeRequestId) {
        setState(() => _isResolvingAddress = false);
      }
    }
  }

  String _coordinateFallback(LatLng point) =>
      'Точка на карте (${point.latitude.toStringAsFixed(3)}, '
      '${point.longitude.toStringAsFixed(3)})';

  void _handleMapEvent(MapEvent event) {
    if (event is! MapEventMoveEnd) return;
    if (event.source == MapEventSource.mapController ||
        event.source == MapEventSource.fitCamera ||
        event.source == MapEventSource.nonRotatedSizeChange) {
      return;
    }

    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_selectPoint(event.camera.center)),
    );
  }

  Future<void> _confirmSelection() async {
    if (_isResolvingAddress || _isValidatingPoint) return;
    final requestId = ++_validationRequestId;
    final city = widget.restrictedCity;
    if (city != null) {
      setState(() {
        _isValidatingPoint = true;
        _validationMessage = null;
      });
      try {
        final allowed =
            city.contains(_selectedPoint) &&
            (await (widget.cityPointValidator?.call(_selectedPoint, city) ??
                    GeocodingService.pointBelongsToCity(_selectedPoint, city))
                .timeout(const Duration(seconds: 10)));
        if (!mounted || requestId != _validationRequestId) return;
        if (!allowed) {
          setState(() {
            _validationMessage = 'Выберите точку в городе ${city.name}.';
          });
          return;
        }
      } on TimeoutException {
        if (!mounted || requestId != _validationRequestId) return;
        setState(() {
          _validationMessage =
              'Не удалось проверить город. Проверьте сеть и повторите.';
        });
        return;
      } catch (_) {
        if (!mounted || requestId != _validationRequestId) return;
        setState(() {
          _validationMessage =
              'Не удалось проверить точку. Попробуйте ещё раз.';
        });
        return;
      } finally {
        if (mounted && requestId == _validationRequestId) {
          setState(() => _isValidatingPoint = false);
        }
      }
    }
    if (!mounted || requestId != _validationRequestId) return;
    Navigator.of(
      context,
    ).pop(MapPointSelection(point: _selectedPoint, address: _selectedAddress));
  }

  Future<void> _moveToCurrentLocation() async {
    if (_isLocating) return;
    final requestId = ++_locationRequestId;
    setState(() {
      _isLocating = true;
      _validationMessage = null;
    });
    LatLng? point;
    try {
      if (widget.locationProvider != null) {
        point = await widget.locationProvider!().timeout(
          const Duration(seconds: 12),
        );
      } else {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw const _LocationFailure('Включите геолокацию на телефоне.');
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied) {
          throw const _LocationFailure('Доступ к геолокации не разрешён.');
        }
        if (permission == LocationPermission.deniedForever) {
          throw const _LocationFailure(
            'Разрешите геолокацию в настройках приложения.',
          );
        }
        final position = await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 12),
        );
        point = LatLng(position.latitude, position.longitude);
      }
    } on TimeoutException {
      if (mounted && requestId == _locationRequestId) {
        setState(
          () => _validationMessage =
              'Не удалось быстро определить местоположение. Выберите точку вручную.',
        );
      }
      return;
    } on _LocationFailure catch (error) {
      if (mounted && requestId == _locationRequestId) {
        setState(() => _validationMessage = error.message);
      }
      return;
    } catch (_) {
      if (mounted && requestId == _locationRequestId) {
        setState(
          () => _validationMessage =
              'Не удалось определить местоположение. Выберите точку вручную.',
        );
      }
      return;
    } finally {
      if (mounted && requestId == _locationRequestId) {
        setState(() => _isLocating = false);
      }
    }
    if (!mounted || requestId != _locationRequestId) return;
    if (point == null) {
      setState(
        () => _validationMessage =
            'Не удалось получить местоположение. Выберите точку вручную.',
      );
      return;
    }

    final city = widget.restrictedCity;
    if (city != null) {
      bool allowed;
      try {
        allowed =
            city.contains(point) &&
            (await (widget.cityPointValidator?.call(point, city) ??
                    GeocodingService.pointBelongsToCity(point, city))
                .timeout(const Duration(seconds: 10)));
      } catch (_) {
        if (mounted && requestId == _locationRequestId) {
          setState(
            () => _validationMessage =
                'Не удалось проверить город. Выберите точку вручную или повторите.',
          );
        }
        return;
      }
      if (!mounted) return;
      if (!allowed) {
        setState(() {
          _validationMessage = 'Выберите точку в городе ${city.name}.';
        });
        return;
      }
    }
    setState(() => _userLocation = point);
    _mapController.move(point, 16);
    await _selectPoint(point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.purpose == MapPointPurpose.pickup
              ? 'Точка отправления'
              : 'Точка назначения',
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 16,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(-90, -180),
                  const LatLng(90, 180),
                ),
              ),
              onMapEvent: _handleMapEvent,
            ),
            children: [
              if (widget.showMapTiles) const TulparMapTileLayer(),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    TulparMapVisuals.userLocationMarker(
                      key: const Key('map_picker_user_location_marker'),
                      point: _userLocation!,
                    ),
                  ],
                ),
            ],
          ),
          IgnorePointer(child: Center(child: TulparSelectionPin())),
          Positioned(
            right: 16,
            bottom: 180,
            child: FloatingActionButton.small(
              key: const Key('map_picker_gps_button'),
              heroTag: 'map-picker-gps',
              tooltip: 'Моё местоположение',
              onPressed: _isLocating ? null : _moveToCurrentLocation,
              child: _isLocating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (_isResolvingAddress)
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.location_on,
                                color: widget.purpose == MapPointPurpose.pickup
                                    ? TulparMapVisuals.pickupColor
                                    : TulparMapVisuals.destinationColor,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              _selectedAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_validationMessage != null) ...[
                        Text(
                          _validationMessage!,
                          key: const Key('map_point_city_error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      FilledButton(
                        onPressed: _isResolvingAddress || _isValidatingPoint
                            ? null
                            : _confirmSelection,
                        child: Text(
                          _isValidatingPoint
                              ? 'Проверка...'
                              : 'Выбрать эту точку',
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
    );
  }
}

class _LocationFailure implements Exception {
  const _LocationFailure(this.message);
  final String message;
}
