import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/order_service_type.dart';
import '../../app_routes.dart';
import '../../services/active_order_service.dart';
import '../../widgets/city_order_cancellation_dialog.dart';
import '../../models/next_order.dart';
import '../../screens/chat/chat_screen.dart';
import '../../widgets/chat_unread_badge.dart';
import '../../widgets/order_stops_view.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/driver_location_marker_layer.dart';
import '../../widgets/navigation_overlay.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/delivery_details_view.dart';
import '../../widgets/intercity_details_view.dart';
import '../../widgets/next_order_candidate_card.dart';
import '../../widgets/tulpar_map_tile_layer.dart';
import '../../widgets/tulpar_map_visuals.dart';
import '../../services/route_service.dart'; // Переиспользуем сервис
import '../../services/order_workflow_service.dart';
import '../../services/order_offer_service.dart';
import '../../services/driver_tracking_service.dart';
import '../../services/address_label_service.dart';
import '../../services/driver_next_order_transition.dart';
import '../../services/next_order_candidate_controller.dart';
import '../../services/tulpar_api_client.dart';
import '../../services/navigation_reroute_controller.dart';
import '../../services/navigation_camera_controller.dart';
import '../../services/driver_trip_wakelock_controller.dart';
import '../../services/navigation_route_trimmer.dart';
import '../../services/navigation_voice_service.dart';
import '../../services/voice_guidance_settings.dart';
import '../../models/navigation_step.dart';
import '../../models/order_stops.dart';
import '../../l10n/generated/app_localizations.dart';

class DriverRoutePlan {
  const DriverRoutePlan({
    required this.destination,
    this.intermediatePoints = const [],
  });

  final LatLng destination;
  final List<LatLng> intermediatePoints;

  List<LatLng> get orderedRemainingPoints => [
    ...intermediatePoints,
    destination,
  ];
}

DriverRoutePlan driverRoutePlan(
  Map<String, dynamic> orderData, {
  String? statusOverride,
}) {
  final status =
      statusOverride ?? orderData['status']?.toString() ?? 'accepted';
  final useDestination = status == 'in_progress';
  if (useDestination) {
    final pending = <({LatLng point, int sequence, int fallbackIndex})>[];
    final stops = orderStopsFromData(orderData);
    for (var index = 0; index < stops.length; index++) {
      final stop = stops[index];
      if (!stop.isReached) {
        final lat = stop.raw['latitude'] ?? stop.raw['lat'];
        final lng = stop.raw['longitude'] ?? stop.raw['lng'];
        if (lat is num && lng is num) {
          pending.add((
            point: LatLng(lat.toDouble(), lng.toDouble()),
            sequence: stop.sequence,
            fallbackIndex: index,
          ));
        }
      }
    }
    pending.sort((left, right) {
      final bySequence = left.sequence.compareTo(right.sequence);
      return bySequence != 0
          ? bySequence
          : left.fallbackIndex.compareTo(right.fallbackIndex);
    });
    if (pending.isNotEmpty) {
      final points = pending.map((entry) => entry.point).toList();
      return DriverRoutePlan(
        destination: points.last,
        intermediatePoints: List.unmodifiable(points.take(points.length - 1)),
      );
    }
  }
  return DriverRoutePlan(
    destination: LatLng(
      (orderData[useDestination ? 'toLat' : 'fromLat'] as num).toDouble(),
      (orderData[useDestination ? 'toLng' : 'fromLng'] as num).toDouble(),
    ),
  );
}

LatLng driverRouteDestination(
  Map<String, dynamic> orderData, {
  String? statusOverride,
}) {
  final plan = driverRoutePlan(orderData, statusOverride: statusOverride);
  return plan.intermediatePoints.isEmpty
      ? plan.destination
      : plan.intermediatePoints.first;
}

bool hasPendingIntermediateStop(Map<String, dynamic> orderData) {
  final pending = orderStopsFromData(
    orderData,
  ).where((stop) => !stop.isReached).length;
  return pending > 1;
}

bool driverRouteContextChanged({
  required String oldOrderId,
  required String newOrderId,
  required Map<String, dynamic> oldOrderData,
  required Map<String, dynamic> newOrderData,
}) =>
    oldOrderId != newOrderId ||
    oldOrderData['status']?.toString() != newOrderData['status']?.toString() ||
    orderStopsFromData(
          oldOrderData,
        ).map((stop) => '${stop.sequence}:${stop.reachedAt}').join('|') !=
        orderStopsFromData(
          newOrderData,
        ).map((stop) => '${stop.sequence}:${stop.reachedAt}').join('|');

bool driverStatusSupportsNavigation(Object? status) => {
  'accepted',
  'driver_arrived',
  'arrived',
  'in_progress',
}.contains(status?.toString());

const double navigationVehicleVerticalFraction = 0.64;

bool navigationUsesFixedVehicleMarker({
  required bool following,
  required bool hasActiveNavigation,
}) => following && hasActiveNavigation;

bool navigationShouldRestoreCameraOnResume({
  required bool following,
  required bool hasActiveNavigation,
}) => following && hasActiveNavigation;

bool navigationMapEventDisablesFollow(MapEventSource source) => const {
  MapEventSource.dragStart,
  MapEventSource.onDrag,
  MapEventSource.dragEnd,
  MapEventSource.multiFingerGestureStart,
  MapEventSource.onMultiFinger,
  MapEventSource.multiFingerEnd,
  MapEventSource.doubleTap,
  MapEventSource.doubleTapHold,
  MapEventSource.doubleTapZoomAnimationController,
  MapEventSource.flingAnimationController,
  MapEventSource.scrollWheel,
  MapEventSource.cursorKeyboardRotation,
  MapEventSource.keyboard,
}.contains(source);

Offset navigationCameraOffset(Size mapSize) =>
    Offset(0, mapSize.height * (navigationVehicleVerticalFraction - 0.5));

class FixedNavigationVehicleMarker extends StatelessWidget {
  const FixedNavigationVehicleMarker({
    super.key,
    required this.marker,
    this.gpsPosition,
  });

  final Widget marker;

  /// Kept for diagnostics and tests. GPS changes navigation state, but never
  /// participates in this overlay's screen-space layout.
  final LatLng? gpsPosition;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    key: const Key('driver_fixed_vehicle_marker'),
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned(
              left:
                  (constraints.maxWidth - TulparMapVisuals.vehicleMarkerSize) /
                  2,
              top:
                  constraints.maxHeight * navigationVehicleVerticalFraction -
                  TulparMapVisuals.vehicleMarkerSize / 2,
              width: TulparMapVisuals.vehicleMarkerSize,
              height: TulparMapVisuals.vehicleMarkerSize,
              child: marker,
            ),
          ],
        ),
      ),
    ),
  );
}

class DriverRouteRequestState {
  int _generation = 0;
  bool isLoading = false;
  List<LatLng> geometry = const [];
  List<NavigationStep> steps = const [];
  double routeDistanceMeters = 0;
  double routeDurationSeconds = 0;
  bool isRerouting = false;
  String? rerouteErrorMessage;

  int get generation => _generation;

  int begin({bool preserveRoute = false, bool rerouting = false}) {
    isLoading = true;
    isRerouting = rerouting;
    rerouteErrorMessage = null;
    if (!preserveRoute) {
      geometry = const [];
      steps = const [];
      routeDistanceMeters = 0;
      routeDurationSeconds = 0;
    }
    return ++_generation;
  }

  void invalidate() {
    _generation++;
    isLoading = false;
    isRerouting = false;
    rerouteErrorMessage = null;
    geometry = const [];
    steps = const [];
    routeDistanceMeters = 0;
    routeDurationSeconds = 0;
  }

  bool complete(int generation, RouteResult result) {
    if (generation != _generation) return false;
    isLoading = false;
    isRerouting = false;
    rerouteErrorMessage = null;
    geometry = result.geometry;
    steps = result.steps;
    routeDistanceMeters = result.distanceMeters;
    routeDurationSeconds = result.durationSeconds;
    return true;
  }

  bool fail(int generation, {bool rerouting = false}) {
    if (generation != _generation) return false;
    isLoading = false;
    isRerouting = false;
    if (rerouting) rerouteErrorMessage = 'Не удалось перестроить маршрут';
    return true;
  }
}

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

class _DriverMapScreenState extends State<DriverMapScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final DriverRouteRequestState _routeState = DriverRouteRequestState();
  final DriverTrackingService _tracking = DriverTrackingService();
  final NavigationRerouteController _rerouteController =
      NavigationRerouteController();
  final NavigationCameraController _cameraController =
      NavigationCameraController();
  final NavigationRouteTrimmer _routeTrimmer = NavigationRouteTrimmer();
  final NavigationVoiceController _voiceController =
      NavigationVoiceController();
  final TulparMapCameraBridge _mapCameraBridge = TulparMapCameraBridge();
  final DriverTripWakelockController _wakelockController =
      DriverTripWakelockController();
  late final NextOrderCandidateController _nextOrderController;
  late final DriverNextOrderTransition _nextOrderTransition;
  final OrderOfferService _offerService = OrderOfferService();
  String? _trackingMessage;
  bool _cancellingCityOrder = false;
  bool _cityCancellationHandled = false;
  bool _checkingRemoteCityCancellation = false;
  Timer? _cityCancellationPoll;
  bool get _followDriver => _cameraController.following;
  late final AnimationController _cameraAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  LatLng? _cameraPosition;
  bool _isMapReady = false;
  bool _isOrderPanelExpanded = true;
  int _activeMapPointers = 0;
  late final NavigationFollowResumeTimer _followResume =
      NavigationFollowResumeTimer(
        canResume: () =>
            mounted && _hasActiveNavigation && _activeMapPointers == 0,
        onResume: _resumeFollowing,
      );

  static const double _navigationZoom = 16.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wakelockController.start(widget.orderData['status']);
    _tracking.positionListenable.addListener(_handleDriverPosition);
    appVoiceGuidanceSettings.addListener(_handleVoiceSettingChanged);
    unawaited(appVoiceGuidanceSettings.load());
    _nextOrderController = NextOrderCandidateController(
      apiClient: TulparApiClient(),
    )..addListener(_handleNextOrderChanged);
    _nextOrderTransition = DriverNextOrderTransition(
      apiClient: TulparApiClient(),
    );
    _nextOrderController.updateOrder(widget.orderData);
    _startTracking();
    if (widget.orderData['serviceType'] == 'city') {
      _cityCancellationPoll = Timer.periodic(const Duration(seconds: 3), (_) {
        unawaited(_checkRemoteCityCancellation());
      });
    }
  }

  Future<void> _checkRemoteCityCancellation() async {
    if (_checkingRemoteCityCancellation ||
        _cityCancellationHandled ||
        !mounted) {
      return;
    }
    _checkingRemoteCityCancellation = true;
    try {
      final details = await TulparApiClient().getOrderDetails(widget.orderId);
      if (details['status'] == 'cancelled' && mounted) {
        await _finishCancelledCityOrder();
      }
    } catch (_) {
      // A transient network failure is not a confirmed cancellation.
    } finally {
      _checkingRemoteCityCancellation = false;
    }
  }

  Future<void> _finishCancelledCityOrder() async {
    if (_cityCancellationHandled) return;
    _cityCancellationHandled = true;
    _cityCancellationPoll?.cancel();
    _followResume.cancel();
    _routeState.invalidate();
    _rerouteController.reset();
    _wakelockController.updateStatus('cancelled');
    await _tracking.stopLocationUpdates(widget.orderId);
    ActiveOrderService.clearRememberedOrder();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.driverTaxi, (_) => false);
  }

  void _handleNextOrderChanged() {
    if (mounted) setState(() {});
  }

  void _handleVoiceSettingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startTracking() async {
    final result = await _tracking.startLocationUpdates(widget.orderId);
    if (mounted && !result.isStarted) {
      final l10n = AppLocalizations.of(context);
      setState(
        () => _trackingMessage = switch (result.failure) {
          DriverTrackingFailure.stopped => l10n.trackingStopped,
          DriverTrackingFailure.signIn => l10n.trackingSignIn,
          DriverTrackingFailure.servicesDisabled => l10n.trackingEnableServices,
          DriverTrackingFailure.permissionDenied => l10n.trackingAllowLocation,
          DriverTrackingFailure.settingsDenied => l10n.trackingAllowInSettings,
          DriverTrackingFailure.positionFailed ||
          null => l10n.trackingPositionFailed,
        },
      );
    }
  }

  @override
  void dispose() {
    _cityCancellationPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _followResume.dispose();
    _cameraAnimation.dispose();
    _tracking.positionListenable.removeListener(_handleDriverPosition);
    appVoiceGuidanceSettings.removeListener(_handleVoiceSettingChanged);
    _nextOrderController.removeListener(_handleNextOrderChanged);
    _nextOrderController.dispose();
    _nextOrderTransition.invalidate();
    unawaited(_tracking.dispose(widget.orderId));
    unawaited(_voiceController.dispose());
    unawaited(_wakelockController.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_hasActiveNavigation) {
      return;
    }
    _followResume.cancel();
    _activeMapPointers = 0;
    if (!_followDriver) setState(_cameraController.resumeFollow);
    final position = _tracking.latestPosition;
    if (kDebugMode) {
      debugPrint('[NavCamera] FOLLOW=true source=app_resume');
    }
    if (position != null) _moveMapToDriver(position, snapToRoute: true);
  }

  @override
  void didUpdateWidget(covariant DriverMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final orderChanged = oldWidget.orderId != widget.orderId;
    if (orderChanged) {
      unawaited(_restartTracking(oldWidget.orderId));
    }
    _nextOrderController.updateOrder(widget.orderData);
    _wakelockController.updateStatus(widget.orderData['status']);
    if (driverRouteContextChanged(
      oldOrderId: oldWidget.orderId,
      newOrderId: widget.orderId,
      oldOrderData: oldWidget.orderData,
      newOrderData: widget.orderData,
    )) {
      final position = _tracking.latestPosition;
      setState(() {
        _routeState.invalidate();
        _rerouteController.reset();
        _cameraController.restoreAfterNavigationChange();
        _routeTrimmer.reset();
      });
      if (position == null ||
          !driverStatusSupportsNavigation(widget.orderData['status'])) {
        return;
      } else {
        _requestRouteFrom(position);
      }
    }
  }

  Future<void> _restartTracking(String oldOrderId) async {
    await _tracking.stopLocationUpdates(oldOrderId);
    await _startTracking();
  }

  // Route geometry improves the bearing, but must not gate navigation follow:
  // while it is loading (or temporarily unavailable) GPS/heading is the
  // supported fallback and the vehicle must remain screen-fixed.
  bool get _hasActiveNavigation =>
      driverStatusSupportsNavigation(widget.orderData['status']);

  void _handleDriverPosition() {
    final driverPosition = _tracking.latestPosition;
    if (driverPosition == null) return;

    if (_routeTrimmer.updatePosition(
      position: driverPosition,
      accuracyMeters: _tracking.latestAccuracyMeters,
    )) {
      setState(() {});
    }
    if (_followDriver && _hasActiveNavigation) {
      _moveMapToDriver(driverPosition);
    }
    if (!driverStatusSupportsNavigation(widget.orderData['status'])) return;
    if (_routeState.geometry.isEmpty && !_routeState.isLoading) {
      _requestRouteFrom(driverPosition);
      return;
    }
    _checkForReroute(driverPosition);
  }

  LatLng _routeDestination([String? statusOverride]) {
    return driverRouteDestination(
      widget.orderData,
      statusOverride: statusOverride,
    );
  }

  DriverRoutePlan _routePlan([String? statusOverride]) =>
      driverRoutePlan(widget.orderData, statusOverride: statusOverride);

  void _requestRouteFrom(
    LatLng driverPosition, {
    String? statusOverride,
    bool isReroute = false,
  }) {
    if (isReroute && _routeState.isLoading) return;
    _cameraController.restoreAfterNavigationChange();
    final plan = _routePlan(statusOverride);
    final orderId = widget.orderId;
    late final int generation;
    setState(() {
      generation = _routeState.begin(
        preserveRoute: isReroute,
        rerouting: isReroute,
      );
      if (!isReroute) _routeTrimmer.reset();
      if (isReroute) _rerouteController.markRequestStarted();
    });
    unawaited(
      _loadRoute(
        driverPosition,
        generation: generation,
        plan: plan,
        orderId: orderId,
        isReroute: isReroute,
      ),
    );
  }

  void _checkForReroute(LatLng driverPosition) {
    final status = widget.orderData['status']?.toString();
    if (_routeState.geometry.isEmpty ||
        _routeState.isLoading ||
        !driverStatusSupportsNavigation(status)) {
      return;
    }
    final decision = _rerouteController.updatePosition(
      position: driverPosition,
      accuracyMeters: _tracking.latestAccuracyMeters,
    );
    if (kDebugMode) {
      final target = _routeDestination();
      final targetDistance = const Distance().as(
        LengthUnit.Meter,
        driverPosition,
        target,
      );
      debugPrint(
        '[Nav] phase=$status targetDistance=${targetDistance.round()} '
        'accuracy=${_tracking.latestAccuracyMeters} '
        'offRoute=${decision.distanceToRouteMeters} '
        'reroute=${decision.shouldReroute}',
      );
    }
    if (decision.shouldReroute) {
      _requestRouteFrom(driverPosition, isReroute: true);
    }
  }

  Future<void> _loadRoute(
    LatLng driverPosition, {
    required int generation,
    required DriverRoutePlan plan,
    required String orderId,
    required bool isReroute,
  }) async {
    try {
      if (kDebugMode) {
        final coordinates = [driverPosition, ...plan.orderedRemainingPoints];
        debugPrint(
          '[Route] orderId=$orderId '
          'pickup=${driverPosition.latitude},${driverPosition.longitude} '
          'stops=${plan.intermediatePoints.map((p) => '${p.latitude},${p.longitude}').toList()} '
          'destination=${plan.destination.latitude},${plan.destination.longitude} '
          'osrmCoordinates=${coordinates.map((p) => '${p.longitude},${p.latitude}').join(';')}',
        );
      }
      final result = await RouteService.fetchRoute(
        startLat: driverPosition.latitude,
        startLng: driverPosition.longitude,
        destLat: plan.destination.latitude,
        destLng: plan.destination.longitude,
        intermediatePoints: plan.intermediatePoints,
      );

      if (kDebugMode && result.geometry.isNotEmpty) {
        final diagnostics = RouteEndpointDiagnostics.fromRoute(
          geometry: result.geometry,
          expectedStart: driverPosition,
          expectedDestination: plan.destination,
        );
        debugPrint(
          '[Route] waypoint[0] input=${driverPosition.latitude},${driverPosition.longitude} '
          'snapped=${result.geometry.first.latitude},${result.geometry.first.longitude} '
          'snapDistance=${diagnostics.startDistanceMeters.round()}m',
        );
        debugPrint(
          '[Route] waypoint[last] input=${plan.destination.latitude},${plan.destination.longitude} '
          'snapped=${result.geometry.last.latitude},${result.geometry.last.longitude} '
          'snapDistance=${diagnostics.destinationDistanceMeters.round()}m '
          'withinTolerance=${diagnostics.destinationWithinTolerance}',
        );
        assert(
          diagnostics.destinationWithinTolerance,
          'OSRM route endpoint is ${diagnostics.destinationDistanceMeters.round()}m '
          'from the selected destination.',
        );
      }

      if (mounted && orderId == widget.orderId) {
        setState(() {
          final applied = _routeState.complete(generation, result);
          if (applied) {
            _rerouteController.replaceRoute(
              result.geometry,
              startCooldown: isReroute,
            );
            _routeTrimmer.replaceRoute(result.geometry);
            final current = _tracking.latestPosition ?? driverPosition;
            _routeTrimmer.updatePosition(
              position: current,
              accuracyMeters: _tracking.latestAccuracyMeters,
            );
            if (_followDriver) _moveMapToDriver(current);
          }
        });
      }
    } catch (e) {
      debugPrint('Ошибка получения маршрута: $e');
      if (mounted) {
        setState(() {
          final applied = _routeState.fail(generation, rerouting: isReroute);
          if (applied && isReroute) _rerouteController.markRequestFailed();
        });
      }
    }
  }

  void _moveMapToDriver(LatLng position, {bool snapToRoute = false}) {
    final cameraUpdate = _cameraController.update(
      position: position,
      accuracyMeters: _tracking.latestAccuracyMeters,
      reportedHeadingDegrees: _tracking.latestHeadingDegrees,
      speedMetersPerSecond: _tracking.latestSpeedMetersPerSecond,
      routeAhead: _routeTrimmer.visibleRoute,
      snapToRoute: snapToRoute,
    );
    if (!cameraUpdate.accepted) return;
    if (kDebugMode) {
      debugPrint(
        '[NavCamera] FOLLOW=$_followDriver '
        'GPS=${position.latitude.toStringAsFixed(6)},'
        '${position.longitude.toStringAsFixed(6)} '
        'ROUTE_BEARING=${cameraUpdate.routeBearingDegrees?.toStringAsFixed(1)} '
        'CAMERA_TARGET=${cameraUpdate.targetHeadingDegrees?.toStringAsFixed(1)} '
        'CAR_SCREEN_ANCHOR=$navigationVehicleVerticalFraction',
      );
    }
    final ticket = _cameraController.beginCameraUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_isMapReady ||
          !_cameraController.canApply(ticket) ||
          !_hasActiveNavigation) {
        return;
      }
      _cameraAnimation.stop();
      final start = _cameraPosition ?? position;
      final startHeading = -_mapController.camera.rotation;
      final delta = NavigationCameraController.shortestAngularDifference(
        startHeading,
        cameraUpdate.headingDegrees ?? startHeading,
      );
      void tick() {
        if (!mounted ||
            !_cameraController.canApply(ticket) ||
            !_hasActiveNavigation) {
          return;
        }
        final t = Curves.easeInOut.transform(_cameraAnimation.value);
        _cameraPosition = LatLng(
          start.latitude + (position.latitude - start.latitude) * t,
          start.longitude + (position.longitude - start.longitude) * t,
        );
        // FlutterMap rotation is opposite to MapLibre's geographic bearing.
        _mapController.rotate(
          -(startHeading + delta * t),
          id: 'driver-follow-heading',
        );
        _mapController.move(
          _cameraPosition!,
          _navigationZoom,
          offset: navigationCameraOffset(_mapController.camera.nonRotatedSize),
          id: 'driver-follow-position',
        );
      }

      _cameraAnimation.addListener(tick);
      _cameraAnimation
          .forward(from: 0)
          .orCancel
          .then(
            (_) {
              _cameraAnimation.removeListener(tick);
              if (kDebugMode && _cameraController.canApply(ticket)) {
                final applied = -_mapController.camera.rotation;
                final center = _mapController.camera.center;
                debugPrint(
                  '[NavCamera] appliedBearing=${applied.toStringAsFixed(1)} '
                  'mapCenter=${center.latitude.toStringAsFixed(6)},'
                  '${center.longitude.toStringAsFixed(6)} '
                  'follow=$_followDriver fixedVehicleMarker=true',
                );
              }
            },
            onError: (Object _) {
              _cameraAnimation.removeListener(tick);
            },
          );
    });
  }

  void _resumeFollowing() {
    _followResume.cancel();
    final position = _tracking.latestPosition;
    if (position == null) return;
    setState(_cameraController.resumeFollow);
    if (kDebugMode) {
      debugPrint('[NavCamera] follow=true source=gps_button');
    }
    if (_hasActiveNavigation) _moveMapToDriver(position, snapToRoute: true);
  }

  void _suspendFollowingForGesture() {
    if (!mounted || !_hasActiveNavigation) return;
    _followResume.cancel();
    if (!_followDriver) {
      _scheduleFollowResume();
      return;
    }
    _cameraAnimation.stop();
    _mapCameraBridge.cancelPending();
    setState(_cameraController.suspendFollow);
    if (kDebugMode) {
      debugPrint('[NavCamera] follow=false source=manual_gesture');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_mapCameraBridge.applyFlutterMapCamera(_mapController.camera));
    });
    _scheduleFollowResume();
  }

  void _scheduleFollowResume() {
    _followResume.cancel();
    if (_activeMapPointers > 0 || !mounted || !_hasActiveNavigation) return;
    _followResume.schedule();
  }

  void _mapPointerDown(PointerDownEvent _) {
    _activeMapPointers++;
    _followResume.cancel();
    _suspendFollowingForGesture();
  }

  void _mapPointerUp(PointerEvent _) {
    if (_activeMapPointers > 0) _activeMapPointers--;
    _scheduleFollowResume();
  }

  Future<void> _advanceOrder(String currentStatus) async {
    if (currentStatus == 'in_progress' &&
        hasPendingIntermediateStop(widget.orderData)) {
      try {
        final stops = await OrderWorkflowService().advanceOrderStop(
          widget.orderId,
        );
        if (!mounted) return;
        setState(() => widget.orderData['stops'] = stops);
        final position = _tracking.latestPosition;
        if (position != null) _requestRouteFrom(position);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).driverMapActionFailed),
            ),
          );
        }
      }
      return;
    }
    final nextStatus = {
      'accepted': 'driver_arrived',
      'driver_arrived': 'in_progress',
      'arrived': 'in_progress',
      'in_progress': 'completed',
    }[currentStatus];
    if (nextStatus == null) return;

    CompleteOrderResult? completeResult;
    try {
      if (nextStatus == 'completed') {
        completeResult = await OrderWorkflowService().completeOrder(
          widget.orderId,
        );
      } else {
        await OrderWorkflowService().transitionOrderStatus(
          orderId: widget.orderId,
          nextStatus: nextStatus,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).driverMapActionFailed),
          ),
        );
      }
      return;
    }
    if (nextStatus == 'completed') {
      _wakelockController.updateStatus(nextStatus);
      await _tracking.stopLocationUpdates(widget.orderId);
    } else if (nextStatus == 'in_progress') {
      final position = _tracking.latestPosition;
      if (position != null) {
        _requestRouteFrom(position, statusOverride: nextStatus);
      }
    }

    if (mounted && nextStatus == 'completed') {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => RatingDialog(
          targetUserId: widget.orderData['passengerId'],
          orderId: widget.orderId,
          isRatingDriver: false,
          targetLabel:
              OrderServiceType.fromValue(
                widget.orderData['serviceType'],
              ).isDelivery
              ? AppLocalizations.of(context).driverMapCustomer
              : null,
        ),
      );
      if (!mounted || completeResult == null) return;
      await _switchToActivatedNextOrder(completeResult);
    }
  }

  Future<void> _cancelCityOrder(String status) async {
    if (_cancellingCityOrder) return;
    final reason = status == 'in_progress'
        ? await showCityCancellationDialog(context, isDriver: true)
        : null;
    if (status == 'in_progress' && reason == null) return;
    if (!mounted) return;
    if (status != 'in_progress') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppLocalizations.of(dialogContext).cancelOrderTitle),
          content: Text(AppLocalizations.of(dialogContext).confirmCancelOrder),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppLocalizations.of(dialogContext).no),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppLocalizations.of(dialogContext).yesCancel),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _cancellingCityOrder = true);
    try {
      await OrderWorkflowService().cancelOrder(
        widget.orderId,
        reasonCode: reason?.code,
        reasonText: reason?.text,
      );
      await _finishCancelledCityOrder();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).cancelOrderFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancellingCityOrder = false);
    }
  }

  Future<void> _switchToActivatedNextOrder(
    CompleteOrderResult completeResult,
  ) async {
    if (!_nextOrderTransition.shouldSwitch(
      result: completeResult,
      serviceType: widget.orderData['serviceType'],
    )) {
      return;
    }
    final generation = _nextOrderTransition.beginOnce();
    final nextOrderId = completeResult.nextOrderId;
    if (generation == null || nextOrderId == null || !mounted) return;

    setState(() {
      _routeState.invalidate();
      _rerouteController.reset();
      _cameraController.reset();
      _routeTrimmer.reset();
      _nextOrderController.stop(clearCandidate: true);
    });

    try {
      final nextOrder = await _nextOrderTransition.loadAcceptedNext(
        nextOrderId: nextOrderId,
        generation: generation,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              DriverMapScreen(orderId: nextOrderId, orderData: nextOrder),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).driverMapNextLoadFailed),
        ),
      );
    }
  }

  Future<void> _acceptNextOrder() async {
    final accepted = await _nextOrderController.accept();
    if (!mounted) return;
    final message = accepted
        ? AppLocalizations.of(context).driverMapNextAccepted
        : AppLocalizations.of(context).driverMapNextUnavailable;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _offerNextOrder() async {
    final candidate = _nextOrderController.candidate;
    if (candidate == null) return;
    final controller = TextEditingController(
      text: candidate.passengerPrice.toString(),
    );
    final price = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext).driverMapOwnPrice),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(dialogContext).driverMapPriceLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(dialogContext).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()),
            ),
            child: Text(AppLocalizations.of(dialogContext).driverSendOffer),
          ),
        ],
      ),
    );
    controller.dispose();
    if (price == null || !mounted) return;
    try {
      OrderOfferService.validateOfferPrice(
        price,
        passengerPrice: candidate.passengerPrice,
      );
      await _offerService.submitOffer(orderId: candidate.orderId, price: price);
      _nextOrderController.markOfferSent(candidate.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).driverMapOfferSent),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).driverOfferFailed),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.orderData['status']?.toString() ?? 'accepted';
    final serviceType = OrderServiceType.fromValue(
      widget.orderData['serviceType'],
    );
    final actionLabel = switch (status) {
      'accepted' => AppLocalizations.of(context).driverMapArrivedAction,
      'driver_arrived' || 'arrived' =>
        serviceType.isDelivery
            ? AppLocalizations.of(context).driverMapPackageReceived
            : AppLocalizations.of(context).driverMapStartTrip,
      'in_progress' =>
        hasPendingIntermediateStop(widget.orderData)
            ? AppLocalizations.of(context).driverMapNextStop
            : serviceType.isDelivery
            ? AppLocalizations.of(context).driverMapCompleteDelivery
            : AppLocalizations.of(context).driverMapCompleteTrip,
      _ => null,
    };
    LatLng passengerFrom = LatLng(
      widget.orderData['fromLat'],
      widget.orderData['fromLng'],
    );
    LatLng passengerTo = LatLng(
      widget.orderData['toLat'],
      widget.orderData['toLng'],
    );
    final routeStops = orderStopsFromData(widget.orderData);

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (serviceType) {
          OrderServiceType.delivery => AppLocalizations.of(
            context,
          ).driverMapDeliveryTitle,
          OrderServiceType.intercity => AppLocalizations.of(
            context,
          ).driverMapIntercityTitle,
          OrderServiceType.city => AppLocalizations.of(
            context,
          ).driverMapCityTitle,
        }),
        backgroundColor: Colors.green,
      ),
      drawer: AppDrawer(mode: AppMode.driver, selectedServiceType: serviceType),
      body: Stack(
        children: [
          Listener(
            onPointerDown: _mapPointerDown,
            onPointerUp: _mapPointerUp,
            onPointerCancel: _mapPointerUp,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: passengerFrom,
                initialZoom: _navigationZoom,
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    const LatLng(-90, -180),
                    const LatLng(90, 180),
                  ),
                ),
                onMapReady: () {
                  _isMapReady = true;
                  final position = _tracking.latestPosition;
                  if (position != null &&
                      _followDriver &&
                      _hasActiveNavigation) {
                    _moveMapToDriver(position);
                  }
                },
                onMapEvent: (event) {
                  if (navigationMapEventDisablesFollow(event.source) &&
                      mounted) {
                    _suspendFollowingForGesture();
                  }
                },
              ),
              children: [
                TulparMapTileLayer(cameraBridge: _mapCameraBridge),
                if (_routeTrimmer.visibleRoute.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      TulparMapVisuals.routePolyline(
                        _routeTrimmer.visibleRoute,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    TulparMapVisuals.endpointMarker(
                      point: passengerFrom,
                      endpoint: TulparMapEndpoint.pickup,
                    ),
                    TulparMapVisuals.endpointMarker(
                      point: passengerTo,
                      endpoint: TulparMapEndpoint.destination,
                    ),
                    for (final stop in routeStops.where(
                      (stop) => !stop.isFinal,
                    ))
                      if (stop.raw['latitude'] is num &&
                          stop.raw['longitude'] is num)
                        TulparMapVisuals.stopMarker(
                          point: LatLng(
                            (stop.raw['latitude'] as num).toDouble(),
                            (stop.raw['longitude'] as num).toDouble(),
                          ),
                          number: stop.sequence + 1,
                          reached: stop.isReached,
                        ),
                  ],
                ),
                if (!navigationUsesFixedVehicleMarker(
                  following: _followDriver,
                  hasActiveNavigation: _hasActiveNavigation,
                ))
                  DriverLocationMarkerLayer(
                    key: const Key('driver_geographic_vehicle_marker'),
                    positionListenable: _tracking.positionListenable,
                    accuracyProvider: () => _tracking.latestAccuracyMeters,
                    headingProvider: () => _tracking.latestHeadingDegrees,
                    maximumAnimationDuration: const Duration(milliseconds: 800),
                    width: TulparMapVisuals.vehicleMarkerSize,
                    height: TulparMapVisuals.vehicleMarkerSize,
                    marker: TulparVehicleMarker(
                      isDelivery: serviceType.isDelivery,
                    ),
                  ),
              ],
            ),
          ),
          if (navigationUsesFixedVehicleMarker(
            following: _followDriver,
            hasActiveNavigation: _hasActiveNavigation,
          ))
            FixedNavigationVehicleMarker(
              gpsPosition: _tracking.latestPosition,
              marker: TulparVehicleMarker(isDelivery: serviceType.isDelivery),
            ),
          if (_routeState.steps.isNotEmpty)
            NavigationOverlay(
              steps: _routeState.steps,
              routeGeneration: _routeState.generation,
              routeDistanceMeters: _routeState.routeDistanceMeters,
              routeDurationSeconds: _routeState.routeDurationSeconds,
              positionListenable: _tracking.positionListenable,
              positionAccuracyProvider: () => _tracking.latestAccuracyMeters,
              isRerouting: _routeState.isRerouting,
              rerouteErrorMessage: _routeState.rerouteErrorMessage == null
                  ? null
                  : AppLocalizations.of(context).driverMapRerouteFailed,
              voiceController: _voiceController,
              voiceEnabled: appVoiceGuidanceSettings.enabled,
              voiceActive: _hasActiveNavigation,
              routePhase: status,
              routeTarget: _routeDestination(),
            ),
          if (_nextOrderController.candidate != null)
            Positioned(
              left: 15,
              right: 15,
              bottom: 185,
              child: NextOrderCandidateCard(
                candidate: _nextOrderController.candidate!,
                isAccepting: _nextOrderController.isAccepting,
                onAccept: _acceptNextOrder,
                onOffer: _offerNextOrder,
              ),
            ),
          Positioned(
            right: 16,
            bottom: _nextOrderController.candidate == null ? 190 : 365,
            child: FloatingActionButton.small(
              heroTag: 'follow-driver',
              onPressed: _resumeFollowing,
              backgroundColor: _followDriver ? Colors.blue : Colors.white,
              foregroundColor: _followDriver ? Colors.white : Colors.blue,
              child: const Icon(Icons.my_location),
            ),
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
                    InkWell(
                      key: const Key('driver_order_panel_toggle'),
                      onTap: () => setState(
                        () => _isOrderPanelExpanded = !_isOrderPanelExpanded,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${AddressLabelService.fromOrder(widget.orderData, Localizations.localeOf(context), const ['toAddress', 'destinationAddress'])} · ${serviceType.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            _isOrderPanelExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                          ),
                        ],
                      ),
                    ),
                    if (_isOrderPanelExpanded) ...[
                      OrderStopsView(orderData: widget.orderData),
                      const SizedBox(height: 10),
                      if (_trackingMessage != null)
                        Text(
                          _trackingMessage!,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      Text(
                        serviceType.isDelivery
                            ? AppLocalizations.of(
                                context,
                              ).driverMapCollectPackage(
                                AddressLabelService.fromOrder(
                                  widget.orderData,
                                  Localizations.localeOf(context),
                                  const ['fromAddress', 'pickupAddress'],
                                ),
                              )
                            : AppLocalizations.of(
                                context,
                              ).driverMapClientWaiting(
                                AddressLabelService.fromOrder(
                                  widget.orderData,
                                  Localizations.localeOf(context),
                                  const ['fromAddress', 'pickupAddress'],
                                ),
                              ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (DeliveryDetailsView.isDelivery(widget.orderData)) ...[
                        const SizedBox(height: 10),
                        DeliveryDetailsView(
                          orderData: widget.orderData,
                          enableRecipientCall: true,
                        ),
                      ],
                      if (IntercityDetailsView.isIntercity(
                        widget.orderData,
                      )) ...[
                        const SizedBox(height: 10),
                        IntercityDetailsView(orderData: widget.orderData),
                      ],
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: ChatUnreadBadge(orderId: widget.orderId),
                            label: Text(AppLocalizations.of(context).chat),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  orderId: widget.orderId,
                                  peerUserId: widget.orderData['passengerId']?.toString(),
                                  peerName: AppLocalizations.of(
                                    context,
                                  ).passenger,
                                ),
                              ),
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
                    ),
                    if (serviceType == OrderServiceType.city &&
                        const {
                          'accepted',
                          'driver_arriving',
                          'driver_arrived',
                          'arrived',
                          'in_progress',
                        }.contains(status))
                      TextButton.icon(
                        onPressed: _cancellingCityOrder
                            ? null
                            : () => _cancelCityOrder(status),
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text(AppLocalizations.of(context).cancelOrder),
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
