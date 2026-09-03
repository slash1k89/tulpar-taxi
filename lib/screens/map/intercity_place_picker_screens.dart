import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '/models/address_suggestion.dart';
import '/models/city.dart';
import '/services/geocoding_service.dart';
import '/services/map_point_address_resolver.dart';
import 'destination_picker_screen.dart';

class IntercityCityPickerScreen extends StatefulWidget {
  const IntercityCityPickerScreen({super.key, this.search});

  final Future<List<KazakhstanSettlement>> Function(String query)? search;

  @override
  State<IntercityCityPickerScreen> createState() =>
      _IntercityCityPickerScreenState();
}

class _IntercityCityPickerScreenState extends State<IntercityCityPickerScreen> {
  Timer? _debounce;
  List<KazakhstanSettlement> _results = const [];
  int _searchRequestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchRequestId++;
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    final requestId = ++_searchRequestId;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results =
          await (widget.search?.call(value) ??
              GeocodingService.searchKazakhstanSettlements(query: value));
      if (mounted && requestId == _searchRequestId) {
        setState(() => _results = results);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    appBar: AppBar(title: const Text('Выберите город')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('intercity_city_search'),
            autofocus: true,
            onChanged: _search,
            decoration: const InputDecoration(
              hintText: 'Город или населённый пункт',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: _results.length,
            itemBuilder: (_, index) {
              final city = _results[index];
              return ListTile(
                key: Key('intercity_city_result_${city.id}'),
                leading: const Icon(Icons.location_city),
                title: Text(city.name),
                subtitle: city.region.isEmpty ? null : Text(city.region),
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(context, city);
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class IntercityAddressPickerScreen extends StatefulWidget {
  const IntercityAddressPickerScreen({
    super.key,
    required this.settlement,
    required this.purpose,
    this.search,
    this.addressResolver,
    this.restrictedCity,
    this.cityPointValidator,
    this.locationProvider,
    this.showMapTiles = true,
    this.initialSelection,
  });

  final KazakhstanSettlement settlement;
  final MapPointPurpose purpose;
  final Future<List<AddressSuggestion>> Function(String, KazakhstanSettlement)?
  search;
  final MapPointAddressResolver? addressResolver;
  final City? restrictedCity;
  final Future<bool> Function(LatLng point, City city)? cityPointValidator;
  final Future<LatLng?> Function()? locationProvider;
  final bool showMapTiles;
  final MapPointSelection? initialSelection;

  @override
  State<IntercityAddressPickerScreen> createState() =>
      _IntercityAddressPickerScreenState();
}

class _IntercityAddressPickerScreenState
    extends State<IntercityAddressPickerScreen> {
  Timer? _debounce;
  List<AddressSuggestion> _results = const [];
  int _searchRequestId = 0;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialSelection?.address ?? '',
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchRequestId++;
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    final requestId = ++_searchRequestId;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results =
          await (widget.search?.call(value, widget.settlement) ??
              GeocodingService.searchKazakhstanAddress(
                query: value,
                settlement: widget.settlement,
              ));
      if (mounted && requestId == _searchRequestId) {
        setState(() => _results = results);
      }
    });
  }

  Future<void> _openMap() async {
    final selection = await Navigator.push<MapPointSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPointPickerScreen(
          initialCenter:
              widget.initialSelection?.point ??
              LatLng(widget.settlement.lat, widget.settlement.lng),
          initialAddress: widget.initialSelection?.address,
          purpose: widget.purpose,
          addressResolver: widget.addressResolver,
          restrictedCity: widget.restrictedCity,
          cityPointValidator: widget.cityPointValidator,
          locationProvider: widget.locationProvider,
          showMapTiles: widget.showMapTiles,
        ),
      ),
    );
    if (!mounted || selection == null) return;
    if (widget.restrictedCity != null) {
      Navigator.pop(
        context,
        MapPointSelection(
          point: selection.point,
          address: AddressSuggestion.shortAddressFromDisplayName(
            selection.address,
          ),
        ),
      );
      return;
    }
    final addressContainsSettlement = selection.address.toLowerCase().contains(
      widget.settlement.name.toLowerCase(),
    );
    if (addressContainsSettlement) {
      Navigator.pop(context, selection);
      return;
    }
    KazakhstanPointAddress? resolved;
    try {
      resolved = await GeocodingService.reverseGeocodeKazakhstanChecked(
        selection.point.latitude,
        selection.point.longitude,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось проверить город. Проверьте сеть и повторите.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (resolved == null ||
        !GeocodingService.settlementNamesMatch(
          resolved.settlement.name,
          widget.settlement.name,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Выберите точку в городе ${widget.settlement.name}.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      MapPointSelection(
        point: selection.point,
        address: AddressSuggestion.shortAddressFromDisplayName(
          resolved.address,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    appBar: AppBar(title: Text(widget.settlement.displayName)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('intercity_address_search'),
            controller: _searchController,
            autofocus: true,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Улица и дом',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                key: const Key('intercity_address_map_button'),
                tooltip: 'Выбрать на карте',
                onPressed: _openMap,
                icon: const Icon(Icons.map_outlined),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: _results.length,
            itemBuilder: (_, index) {
              final address = _results[index];
              return ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(address.shortAddress),
                subtitle: address.locality == null
                    ? null
                    : Text(address.locality!),
                onTap: () => Navigator.pop(
                  context,
                  MapPointSelection(
                    point: LatLng(address.lat, address.lng),
                    address: address.shortAddress,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
