import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '/models/city.dart';
import '/models/address_suggestion.dart';
import '/models/order_service_type.dart';
import '/services/city_service.dart';
import '/services/active_order_service.dart';
import '/services/order_creation_service.dart';
import '/services/route_service.dart';
import '/services/geocoding_service.dart';
import '/widgets/tulpar_date_picker.dart';
import '/services/map_point_address_resolver.dart';
import '/services/startup_diagnostics.dart';
import '/widgets/app_drawer.dart';
import '/widgets/city_selection_modal.dart';
import '/widgets/order_creation_error_snackbar.dart';
import '/widgets/tulpar_time_picker.dart';
import '/widgets/tulpar_map_tile_layer.dart';
import '/widgets/tulpar_map_visuals.dart';
import '/utils/formatters.dart';
import 'destination_picker_screen.dart';
import 'intercity_place_picker_screens.dart';
import 'order_tracking_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.orderCreationService,
    this.addressResolver,
    this.locationProvider,
    this.cityPointValidator,
    this.cityAddressSearch,
    this.settlementSearch,
    this.intercityAddressSearch,
    this.showMapTiles = true,
    this.serviceType = OrderServiceType.city,
  });

  final OrderCreationService? orderCreationService;
  final MapPointAddressResolver? addressResolver;
  final Future<LatLng?> Function()? locationProvider;
  final Future<bool> Function(LatLng point, City city)? cityPointValidator;
  final Future<List<AddressSuggestion>> Function(String query, City city)?
  cityAddressSearch;
  final Future<List<KazakhstanSettlement>> Function(String query)?
  settlementSearch;
  final Future<List<AddressSuggestion>> Function(
    String query,
    KazakhstanSettlement settlement,
  )?
  intercityAddressSearch;
  final bool showMapTiles;
  final OrderServiceType serviceType;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  late final OrderCreationService _orderCreationService;
  late final MapPointAddressResolver _addressResolver;

  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();

  City _selectedCity = availableCities.first;
  LatLng _mapCenter = availableCities.first.center;
  double _mapZoom = availableCities.first.mapZoom;

  LatLng? _fromPoint;
  LatLng? _toPoint;
  LatLng? _userLocation;
  List<LatLng> _routePoints = [];

  final TextEditingController _fromAddressController = TextEditingController();
  final TextEditingController _toAddressController = TextEditingController();
  final TextEditingController _fromSettlementController =
      TextEditingController();
  final TextEditingController _toSettlementController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _itemDescriptionController =
      TextEditingController();
  final TextEditingController _recipientNameController =
      TextEditingController();
  final TextEditingController _recipientPhoneController =
      TextEditingController();
  final TextEditingController _destinationApartmentController =
      TextEditingController();
  final TextEditingController _intercityCommentController =
      TextEditingController();
  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTime;
  int _passengerCount = 1;
  bool _hasLuggage = false;
  String? _priceErrorText;
  String get _serviceType => widget.serviceType.apiValue;

  List<AddressSuggestion> _fromSuggestions = [];
  List<AddressSuggestion> _toSuggestions = [];
  final List<KazakhstanSettlement> _fromSettlementSuggestions = [];
  final List<KazakhstanSettlement> _toSettlementSuggestions = [];
  KazakhstanSettlement? _fromSettlement;
  KazakhstanSettlement? _toSettlement;
  Timer? _debounceFrom;
  Timer? _debounceTo;
  Timer? _debounceFromSettlement;
  Timer? _debounceToSettlement;
  Timer? _mapReverseGeocodeDebounce;
  int _reverseGeocodeRequestId = 0;

  bool _isLoadingRoute = false;
  bool _isCreatingOrder = false;
  bool _isOrderPanelExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupDiagnostics.mark('map screen ready');
    });
    _orderCreationService =
        widget.orderCreationService ?? OrderCreationService();
    _addressResolver = widget.addressResolver ?? MapPointAddressResolver();
    final defaultDeparture = kazakhstanWallClock().add(
      const Duration(minutes: 15),
    );
    _scheduledDate = DateTime(
      defaultDeparture.year,
      defaultDeparture.month,
      defaultDeparture.day,
    );
    _scheduledTime = TimeOfDay(
      hour: defaultDeparture.hour,
      minute: defaultDeparture.minute,
    );
    _applyCurrentMinimumPrice();
    unawaited(_initializeMap());
  }

  Future<void> _initializeMap() async {
    await _loadSavedCity();
    if (!widget.serviceType.isIntercity) {
      await _determinePosition(showOutsideMessage: false);
    }
  }

  int? _readEnteredPrice() =>
      int.tryParse(_priceController.text.replaceAll(RegExp(r'\D'), ''));

  void _applyCurrentMinimumPrice() {
    if (widget.serviceType.isIntercity) return;
    final proposedPrice = _readEnteredPrice() ?? 0;
    final adjustedPrice = _orderCreationService.priceWithCurrentMinimum(
      proposedPrice,
    );
    if (adjustedPrice != proposedPrice) {
      _priceController.text = adjustedPrice.toString();
    }
  }

  String? _priceValidationMessage(int? proposedPrice) {
    if (_serviceType == 'delivery' || _serviceType == 'intercity') {
      if (proposedPrice == null || proposedPrice <= 0) {
        return _serviceType == 'delivery'
            ? 'Укажите цену доставки.'
            : 'Укажите цену поездки.';
      }
      return null;
    }
    final minimumFare = _orderCreationService.currentMinimumFare;
    if (proposedPrice == null || proposedPrice < minimumFare) {
      return _orderCreationService.minimumFareMessage(minimumFare);
    }
    return null;
  }

  @override
  void dispose() {
    _fromAddressController.dispose();
    _toAddressController.dispose();
    _fromSettlementController.dispose();
    _toSettlementController.dispose();
    _priceController.dispose();
    _itemDescriptionController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _destinationApartmentController.dispose();
    _intercityCommentController.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    _debounceFrom?.cancel();
    _debounceTo?.cancel();
    _debounceFromSettlement?.cancel();
    _debounceToSettlement?.cancel();
    _mapReverseGeocodeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedCity() async {
    final savedCity = await CityService.getSelectedCityDetails();
    if (!mounted) return;

    setState(() {
      _selectedCity = savedCity;
      _mapCenter = savedCity.center;
      _mapZoom = savedCity.mapZoom;
      if (widget.serviceType.isIntercity && _fromSettlement == null) {
        _fromSettlement = KazakhstanSettlement.fromCity(savedCity);
        _fromSettlementController.text = _fromSettlement!.displayName;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(savedCity.center, savedCity.mapZoom);
      }
    });
  }

  Future<void> _determinePosition({bool showOutsideMessage = true}) async {
    LatLng? point;
    if (widget.locationProvider != null) {
      try {
        point = await widget.locationProvider!().timeout(
          const Duration(seconds: 12),
        );
      } on TimeoutException {
        point = null;
      }
    } else {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 12),
        );
      } on TimeoutException {
        if (mounted && showOutsideMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Не удалось быстро определить местоположение. '
                'Выберите адрес вручную.',
              ),
            ),
          );
        }
        return;
      }
      point = LatLng(position.latitude, position.longitude);
    }
    if (!mounted || point == null) return;

    if (!widget.serviceType.isIntercity && !_selectedCity.contains(point)) {
      _mapController.move(_selectedCity.center, _selectedCity.mapZoom);
      if (showOutsideMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ваше местоположение вне города ${_selectedCity.name}.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _mapCenter = point!;
      _mapZoom = 15.0;
      _userLocation = point;
    });
    _mapController.move(point, 15.0);
    await _selectPickupAt(point);
  }

  Future<bool> _isAllowedCityPoint(LatLng point) async {
    if (!_selectedCity.contains(point)) return false;
    return widget.cityPointValidator?.call(point, _selectedCity) ??
        GeocodingService.pointBelongsToCity(point, _selectedCity);
  }

  Future<void> _selectPickupAt(LatLng point) async {
    final requestId = ++_reverseGeocodeRequestId;
    String? resolvedCityAddress;

    var isAllowed = true;
    if (!widget.serviceType.isIntercity) {
      if (widget.cityPointValidator == null && widget.addressResolver == null) {
        if (!_selectedCity.contains(point)) {
          isAllowed = false;
        } else {
          try {
            final resolved =
                await GeocodingService.reverseGeocodeKazakhstanChecked(
                  point.latitude,
                  point.longitude,
                );
            isAllowed =
                resolved != null &&
                GeocodingService.settlementNamesMatch(
                  resolved.settlement.name,
                  _selectedCity.name,
                );
            resolvedCityAddress = resolved?.address;
          } catch (error) {
            debugPrint('[ReverseGeocoding] city validation error=$error');
            isAllowed = false;
          }
        }
      } else {
        isAllowed = await _isAllowedCityPoint(point);
      }
    }

    if (!isAllowed) {
      if (!mounted || requestId != _reverseGeocodeRequestId) return;
      _mapController.move(_selectedCity.center, _selectedCity.mapZoom);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Выберите точку в городе ${_selectedCity.name}.'),
        ),
      );
      return;
    }

    setState(() {
      _mapCenter = point;
      _fromPoint = point;
      _fromAddressController.text = 'Определение адреса...';
      _fromSuggestions.clear();
      _routePoints.clear();
    });

    if (widget.serviceType.isIntercity) {
      final resolved = await GeocodingService.reverseGeocodeKazakhstan(
        point.latitude,
        point.longitude,
      );
      if (!mounted || requestId != _reverseGeocodeRequestId) return;
      if (resolved == null) {
        setState(() {
          _fromPoint = null;
          _fromAddressController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Выберите точку на территории Казахстана.'),
          ),
        );
        return;
      }
      setState(() {
        _fromSettlement = resolved.settlement;
        _fromSettlementController.text = resolved.settlement.displayName;
        _fromAddressController.text =
            AddressSuggestion.shortAddressFromDisplayName(resolved.address);
      });
      if (_toPoint != null) await _buildRoute();
      return;
    }

    final resolved = resolvedCityAddress == null
        ? await _addressResolver.resolve(point)
        : ResolvedMapPoint(point: point, address: resolvedCityAddress);

    if (!mounted || requestId != _reverseGeocodeRequestId) return;

    setState(
      () => _fromAddressController.text =
          AddressSuggestion.shortAddressFromDisplayName(resolved.address),
    );

    if (_toPoint != null) await _buildRoute();
  }

  void _handleMapEvent(MapEvent event) {
    if (event is! MapEventMoveEnd) return;
    if (event.source == MapEventSource.mapController ||
        event.source == MapEventSource.fitCamera ||
        event.source == MapEventSource.nonRotatedSizeChange) {
      return;
    }

    _mapReverseGeocodeDebounce?.cancel();
    _mapReverseGeocodeDebounce = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_selectPickupAt(event.camera.center)),
    );
  }

  void _selectSettlement(
    KazakhstanSettlement settlement, {
    required bool isPickup,
  }) {
    setState(() {
      if (isPickup) {
        _fromSettlement = settlement;
        _fromSettlementController.text = settlement.displayName;
        _fromSettlementSuggestions.clear();
        _fromAddressController.clear();
        _fromPoint = null;
      } else {
        _toSettlement = settlement;
        _toSettlementController.text = settlement.displayName;
        _toSettlementSuggestions.clear();
        _toAddressController.clear();
        _toPoint = null;
      }
      _routePoints.clear();
      _mapCenter = LatLng(settlement.lat, settlement.lng);
      _mapZoom = 13;
    });
    _mapController.move(_mapCenter, _mapZoom);
  }

  Future<void> _openSettlementPicker({required bool isPickup}) async {
    final settlement = await Navigator.push<KazakhstanSettlement>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            IntercityCityPickerScreen(search: widget.settlementSearch),
      ),
    );
    if (settlement != null) _selectSettlement(settlement, isPickup: isPickup);
  }

  Future<void> _openIntercityAddressPicker({required bool isPickup}) async {
    final settlement = isPickup ? _fromSettlement : _toSettlement;
    if (settlement == null) return;
    final selection = await Navigator.push<MapPointSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => IntercityAddressPickerScreen(
          settlement: settlement,
          purpose: isPickup
              ? MapPointPurpose.pickup
              : MapPointPurpose.destination,
          search: widget.intercityAddressSearch,
          addressResolver: _addressResolver,
          locationProvider: widget.locationProvider,
          showMapTiles: widget.showMapTiles,
        ),
      ),
    );
    if (!mounted || selection == null) return;
    setState(() {
      if (isPickup) {
        _fromPoint = selection.point;
        _fromAddressController.text = selection.address;
      } else {
        _toPoint = selection.point;
        _toAddressController.text = selection.address;
      }
    });
    _mapController.move(selection.point, 15);
    if (_fromPoint != null && _toPoint != null) await _buildRoute();
  }

  Future<void> _openUnifiedAddressPicker({required bool isPickup}) async {
    if (widget.serviceType.isIntercity) {
      await _openIntercityAddressPicker(isPickup: isPickup);
      return;
    }
    final settlement = KazakhstanSettlement.fromCity(_selectedCity);
    final selection = await Navigator.push<MapPointSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => IntercityAddressPickerScreen(
          settlement: settlement,
          purpose: isPickup
              ? MapPointPurpose.pickup
              : MapPointPurpose.destination,
          search: (query, _) =>
              widget.cityAddressSearch?.call(query, _selectedCity) ??
              GeocodingService.searchCityAddress(
                query: query,
                city: _selectedCity,
              ),
          addressResolver: _addressResolver,
          restrictedCity: _selectedCity,
          cityPointValidator: widget.cityPointValidator,
          locationProvider: widget.locationProvider,
          showMapTiles: widget.showMapTiles,
        ),
      ),
    );
    if (!mounted || selection == null) return;
    setState(() {
      if (isPickup) {
        _fromPoint = selection.point;
        _fromAddressController.text = selection.address;
      } else {
        _toPoint = selection.point;
        _toAddressController.text = selection.address;
      }
    });
    _mapController.move(selection.point, 15);
    if (_fromPoint != null && _toPoint != null) await _buildRoute();
  }

  Widget _buildSettlementField({required bool isPickup}) {
    final controller = isPickup
        ? _fromSettlementController
        : _toSettlementController;
    final suggestions = isPickup
        ? _fromSettlementSuggestions
        : _toSettlementSuggestions;
    return Column(
      children: [
        InkWell(
          key: Key(
            isPickup
                ? 'intercity_from_settlement_field'
                : 'intercity_to_settlement_field',
          ),
          onTap: () => _openSettlementPicker(isPickup: isPickup),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: isPickup ? 'Город отправления' : 'Город назначения',
              prefixIcon: Icon(
                isPickup ? Icons.my_location : Icons.location_city,
                color: isPickup ? Colors.green : Colors.red,
              ),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              border: const OutlineInputBorder(),
            ),
            child: Text(
              controller.text.isEmpty ? 'Выберите город' : controller.text,
            ),
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Colors.amber),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final settlement = suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_city),
                  title: Text(settlement.name),
                  subtitle: settlement.region.isEmpty
                      ? null
                      : Text(settlement.region),
                  onTap: () =>
                      _selectSettlement(settlement, isPickup: isPickup),
                );
              },
            ),
          ),
      ],
    );
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

  Future<void> _selectTravelDate() async {
    final now = kazakhstanWallClock();
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showTulparDatePicker(
      context: context,
      initialDate: _scheduledDate.isBefore(today) ? today : _scheduledDate,
      firstDate: today,
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (selected != null && mounted) {
      setState(() {
        _scheduledDate = selected;
        if (!_scheduledAt.isAfter(DateTime.now().toUtc())) {
          final next = kazakhstanWallClock().add(const Duration(minutes: 15));
          _scheduledTime = TimeOfDay(hour: next.hour, minute: next.minute);
          _scheduledDate = DateTime(next.year, next.month, next.day);
        }
      });
    }
  }

  Future<void> _selectTravelTime() async {
    final selected = await showTulparTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (selected != null && mounted) {
      final candidate = kazakhstanDepartureUtc(
        year: _scheduledDate.year,
        month: _scheduledDate.month,
        day: _scheduledDate.day,
        hour: selected.hour,
        minute: selected.minute,
      );
      if (!candidate.isAfter(DateTime.now().toUtc())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите будущее время.')),
        );
        return;
      }
      setState(() => _scheduledTime = selected);
    }
  }

  DateTime get _scheduledAt => kazakhstanDepartureUtc(
    year: _scheduledDate.year,
    month: _scheduledDate.month,
    day: _scheduledDate.day,
    hour: _scheduledTime.hour,
    minute: _scheduledTime.minute,
  );

  String get _scheduledDateLabel =>
      '${_scheduledDate.day.toString().padLeft(2, '0')}.'
      '${_scheduledDate.month.toString().padLeft(2, '0')}.'
      '${_scheduledDate.year}';

  String get _scheduledTimeLabel =>
      formatHourMinute24(_scheduledTime.hour, _scheduledTime.minute);

  Future<void> _submitOrder() async {
    if (_isCreatingOrder) return;

    if (widget.serviceType.isIntercity &&
        (_fromSettlement == null || _toSettlement == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала выберите города отправления и назначения.'),
        ),
      );
      return;
    }

    if (_fromPoint == null || _toPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите точки A и B на карте или выберите из списка'),
        ),
      );
      return;
    }

    final priceInt = _readEnteredPrice();
    final priceError = _priceValidationMessage(priceInt);
    if (priceError != null) {
      setState(() => _priceErrorText = priceError);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(priceError)));
      return;
    }

    DeliveryOrderDetails? delivery;
    if (_serviceType == 'delivery') {
      delivery = DeliveryOrderDetails(
        itemDescription: _itemDescriptionController.text,
        recipientName: _recipientNameController.text,
        recipientPhone: _recipientPhoneController.text,
        destinationApartment: _destinationApartmentController.text,
      );
      try {
        delivery.validate();
      } on OrderCreationException catch (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.userMessage)));
        return;
      }
    }

    IntercityOrderDetails? intercity;
    if (_serviceType == 'intercity') {
      intercity = IntercityOrderDetails(
        scheduledAt: _scheduledAt,
        passengerCount: _passengerCount,
        hasLuggage: _hasLuggage,
        comment: _intercityCommentController.text,
      );
      try {
        intercity.validate();
      } on OrderCreationException catch (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.userMessage)));
        return;
      }
    }

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
            price: priceInt!,
            fromPoint: _fromPoint!,
            toPoint: _toPoint!,
            cityId: _selectedCity.id,
            serviceType: _serviceType,
            delivery: delivery,
            intercity: intercity,
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
      if (error is OrderCreationException &&
          error.failure == OrderCreationFailure.belowMinimumFare) {
        final minimumFare =
            error.minimumFare ?? _orderCreationService.currentMinimumFare;
        if ((_readEnteredPrice() ?? 0) < minimumFare) {
          _priceController.text = minimumFare.toString();
        }
        if (mounted) {
          setState(() => _priceErrorText = error.userMessage);
        }
      }
      if (error is OrderCreationException &&
          error.failure == OrderCreationFailure.activeOrderExists) {
        final activeOrder = await ActiveOrderService().findCurrentOrder();
        if (!mounted) return;
        if (activeOrder != null && !activeOrder.isDriver) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingScreen(
                orderId: activeOrder.orderId,
                initialOrderData: activeOrder.data,
              ),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Найдена устаревшая привязка заказа. Она не удалена автоматически. '
              'Обратитесь к администратору для проверки.',
            ),
          ),
        );
        return;
      }
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
          onTap: widget.serviceType.isIntercity ? null : _openCitySelector,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.serviceType.isIntercity
                      ? Icons.route
                      : Icons.location_on,
                  size: 20,
                  color: Colors.amber,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.serviceType.isIntercity
                      ? widget.serviceType.title
                      : '${widget.serviceType.title} — ${_selectedCity.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!widget.serviceType.isIntercity)
                  const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        centerTitle: true,
      ),
      drawer: AppDrawer(
        mode: AppMode.passenger,
        selectedServiceType: widget.serviceType,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _mapZoom,
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
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [TulparMapVisuals.routePolyline(_routePoints)],
                ),
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    TulparMapVisuals.userLocationMarker(
                      key: const Key('passenger_user_location_marker'),
                      point: _userLocation!,
                    ),
                  if (_toPoint != null)
                    TulparMapVisuals.endpointMarker(
                      key: const Key('passenger_destination_marker'),
                      point: _toPoint!,
                      endpoint: TulparMapEndpoint.destination,
                    ),
                ],
              ),
            ],
          ),

          IgnorePointer(child: Center(child: const TulparSelectionPin())),

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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
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
                        InkWell(
                          key: const Key('passenger_order_panel_toggle'),
                          onTap: () => setState(
                            () =>
                                _isOrderPanelExpanded = !_isOrderPanelExpanded,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(widget.serviceType.icon, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.serviceType.title,
                                      key: const Key(
                                        'order_form_service_title',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
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
                          const SizedBox(height: 8),
                          if (widget.serviceType.isIntercity) ...[
                            _buildSettlementField(isPickup: true),
                            const SizedBox(height: 8),
                          ],
                          // Поле Откуда
                          TextField(
                            key: const Key('from_address_field'),
                            controller: _fromAddressController,
                            focusNode: _fromFocusNode,
                            enabled:
                                !widget.serviceType.isIntercity ||
                                _fromSettlement != null,
                            readOnly: true,
                            onTap: () =>
                                _openUnifiedAddressPicker(isPickup: true),
                            decoration: InputDecoration(
                              labelText: 'Точный адрес отправления',
                              hintText: 'Выберите адрес',
                              prefixIcon: const Icon(
                                Icons.my_location,
                                color: Colors.green,
                              ),
                              suffixIcon: const Icon(Icons.chevron_right),
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
                                    final settlement = _fromSettlement;
                                    final results =
                                        widget.serviceType.isIntercity
                                        ? settlement == null
                                              ? <AddressSuggestion>[]
                                              : await (widget
                                                        .intercityAddressSearch
                                                        ?.call(
                                                          val,
                                                          settlement,
                                                        ) ??
                                                    GeocodingService.searchKazakhstanAddress(
                                                      query: val,
                                                      settlement: settlement,
                                                    ))
                                        : await (widget.cityAddressSearch?.call(
                                                val,
                                                _selectedCity,
                                              ) ??
                                              GeocodingService.searchCityAddress(
                                                query: val,
                                                city: _selectedCity,
                                              ));
                                    if (mounted) {
                                      setState(
                                        () => _fromSuggestions = results.toList(
                                          growable: true,
                                        ),
                                      );
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
                                      if (_fromPoint != null &&
                                          _toPoint != null) {
                                        _buildRoute();
                                      }
                                    },
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 8),

                          if (widget.serviceType.isIntercity) ...[
                            _buildSettlementField(isPickup: false),
                            const SizedBox(height: 8),
                          ],
                          // Поле Куда
                          TextField(
                            key: const Key('to_address_field'),
                            controller: _toAddressController,
                            focusNode: _toFocusNode,
                            enabled:
                                !widget.serviceType.isIntercity ||
                                _toSettlement != null,
                            readOnly: true,
                            onTap: () =>
                                _openUnifiedAddressPicker(isPickup: false),
                            decoration: InputDecoration(
                              labelText: widget.serviceType.isDelivery
                                  ? 'Точный адрес доставки'
                                  : 'Точный адрес назначения',
                              hintText: 'Выберите адрес',
                              prefixIcon: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                              ),
                              suffixIcon: const Icon(Icons.chevron_right),
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
                                    final settlement = _toSettlement;
                                    final results =
                                        widget.serviceType.isIntercity
                                        ? settlement == null
                                              ? <AddressSuggestion>[]
                                              : await (widget
                                                        .intercityAddressSearch
                                                        ?.call(
                                                          val,
                                                          settlement,
                                                        ) ??
                                                    GeocodingService.searchKazakhstanAddress(
                                                      query: val,
                                                      settlement: settlement,
                                                    ))
                                        : await (widget.cityAddressSearch?.call(
                                                val,
                                                _selectedCity,
                                              ) ??
                                              GeocodingService.searchCityAddress(
                                                query: val,
                                                city: _selectedCity,
                                              ));
                                    if (mounted) {
                                      setState(
                                        () => _toSuggestions = results.toList(
                                          growable: true,
                                        ),
                                      );
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
                                      if (_fromPoint != null &&
                                          _toPoint != null) {
                                        _buildRoute();
                                      }
                                    },
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 8),

                          if (_serviceType == 'delivery') ...[
                            TextField(
                              key: const Key(
                                'delivery_destination_apartment_field',
                              ),
                              controller: _destinationApartmentController,
                              keyboardType: TextInputType.text,
                              maxLength: 30,
                              decoration: const InputDecoration(
                                labelText:
                                    'Квартира получателя (необязательно)',
                                hintText: '25',
                                prefixIcon: Icon(Icons.apartment_outlined),
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const Key('delivery_item_description_field'),
                              controller: _itemDescriptionController,
                              textCapitalization: TextCapitalization.sentences,
                              maxLength: 500,
                              decoration: const InputDecoration(
                                labelText: 'Описание посылки',
                                hintText: 'Например: документы',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const Key('delivery_recipient_name_field'),
                              controller: _recipientNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Имя получателя',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const Key('delivery_recipient_phone_field'),
                              controller: _recipientPhoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [RuPhoneInputFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Телефон получателя',
                                hintText: '+7 ...',
                                prefixIcon: Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          if (_serviceType == 'intercity') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    key: const Key('intercity_date_field'),
                                    onPressed: _selectTravelDate,
                                    icon: const Icon(Icons.calendar_today),
                                    label: Text(_scheduledDateLabel),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    key: const Key('intercity_time_field'),
                                    onPressed: _selectTravelTime,
                                    icon: const Icon(Icons.schedule),
                                    label: Text(_scheduledTimeLabel),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              key: const Key('intercity_passenger_count_field'),
                              initialValue: _passengerCount,
                              decoration: const InputDecoration(
                                labelText: 'Количество пассажиров',
                                prefixIcon: Icon(Icons.people_outline),
                                border: OutlineInputBorder(),
                              ),
                              items: List.generate(
                                8,
                                (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text('${index + 1}'),
                                ),
                              ),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _passengerCount = value);
                                }
                              },
                            ),
                            SwitchListTile(
                              key: const Key('intercity_luggage_field'),
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Есть багаж'),
                              secondary: const Icon(Icons.luggage),
                              value: _hasLuggage,
                              onChanged: (value) {
                                setState(() => _hasLuggage = value);
                              },
                            ),
                            TextField(
                              key: const Key('intercity_comment_field'),
                              controller: _intercityCommentController,
                              textCapitalization: TextCapitalization.sentences,
                              maxLength: 500,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Комментарий (необязательно)',
                                prefixIcon: Icon(Icons.comment_outlined),
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _priceErrorText = _priceValidationMessage(
                                  _readEnteredPrice(),
                                );
                              });
                            },
                            decoration: InputDecoration(
                              labelText: 'Ваша цена (₸)',
                              errorText: _priceErrorText,
                              prefixIcon: const Icon(
                                Icons.attach_money,
                                color: Colors.amber,
                              ),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
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
                                  : Text(
                                      switch (_serviceType) {
                                        'delivery' => 'Заказать доставку',
                                        'intercity' => 'Заказать межгород',
                                        _ => 'Заказать такси',
                                      },
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
