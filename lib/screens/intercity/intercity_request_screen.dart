import 'package:flutter/material.dart';

import '../../models/intercity_ride_request.dart';
import '../../models/intercity_ride_search_draft.dart';
import '../../models/intercity_pickup_draft.dart';
import '../../models/order_service_type.dart';
import '../../services/city_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/intercity_ride_service.dart';
import '../../services/address_label_service.dart';
import '../../services/tulpar_api_client.dart';
import '../../utils/intercity_ride_formatters.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/intercity_ride_fields.dart';
import '../../widgets/intercity_pickup_field.dart';
import '../../widgets/tulpar_date_picker.dart';
import 'intercity_ride_details_screen.dart';
import '../../l10n/generated/app_localizations.dart';

class IntercityRequestScreen extends StatefulWidget {
  const IntercityRequestScreen({
    super.key,
    this.repository,
    this.initialDraft,
    this.defaultCityLoader,
    this.pickupPicker,
    this.initialPickup,
    this.originCityPickerBuilder,
    this.destinationCityPickerBuilder,
  });

  final IntercityRideRepository? repository;
  final IntercityRideSearchDraft? initialDraft;
  final Future<KazakhstanSettlement> Function()? defaultCityLoader;
  final IntercityPickupPicker? pickupPicker;
  final IntercityPickupDraft? initialPickup;
  final WidgetBuilder? originCityPickerBuilder;
  final WidgetBuilder? destinationCityPickerBuilder;

  @override
  State<IntercityRequestScreen> createState() => _IntercityRequestScreenState();
}

class _IntercityRequestScreenState extends State<IntercityRequestScreen> {
  late final IntercityRideRepository _repository;
  KazakhstanSettlement? _origin;
  KazakhstanSettlement? _destination;
  late DateTime _travelDate;
  int _seats = 1;
  List<IntercityRideRequest> _requests = const [];
  final Set<String> _cancelling = {};
  bool _loading = true;
  bool _creating = false;
  Object? _error;
  IntercityPickupDraft? _pickup;
  final TextEditingController _passengerCommentController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IntercityRideService();
    final draft = widget.initialDraft;
    _origin = draft?.origin;
    _destination = draft?.destination;
    _travelDate =
        draft?.travelDate ??
        DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    _seats = draft?.seats ?? 1;
    _pickup = widget.initialPickup;
    _passengerCommentController.text =
        widget.initialPickup?.passengerComment ?? '';
    if (_origin == null) _loadDefaultOrigin();
    _loadRequests();
  }

  @override
  void dispose() {
    _passengerCommentController.dispose();
    super.dispose();
  }

  void _setOrigin(KazakhstanSettlement value) {
    setState(() {
      if (_origin != null && _cityKey(_origin!.name) != _cityKey(value.name)) {
        _pickup = null;
      }
      _origin = value;
    });
  }

  Future<void> _selectPickup() async {
    final origin = _origin;
    if (origin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).requestSelectOriginFirst),
        ),
      );
      return;
    }
    final selected = await (widget.pickupPicker ?? showIntercityPickupPicker)(
      context,
      origin,
      _pickup,
    );
    if (!mounted || selected == null) return;
    final comment = _normalizedComment;
    setState(() {
      _pickup = selected.copyWith(
        passengerComment: comment,
        clearPassengerComment: comment == null,
      );
    });
  }

  String? get _normalizedComment {
    final value = _passengerCommentController.text.trim();
    return value.isEmpty ? null : value;
  }

  IntercityPickupDraft? get _submissionPickup {
    final pickup = _pickup;
    if (pickup == null || !pickup.isComplete) return null;
    final comment = _normalizedComment;
    return pickup.copyWith(
      passengerComment: comment,
      clearPassengerComment: comment == null,
    );
  }

  Future<void> _loadDefaultOrigin() async {
    final settlement =
        await (widget.defaultCityLoader?.call() ??
            CityService.getSelectedCityDetails().then(
              KazakhstanSettlement.fromCity,
            ));
    if (mounted && _origin == null) setState(() => _origin = settlement);
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _repository.getMyRequests();
      if (mounted) setState(() => _requests = requests);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDate() async {
    final tomorrow = DateUtils.dateOnly(
      DateTime.now(),
    ).add(const Duration(days: 1));
    final selected = await showTulparDatePicker(
      context: context,
      initialDate: _travelDate.isBefore(tomorrow) ? tomorrow : _travelDate,
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 365)),
    );
    if (selected != null && mounted) setState(() => _travelDate = selected);
  }

  Future<void> _create() async {
    if (_creating) return;
    final l10n = AppLocalizations.of(context);
    final origin = _origin;
    final destination = _destination;
    final today = DateUtils.dateOnly(DateTime.now());
    String? validation;
    if (origin == null || destination == null) {
      validation = l10n.intercityChooseCities;
    } else if (_cityKey(origin.name) == _cityKey(destination.name)) {
      validation = l10n.intercityDifferentCities;
    } else if (!_travelDate.isAfter(today)) {
      validation = l10n.requestFutureDate;
    } else if (_passengerCommentController.text.trim().length > 1000) {
      validation = l10n.requestCommentTooLong;
    } else if (_submissionPickup == null) {
      validation = l10n.requestSelectPickup;
    }
    if (validation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }
    setState(() => _creating = true);
    try {
      final created = await _repository.createRequest(
        originCity: origin!.name,
        destinationCity: destination!.name,
        travelDate: _travelDate,
        seats: _seats,
        pickup: _submissionPickup,
      );
      if (!mounted) return;
      setState(() => _requests = [created, ..._requests]);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.requestSaved)));
    } catch (error) {
      if (!mounted) return;
      final message = error is TulparApiException && error.statusCode == 409
          ? l10n.requestDuplicate
          : l10n.requestSaveFailed;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _cancel(IntercityRideRequest request) async {
    if (_cancelling.contains(request.requestId)) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.requestCancelTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.bookingBack),
          ),
          ElevatedButton(
            key: const Key('intercity_cancel_request_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling.add(request.requestId));
    try {
      final updated = await _repository.cancelRequest(request.requestId);
      if (!mounted) return;
      setState(() {
        _requests = _requests
            .map((item) => item.requestId == updated.requestId ? updated : item)
            .toList(growable: false);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.requestCancelFailed)));
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(request.requestId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context).intercityLookingForRide),
    ),
    drawer: const AppDrawer(
      mode: AppMode.passenger,
      selectedServiceType: OrderServiceType.intercity,
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              AppLocalizations.of(context).intercityLeaveRequest,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).requestNotifyHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            IntercityCitySelectionField(
              label: AppLocalizations.of(context).intercityFrom,
              value: _origin,
              onChanged: _setOrigin,
              pickerBuilder: widget.originCityPickerBuilder,
            ),
            const SizedBox(height: 12),
            IntercityCitySelectionField(
              label: AppLocalizations.of(context).intercityTo,
              value: _destination,
              onChanged: (value) => setState(() => _destination = value),
              pickerBuilder: widget.destinationCityPickerBuilder,
            ),
            const SizedBox(height: 12),
            InkWell(
              key: const Key('intercity_request_date'),
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
            const SizedBox(height: 16),
            IntercityPickupField(
              value: _pickup,
              onTap: _selectPickup,
              enabled: !_creating,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('intercity_request_passenger_comment'),
              controller: _passengerCommentController,
              enabled: !_creating,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).requestCommentLabel,
                hintText: AppLocalizations.of(context).requestCommentHint,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                key: const Key('intercity_request_submit'),
                onPressed: _creating ? null : _create,
                child: _creating
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppLocalizations.of(context).intercityLeaveRequest),
              ),
            ),
            const Divider(height: 40),
            Text(
              AppLocalizations.of(context).requestMyRequests,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(
                key: const Key('intercity_requests_error'),
                child: Column(
                  children: [
                    Text(AppLocalizations.of(context).requestLoadFailed),
                    TextButton(
                      onPressed: _loadRequests,
                      child: Text(AppLocalizations.of(context).retry),
                    ),
                  ],
                ),
              )
            else if (_requests.isEmpty)
              Text(AppLocalizations.of(context).requestEmpty)
            else
              for (final request in _requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequestCard(
                    request: request,
                    cancelling: _cancelling.contains(request.requestId),
                    onCancel: () => _cancel(request),
                    onRide: (rideId) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IntercityRideDetailsScreen(
                          repository: _repository,
                          rideId: rideId,
                          initialSeats: request.seats,
                          initialPickup: request.pickup,
                          pickupPicker: widget.pickupPicker,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.cancelling,
    required this.onCancel,
    required this.onRide,
  });

  final IntercityRideRequest request;
  final bool cancelling;
  final VoidCallback onCancel;
  final ValueChanged<String> onRide;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('intercity_request_${request.requestId}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${request.originCity} → ${request.destinationCity}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).requestDateSeats(
              formatIntercityRideDate(request.travelDate),
              request.seats,
            ),
          ),
          Text(_requestStatus(request.status, AppLocalizations.of(context))),
          if (request.pickupAddress?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).bookingPickup(
                AddressLabelService.format(
                  request.pickupAddress!,
                  Localizations.localeOf(context),
                ),
              ),
            ),
          ],
          if (request.passengerComment?.isNotEmpty == true)
            Text(
              AppLocalizations.of(
                context,
              ).bookingComment(request.passengerComment!),
            ),
          if (request.matchedRideIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(AppLocalizations.of(context).requestMatchedRides),
            Wrap(
              spacing: 8,
              children: [
                for (
                  var index = 0;
                  index < request.matchedRideIds.length;
                  index += 1
                )
                  ActionChip(
                    key: Key(
                      'intercity_matched_ride_${request.matchedRideIds[index]}',
                    ),
                    label: Text(
                      AppLocalizations.of(
                        context,
                      ).requestMatchedRide(index + 1),
                    ),
                    onPressed: () => onRide(request.matchedRideIds[index]),
                  ),
              ],
            ),
          ],
          if (request.canCancel) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              key: Key('intercity_cancel_request_${request.requestId}'),
              onPressed: cancelling ? null : onCancel,
              child: cancelling
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppLocalizations.of(context).requestCancel),
            ),
          ],
        ],
      ),
    ),
  );
}

String _requestStatus(
  IntercityRideRequestStatus status,
  AppLocalizations l10n,
) => switch (status) {
  IntercityRideRequestStatus.active => l10n.requestActive,
  IntercityRideRequestStatus.cancelled => l10n.requestCancelled,
  IntercityRideRequestStatus.expired => l10n.requestExpired,
  IntercityRideRequestStatus.unknown => l10n.driverRideUnknown,
};

String _cityKey(String value) => value
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase()
    .replaceAll('ё', 'е');
