import 'package:flutter/material.dart';

import '../../models/intercity_ride_search_draft.dart';
import '../../services/city_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/intercity_ride_service.dart';
import '../../utils/intercity_ride_formatters.dart';
import '../../widgets/intercity_ride_fields.dart';
import '../../widgets/tulpar_date_picker.dart';
import 'intercity_ride_results_screen.dart';
import '../../l10n/generated/app_localizations.dart';

class IntercityRideSearchScreen extends StatefulWidget {
  const IntercityRideSearchScreen({
    super.key,
    this.repository,
    this.initialOrigin,
    this.defaultCityLoader,
  });

  final IntercityRideRepository? repository;
  final KazakhstanSettlement? initialOrigin;
  final Future<KazakhstanSettlement> Function()? defaultCityLoader;

  @override
  State<IntercityRideSearchScreen> createState() =>
      _IntercityRideSearchScreenState();
}

class _IntercityRideSearchScreenState extends State<IntercityRideSearchScreen> {
  late final IntercityRideRepository _repository;
  KazakhstanSettlement? _origin;
  KazakhstanSettlement? _destination;
  late DateTime _travelDate;
  int _seats = 1;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IntercityRideService();
    _origin = widget.initialOrigin;
    _travelDate = DateUtils.dateOnly(DateTime.now());
    if (_origin == null) _loadDefaultOrigin();
  }

  Future<void> _loadDefaultOrigin() async {
    final settlement =
        await (widget.defaultCityLoader?.call() ??
            CityService.getSelectedCityDetails().then(
              KazakhstanSettlement.fromCity,
            ));
    if (mounted && _origin == null) setState(() => _origin = settlement);
  }

  Future<void> _selectDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showTulparDatePicker(
      context: context,
      initialDate: _travelDate.isBefore(today) ? today : _travelDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (selected != null && mounted) setState(() => _travelDate = selected);
  }

  void _search() {
    final origin = _origin;
    final destination = _destination;
    final today = DateUtils.dateOnly(DateTime.now());
    String? message;
    if (origin == null || destination == null) {
      message = AppLocalizations.of(context).intercityChooseCities;
    } else if (_cityKey(origin.name) == _cityKey(destination.name)) {
      message = AppLocalizations.of(context).intercityDifferentCities;
    } else if (_travelDate.isBefore(today)) {
      message = AppLocalizations.of(context).intercityDatePast;
    } else if (_seats < 1 || _seats > 7) {
      message = AppLocalizations.of(context).intercitySeatsRange;
    }
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IntercityRideResultsScreen(
          repository: _repository,
          draft: IntercityRideSearchDraft(
            origin: origin!,
            destination: destination!,
            travelDate: _travelDate,
            seats: _seats,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).intercityFindRide)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          IntercityCitySelectionField(
            label: AppLocalizations.of(context).intercityFrom,
            value: _origin,
            onChanged: (value) => setState(() => _origin = value),
          ),
          const SizedBox(height: 12),
          IntercityCitySelectionField(
            label: AppLocalizations.of(context).intercityTo,
            value: _destination,
            onChanged: (value) => setState(() => _destination = value),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: const Key('intercity_travel_date'),
            onTap: _selectDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).intercityTravelDate,
                prefixIcon: const Icon(Icons.calendar_month_outlined),
              ),
              child: Text(formatIntercityCalendarDate(_travelDate)),
            ),
          ),
          const SizedBox(height: 16),
          IntercitySeatsSelector(
            value: _seats,
            onChanged: (value) => setState(() => _seats = value),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              key: const Key('intercity_search_submit'),
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: Text(AppLocalizations.of(context).intercityFindTrips),
            ),
          ),
        ],
      ),
    ),
  );
}

String _cityKey(String value) => value
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase()
    .replaceAll('ё', 'е');
