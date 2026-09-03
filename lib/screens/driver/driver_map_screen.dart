import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/order_service_type.dart';
import '../../models/next_order.dart';
import '../../screens/chat/chat_screen.dart';
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
import '../../services/driver_next_order_transition.dart';
import '../../services/next_order_candidate_controller.dart';
import '../../services/tulpar_api_client.dart';
import '../../services/navigation_reroute_controller.dart';
import '../../services/navigation_camera_controller.dart';
import '../../services/navigation_route_trimmer.dart';
import '../../services/navigation_voice_service.dart';
import '../../services/voice_guidance_settings.dart';
import '../../models/navigation_step.dart';

LatLng driverRouteDestination(
  Map<String, dynamic> orderData, {
  String? statusOverride,
}) {
  final status =
      statusOverride ?? orderData['status']?.toString() ?? 'accepted';
  final useDestination = status == 'in_progress';
  return LatLng(
    (orderData[useDestination ? 'toLat' : 'fromLat'] as num).toDouble(),
    (orderData[useDestination ? 'toLng' : 'fromLng'] as num).toDouble(),
  );
}

bool driverRouteContextChanged({
  required String oldOrderId,
  required String newOrderId,
  required Map<String, dynamic> oldOrderData,
  required Map<String, dynamic> newOrderData,
}) =>
    oldOrderId != newOrderId ||
    oldOrderData['status']?.toString() != newOrderData['status']?.toString();

bool driverStatusSupportsNavigation(Object? status) => {
  'accepted',
  'driver_arrived',
  'arrived',
  'in_progress',
}.contains(status?.toString());

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
    with SingleTickerProviderStateMixin {
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
  late final NextOrderCandidateController _nextOrderController;
  late final DriverNextOrderTransition _nextOrderTransition;
  final OrderOfferService _offerService = OrderOfferService();
  String? _trackingMessage;
  bool get _followDriver => _cameraController.following;
  late final AnimationController _cameraAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  LatLng? _cameraPosition;
  bool _isMapReady = false;
  bool _isOrderPanelExpanded = true;

  static const double _navigationZoom = 16.5;

  @override
  void initState() {
    super.initState();
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
      setState(() => _trackingMessage = result.message);
    }
  }

  @override
  void dispose() {
    _cameraAnimation.dispose();
    _tracking.positionListenable.removeListener(_handleDriverPosition);
    appVoiceGuidanceSettings.removeListener(_handleVoiceSettingChanged);
    _nextOrderController.removeListener(_handleNextOrderChanged);
    _nextOrderController.dispose();
    _nextOrderTransition.invalidate();
    unawaited(_tracking.dispose(widget.orderId));
    unawaited(_voiceController.dispose());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DriverMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final orderChanged = oldWidget.orderId != widget.orderId;
    if (orderChanged) {
      unawaited(_restartTracking(oldWidget.orderId));
    }
    _nextOrderController.updateOrder(widget.orderData);
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
        _cameraController.reset();
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

  bool get _hasActiveNavigation =>
      driverStatusSupportsNavigation(widget.orderData['status']) &&
      _routeState.geometry.isNotEmpty;

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

  void _requestRouteFrom(
    LatLng driverPosition, {
    String? statusOverride,
    bool isReroute = false,
  }) {
    if (isReroute && _routeState.isLoading) return;
    _cameraController.reset();
    final destination = _routeDestination(statusOverride);
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
        destination: destination,
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
    required LatLng destination,
    required String orderId,
    required bool isReroute,
  }) async {
    try {
      final result = await RouteService.fetchRoute(
        startLat: driverPosition.latitude,
        startLng: driverPosition.longitude,
        destLat: destination.latitude,
        destLng: destination.longitude,
      );

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

  void _moveMapToDriver(LatLng position) {
    final cameraUpdate = _cameraController.update(
      position: position,
      accuracyMeters: _tracking.latestAccuracyMeters,
      reportedHeadingDegrees: _tracking.latestHeadingDegrees,
      speedMetersPerSecond: _tracking.latestSpeedMetersPerSecond,
      routeAhead: _routeTrimmer.visibleRoute,
    );
    if (!cameraUpdate.accepted) return;
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
          offset: Offset(0, _mapController.camera.nonRotatedSize.height / 7),
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
            },
            onError: (Object _) {
              _cameraAnimation.removeListener(tick);
            },
          );
    });
  }

  void _resumeFollowing() {
    final position = _tracking.latestPosition;
    if (position == null) return;
    setState(_cameraController.resumeFollow);
    if (_hasActiveNavigation) _moveMapToDriver(position);
  }

  Future<void> _advanceOrder(String currentStatus) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (nextStatus == 'completed') {
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
              ? 'заказчика'
              : null,
        ),
      );
      if (!mounted || completeResult == null) return;
      await _switchToActivatedNextOrder(completeResult);
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
        const SnackBar(
          content: Text('Следующий заказ принят. Не удалось загрузить данные.'),
        ),
      );
    }
  }

  Future<void> _acceptNextOrder() async {
    final accepted = await _nextOrderController.accept();
    if (!mounted) return;
    final message = accepted
        ? 'Следующий заказ принят'
        : (_nextOrderController.lastError ?? 'Заказ уже недоступен');
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
        title: const Text('Своя цена'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Цена, ₸'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()),
            ),
            child: const Text('Отправить'),
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
          const SnackBar(content: Text('Предложение отправлено пассажиру')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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
      'accepted' => 'Я на месте',
      'driver_arrived' || 'arrived' =>
        serviceType.isDelivery ? 'Посылка получена' : 'Начать поездку',
      'in_progress' =>
        serviceType.isDelivery ? 'Завершить доставку' : 'Завершить поездку',
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

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (serviceType) {
          OrderServiceType.delivery => 'Выполнение доставки',
          OrderServiceType.intercity => 'Междугородняя поездка',
          OrderServiceType.city => 'Выполнение заказа',
        }),
        backgroundColor: Colors.green,
      ),
      drawer: AppDrawer(mode: AppMode.driver, selectedServiceType: serviceType),
      body: Stack(
        children: [
          FlutterMap(
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
                if (position != null && _followDriver && _hasActiveNavigation) {
                  _moveMapToDriver(position);
                }
              },
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _followDriver && mounted) {
                  _cameraAnimation.stop();
                  setState(_cameraController.suspendFollow);
                }
              },
              // FlutterMap.rotateRaw emits an event but does not call
              // onPositionChanged, so handle a rotation-only gesture too.
              onMapEvent: (event) {
                if (event is MapEventRotate &&
                    event.source != MapEventSource.mapController &&
                    _followDriver &&
                    mounted) {
                  _cameraAnimation.stop();
                  setState(_cameraController.suspendFollow);
                }
              },
            ),
            children: [
              const TulparMapTileLayer(),
              if (_routeTrimmer.visibleRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    TulparMapVisuals.routePolyline(_routeTrimmer.visibleRoute),
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
                ],
              ),
              if (!_followDriver || !_hasActiveNavigation)
                DriverLocationMarkerLayer(
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
          if (_followDriver && _hasActiveNavigation)
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Positioned(
                        left:
                            (constraints.maxWidth -
                                TulparMapVisuals.vehicleMarkerSize) /
                            2,
                        top:
                            constraints.maxHeight * (0.5 + 1 / 7) -
                            TulparMapVisuals.vehicleMarkerSize / 2,
                        width: TulparMapVisuals.vehicleMarkerSize,
                        height: TulparMapVisuals.vehicleMarkerSize,
                        child: TulparVehicleMarker(
                          isDelivery: serviceType.isDelivery,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
              rerouteErrorMessage: _routeState.rerouteErrorMessage,
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
                              '${widget.orderData['toAddress'] ?? ''} · ${serviceType.title}',
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
                      if (_trackingMessage != null)
                        Text(
                          _trackingMessage!,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      Text(
                        serviceType.isDelivery
                            ? 'Заберите посылку: ${widget.orderData['fromAddress']}'
                            : 'Клиент ожидает: ${widget.orderData['fromAddress']}',
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
