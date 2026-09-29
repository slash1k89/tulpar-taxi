import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/intercity_pickup_draft.dart';
import '../models/navigation_step.dart';
import '../services/driver_trip_wakelock_controller.dart';
import '../services/navigation_camera_controller.dart';
import '../services/route_service.dart';
import '../widgets/navigation_overlay.dart';
import '../widgets/tulpar_map_tile_layer.dart';
import '../widgets/tulpar_map_visuals.dart';

class DriverNavigationScreen extends StatefulWidget {
  const DriverNavigationScreen({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    this.intermediatePoints = const [],
    this.intercity = false,
    this.onNextPickupReached,
  });

  final double destinationLat;
  final double destinationLng;
  final List<IntercityPickupDraft> intermediatePoints;
  final bool intercity;
  final Future<List<IntercityPickupDraft>> Function()? onNextPickupReached;

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  final MapController _map = MapController();
  final TulparMapCameraBridge _bridge = TulparMapCameraBridge();
  final NavigationCameraController _camera = NavigationCameraController();
  final DriverTripWakelockController _wakelock = DriverTripWakelockController();
  final ValueNotifier<LatLng?> _position = ValueNotifier(null);
  late final NavigationFollowResumeTimer _resume = NavigationFollowResumeTimer(
    canResume: () => mounted,
    onResume: _restoreFollow,
  );
  StreamSubscription<Position>? _positions;
  List<LatLng> _route = const [];
  List<NavigationStep> _steps = const [];
  double _distance = 0;
  double _duration = 0;
  bool _loading = true;
  bool _following = true;
  bool _markingPickup = false;
  String? _error;
  Position? _lastPosition;
  late List<IntercityPickupDraft> _intermediatePoints;

  @override
  void initState() {
    super.initState();
    _intermediatePoints = List.of(widget.intermediatePoints);
    _wakelock.start('in_progress');
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('gps_permission');
      }
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _loadRoute(current);
      _positions = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onPosition);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context).navigationGpsRequired;
        });
      }
    }
  }

  Future<void> _loadRoute(Position current) async {
    _lastPosition = current;
    final point = LatLng(current.latitude, current.longitude);
    final route = await RouteService.fetchRoute(
      startLat: current.latitude,
      startLng: current.longitude,
      destLat: widget.destinationLat,
      destLng: widget.destinationLng,
      intermediatePoints: _intermediatePoints
          .map((pickup) => LatLng(pickup.latitude, pickup.longitude))
          .toList(growable: false),
    );
    if (!mounted) return;
    setState(() {
      _position.value = point;
      _route = route.geometry;
      _steps = route.steps;
      _distance = route.distanceMeters;
      _duration = route.durationSeconds;
      _loading = false;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow(point, true));
  }

  void _onPosition(Position value) {
    _lastPosition = value;
    final point = LatLng(value.latitude, value.longitude);
    _position.value = point;
    if (_following) _follow(point, false, value);
  }

  Future<void> _markNextPickupReached() async {
    final callback = widget.onNextPickupReached;
    final current = _lastPosition;
    if (_markingPickup || callback == null || current == null) return;
    setState(() => _markingPickup = true);
    try {
      final remaining = await callback();
      if (!mounted) return;
      _intermediatePoints = List.of(remaining);
      await _loadRoute(current);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).intercityActiveTripUnknown,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingPickup = false);
    }
  }

  void _follow(LatLng point, bool snap, [Position? raw]) {
    if (!mounted || _route.isEmpty) return;
    final update = _camera.update(
      position: point,
      accuracyMeters: raw?.accuracy,
      reportedHeadingDegrees: raw?.heading,
      speedMetersPerSecond: raw?.speed,
      routeAhead: _route,
      snapToRoute: snap,
    );
    if (!update.accepted) return;
    _map.rotate(-(update.headingDegrees ?? 0), id: 'intercity-follow-bearing');
    _map.move(
      point,
      16.5,
      offset: Offset(0, _map.camera.nonRotatedSize.height * -0.14),
      id: 'intercity-follow-position',
    );
  }

  void _pauseFollow() {
    if (!_following) {
      _resume.schedule();
      return;
    }
    setState(() {
      _following = false;
      _camera.suspendFollow();
    });
    _resume.schedule();
  }

  void _restoreFollow() {
    final point = _position.value;
    if (!mounted || point == null) return;
    setState(() {
      _following = true;
      _camera.resumeFollow();
    });
    _follow(point, true);
  }

  @override
  void dispose() {
    _resume.dispose();
    unawaited(_positions?.cancel());
    unawaited(_wakelock.dispose(reason: 'intercity_navigation_closed'));
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = LatLng(widget.destinationLat, widget.destinationLng);
    final center = _position.value ?? destination;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.intercity
              ? AppLocalizations.of(context).intercityNavigationTitle
              : AppLocalizations.of(context).navigationTitle,
        ),
      ),
      body: Stack(
        children: [
          Listener(
            onPointerDown: (_) => _pauseFollow(),
            onPointerUp: (_) => _resume.schedule(),
            onPointerCancel: (_) => _resume.schedule(),
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                onMapEvent: (event) {
                  if (event.source != MapEventSource.mapController) {
                    _pauseFollow();
                  }
                },
              ),
              children: [
                if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                  TulparMapTileLayer(cameraBridge: _bridge)
                else
                  const ColoredBox(color: Color(0xFFE8E8E8)),
                if (_route.isNotEmpty)
                  PolylineLayer(
                    polylines: [TulparMapVisuals.routePolyline(_route)],
                  ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < _intermediatePoints.length; i++)
                      TulparMapVisuals.stopMarker(
                        point: LatLng(
                          _intermediatePoints[i].latitude,
                          _intermediatePoints[i].longitude,
                        ),
                        number: i + 1,
                        reached: false,
                      ),
                    TulparMapVisuals.endpointMarker(
                      point: destination,
                      endpoint: TulparMapEndpoint.destination,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_following)
            const Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment(0, 0.28),
                  child: SizedBox.square(
                    dimension: 50,
                    child: TulparVehicleMarker(),
                  ),
                ),
              ),
            ),
          if (!_loading && _steps.isNotEmpty)
            NavigationOverlay(
              steps: _steps,
              routeDistanceMeters: _distance,
              routeDurationSeconds: _duration,
              positionListenable: _position,
              routeTarget: destination,
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!),
                ),
              ),
            ),
          if (!_loading &&
              _intermediatePoints.isNotEmpty &&
              widget.onNextPickupReached != null)
            Positioned(
              left: 16,
              right: 88,
              bottom: 24,
              child: FilledButton.icon(
                key: const Key('intercity_navigation_pickup_reached'),
                onPressed: _markingPickup ? null : _markNextPickupReached,
                icon: const Icon(Icons.person_pin_circle_outlined),
                label: Text(
                  AppLocalizations.of(context).intercityMarkPickupReached,
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton(
              key: const Key('intercity_navigation_recenter'),
              onPressed: _restoreFollow,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
