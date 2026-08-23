import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '/services/geocoding_service.dart';

class DestinationSelection {
  const DestinationSelection({required this.point, required this.address});

  final LatLng point;
  final String address;
}

class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({
    super.key,
    required this.initialCenter,
    this.initialAddress,
  });

  final LatLng initialCenter;
  final String? initialAddress;

  @override
  State<DestinationPickerScreen> createState() =>
      _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen> {
  late LatLng _selectedPoint;
  late String _selectedAddress;
  bool _isResolvingAddress = false;
  int _reverseGeocodeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialCenter;
    _selectedAddress = widget.initialAddress?.trim().isNotEmpty == true
        ? widget.initialAddress!.trim()
        : 'Определение адреса...';
    unawaited(_selectPoint(widget.initialCenter));
  }

  Future<void> _selectPoint(LatLng point) async {
    final requestId = ++_reverseGeocodeRequestId;
    setState(() {
      _selectedPoint = point;
      _selectedAddress = 'Определение адреса...';
      _isResolvingAddress = true;
    });

    final address = await GeocodingService.reverseGeocode(
      point.latitude,
      point.longitude,
    );
    if (!mounted || requestId != _reverseGeocodeRequestId) return;

    setState(() {
      _selectedAddress = address;
      _isResolvingAddress = false;
    });
  }

  void _handleMapEvent(MapEvent event) {
    if (event is! MapEventMoveEnd) return;
    if (event.source == MapEventSource.mapController ||
        event.source == MapEventSource.fitCamera ||
        event.source == MapEventSource.nonRotatedSizeChange) {
      return;
    }

    unawaited(_selectPoint(event.camera.center));
  }

  void _confirmSelection() {
    if (_isResolvingAddress) return;
    Navigator.of(context).pop(
      DestinationSelection(point: _selectedPoint, address: _selectedAddress),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Точка назначения')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 16,
              onMapEvent: _handleMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tulpar_taxi',
              ),
            ],
          ),
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: const Icon(
                  Icons.location_on,
                  size: 48,
                  color: Colors.red,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 5)],
                ),
              ),
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
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.location_on, color: Colors.red),
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
                      FilledButton(
                        onPressed: _isResolvingAddress
                            ? null
                            : _confirmSelection,
                        child: const Text('Выбрать эту точку'),
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
