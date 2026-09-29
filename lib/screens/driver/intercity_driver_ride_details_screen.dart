import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/intercity_ride.dart';
import '../../models/intercity_ride_booking.dart';
import '../../models/intercity_pickup_draft.dart';
import '../../services/intercity_ride_service.dart';
import '../../services/active_intercity_trip_service.dart';
import '../../services/address_label_service.dart';
import '../../services/intercity_contact_service.dart';
import '../../widgets/chat_unread_badge.dart';
import '../chat/chat_screen.dart';
import '../driver_navigation_screen.dart';
import '../../utils/intercity_ride_formatters.dart';
import '../intercity/intercity_pickup_viewer_screen.dart';
import 'intercity_create_ride_screen.dart';
import 'intercity_driver_rides_screen.dart';
import '../../l10n/generated/app_localizations.dart';

class IntercityDriverRideDetailsScreen extends StatefulWidget {
  static final Set<_IntercityDriverRideDetailsScreenState> _visibleStates = {};
  static bool isCurrentRide(String rideId) => _visibleStates.any(
    (state) =>
        state.mounted &&
        state.widget.rideId == rideId &&
        ModalRoute.of(state.context)?.isCurrent == true,
  );
  const IntercityDriverRideDetailsScreen({
    super.key,
    required this.rideId,
    this.initialRide,
    this.repository,
  });

  final String rideId;
  final IntercityRide? initialRide;
  final IntercityDriverRideRepository? repository;

  @override
  State<IntercityDriverRideDetailsScreen> createState() =>
      _IntercityDriverRideDetailsScreenState();
}

class _IntercityDriverRideDetailsScreenState
    extends State<IntercityDriverRideDetailsScreen> {
  late final IntercityDriverRideRepository _repository;
  IntercityRide? _ride;
  List<IntercityRideBooking> _bookings = const [];
  bool _loading = true;
  bool _acting = false;
  bool _confirmationOpen = false;
  Object? _error;
  String? _actionError;

  bool get _hasConfirmed => _bookings.any(
    (booking) => booking.status == IntercityRideBookingStatus.confirmed,
  );

  @override
  void initState() {
    super.initState();
    IntercityDriverRideDetailsScreen._visibleStates.add(this);
    _repository = widget.repository ?? IntercityRideService();
    _ride = widget.initialRide;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _repository.getDriverRide(widget.rideId),
        _repository.getDriverRideBookings(widget.rideId),
      ]);
      if (!mounted) return;
      setState(() {
        _ride = results[0] as IntercityRide;
        _bookings = results[1] as List<IntercityRideBooking>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    IntercityDriverRideDetailsScreen._visibleStates.remove(this);
    super.dispose();
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<IntercityRide>(
      context,
      MaterialPageRoute(
        builder: (_) => IntercityCreateRideScreen(
          repository: _repository,
          ride: _ride,
          hasConfirmedBooking: _hasConfirmed,
        ),
      ),
    );
    if (updated != null && mounted) await _load();
  }

  Future<void> _openNavigation() async {
    final ride = _ride;
    if (ride == null) return;
    final destinationLat = ride.destinationLat;
    final destinationLng = ride.destinationLng;
    if (destinationLat == null || destinationLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).intercityNavigationUnavailable,
          ),
        ),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverNavigationScreen(
          destinationLat: destinationLat,
          destinationLng: destinationLng,
          intermediatePoints: intercityNavigationPickups(_bookings),
          intercity: true,
          onNextPickupReached: _markNextPickupReachedFromNavigation,
        ),
      ),
    );
  }

  Future<List<IntercityPickupDraft>>
  _markNextPickupReachedFromNavigation() async {
    final pending = _bookings.where(
      (booking) =>
          booking.status == IntercityRideBookingStatus.confirmed &&
          booking.pickupReachedAt == null &&
          booking.pickup != null,
    );
    if (pending.isEmpty) return const [];
    await _repository.markPickupReached(
      rideId: widget.rideId,
      bookingId: pending.first.bookingId,
    );
    final bookings = await _repository.getDriverRideBookings(widget.rideId);
    if (mounted) setState(() => _bookings = bookings);
    return intercityNavigationPickups(bookings);
  }

  Future<void> _transition(_RideAction action) async {
    if (_acting || _confirmationOpen || _ride == null) return;
    _confirmationOpen = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(action.title(AppLocalizations.of(context))),
          content: Text(
            action.message(
              AppLocalizations.of(context),
              hasConfirmedBookings: _hasConfirmed,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).bookingBack),
            ),
            ElevatedButton(
              key: Key('driver_ride_${action.name}_confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action.confirmLabel(AppLocalizations.of(context))),
            ),
          ],
        ),
      );
    } finally {
      _confirmationOpen = false;
    }
    if (confirmed != true || !mounted) return;
    setState(() {
      _acting = true;
      _actionError = null;
    });
    try {
      final updated = switch (action) {
        _RideAction.cancel => _repository.cancelDriverRide(widget.rideId),
        _RideAction.depart => _repository.departDriverRide(widget.rideId),
        _RideAction.complete => _repository.completeDriverRide(widget.rideId),
      };
      final ride = await updated;
      final bookings = await _repository.getDriverRideBookings(widget.rideId);
      if (!mounted) return;
      setState(() {
        _ride = ride;
        _bookings = bookings;
      });
      if (action == _RideAction.depart && mounted) {
        await _openNavigation();
      } else if (action == _RideAction.complete) {
        await ActiveIntercityTripResolver().clearIfMatches(widget.rideId);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _actionError = intercityDriverErrorMessage(
            error,
            AppLocalizations.of(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).bookingRide)),
        body: const Center(
          key: Key('driver_ride_details_loading'),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null || _ride == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).bookingRide)),
        body: Center(
          key: const Key('driver_ride_details_error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                intercityDriverErrorMessage(
                  _error ?? StateError('ride'),
                  AppLocalizations.of(context),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      );
    }
    final ride = _ride!;
    final occupied = ride.totalSeats - ride.availableSeats;
    final vehicle = [
      ride.driver?.carModel,
      ride.driver?.carColor,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).driverRideDetailsTitle),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${ride.originCity} → ${ride.destinationCity}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _Info(
              AppLocalizations.of(context).driverRideStatusLabel,
              intercityRideStatusLabel(
                ride.status,
                AppLocalizations.of(context),
              ),
            ),
            _Info(
              AppLocalizations.of(context).driverRideDeparture,
              ride.departureAt == null
                  ? AppLocalizations.of(context).driverRideDate
                  : DateFormat(
                      'd MMMM, HH:mm',
                      Localizations.localeOf(context).toLanguageTag(),
                    ).format(toKazakhstanTime(ride.departureAt!)),
            ),
            _Info(
              AppLocalizations.of(context).driverRideTotalSeatsLabel,
              '${ride.totalSeats}',
            ),
            _Info(
              AppLocalizations.of(context).driverRideAvailableSeatsLabel,
              '${ride.availableSeats}',
            ),
            _Info(
              AppLocalizations.of(context).driverRideBookedSeatsLabel,
              '$occupied',
            ),
            _Info(
              AppLocalizations.of(context).driverRidePricePerSeat,
              formatTenge(ride.pricePerSeat),
            ),
            _Info(
              AppLocalizations.of(context).driverRideLuggage,
              ride.allowsLuggage
                  ? AppLocalizations.of(context).driverRideYes
                  : AppLocalizations.of(context).driverRideNo,
            ),
            if (vehicle.isNotEmpty)
              _Info(AppLocalizations.of(context).driverRideVehicle, vehicle),
            if (ride.comment?.isNotEmpty == true)
              _Info(
                AppLocalizations.of(context).driverRideComment,
                ride.comment!,
              ),
            if (_actionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _actionError!,
                  key: const Key('driver_ride_action_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const Divider(height: 32),
            if (ride.status == IntercityRideStatus.scheduled) ...[
              OutlinedButton(
                key: const Key('driver_ride_edit'),
                onPressed: _acting ? null : _edit,
                child: Text(AppLocalizations.of(context).driverRideEditTitle),
              ),
              OutlinedButton(
                key: const Key('driver_ride_cancel'),
                onPressed: _acting
                    ? null
                    : () => _transition(_RideAction.cancel),
                child: Text(AppLocalizations.of(context).driverRideCancelTrip),
              ),
              ElevatedButton(
                key: const Key('driver_ride_depart'),
                onPressed: _acting
                    ? null
                    : () => _transition(_RideAction.depart),
                child: Text(AppLocalizations.of(context).driverRideStartTrip),
              ),
            ] else if (ride.status == IntercityRideStatus.departed) ...[
              ElevatedButton.icon(
                key: const Key('driver_ride_continue'),
                onPressed: _acting ? null : _openNavigation,
                icon: const Icon(Icons.navigation_outlined),
                label: Text(
                  AppLocalizations.of(context).intercityContinueActiveTrip,
                ),
              ),
              OutlinedButton(
                key: const Key('driver_ride_complete'),
                onPressed: _acting
                    ? null
                    : () => _transition(_RideAction.complete),
                child: Text(AppLocalizations.of(context).driverRideFinishTrip),
              ),
            ],
            if (_acting)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
            const Divider(height: 32),
            Text(
              AppLocalizations.of(context).driverRidePassengers,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_bookings.isEmpty)
              Text(AppLocalizations.of(context).driverRideNoBookings)
            else
              for (final booking in _bookings)
                _DriverBookingCard(booking: booking),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _DriverBookingCard extends StatelessWidget {
  const _DriverBookingCard({required this.booking});

  final IntercityRideBooking booking;

  @override
  Widget build(BuildContext context) {
    final passenger = booking.passenger;
    return Card(
      key: Key('driver_booking_${booking.bookingId}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_bookingStatus(booking.status, AppLocalizations.of(context))),
            Text(
              AppLocalizations.of(context).driverRideBookingSummary(
                booking.seats,
                formatTenge(booking.totalPrice),
              ),
            ),
            if (passenger?.name != null)
              Text(
                AppLocalizations.of(
                  context,
                ).driverRidePassengerName(passenger!.name!),
              ),
            if (booking.status == IntercityRideBookingStatus.confirmed &&
                passenger?.phone != null)
              Text(
                AppLocalizations.of(context).bookingPhone(passenger!.phone!),
              ),
            if (booking.status == IntercityRideBookingStatus.confirmed &&
                booking.pickupAddress?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).bookingPickup(
                  AddressLabelService.format(
                    booking.pickupAddress!,
                    Localizations.localeOf(context),
                  ),
                ),
              ),
              if (booking.passengerComment?.isNotEmpty == true)
                Text(
                  AppLocalizations.of(
                    context,
                  ).driverRidePickupComment(booking.passengerComment!),
                ),
              if (booking.pickup != null)
                TextButton.icon(
                  key: Key('driver_booking_map_${booking.bookingId}'),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          IntercityPickupViewerScreen(pickup: booking.pickup!),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(AppLocalizations.of(context).driverRideShowMap),
                ),
              if (booking.pickupReachedAt != null)
                Text(AppLocalizations.of(context).intercityPickupReached),
            ],
            if (booking.chatAvailable) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: Key('driver_booking_chat_${booking.bookingId}'),
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          orderId: booking.bookingId,
                          peerName:
                              passenger?.name ??
                              AppLocalizations.of(context).passenger,
                          intercity: true,
                        ),
                      ),
                    ),
                    icon: ChatUnreadBadge(
                      orderId: booking.bookingId,
                      intercity: true,
                    ),
                    label: Text(AppLocalizations.of(context).intercityOpenChat),
                  ),
                  if (passenger?.phone != null)
                    TextButton.icon(
                      key: Key('driver_booking_whatsapp_${booking.bookingId}'),
                      onPressed: () async {
                        final opened = await openIntercityWhatsApp(
                          passenger?.phone,
                        );
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                ).intercityWhatsAppUnavailable,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(
                        AppLocalizations.of(context).intercityWhatsApp,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _bookingStatus(
  IntercityRideBookingStatus status,
  AppLocalizations l10n,
) => switch (status) {
  IntercityRideBookingStatus.confirmed => l10n.driverRideBookingConfirmed,
  IntercityRideBookingStatus.cancelled => l10n.driverRideBookingCancelled,
  IntercityRideBookingStatus.completed => l10n.driverRideBookingCompleted,
  IntercityRideBookingStatus.unknown => l10n.driverRideBookingUnknown,
};

enum _RideAction { cancel, depart, complete }

extension on _RideAction {
  String title(AppLocalizations l10n) => switch (this) {
    _RideAction.cancel => l10n.driverRideCancelTitle,
    _RideAction.depart => l10n.driverRideDepartTitle,
    _RideAction.complete => l10n.driverRideCompleteTitle,
  };

  String confirmLabel(AppLocalizations l10n) => switch (this) {
    _RideAction.cancel => l10n.driverRideCancelAction,
    _RideAction.depart => l10n.driverRideDepartAction,
    _RideAction.complete => l10n.driverRideCompleteAction,
  };

  String message(AppLocalizations l10n, {required bool hasConfirmedBookings}) =>
      switch (this) {
        _RideAction.cancel =>
          hasConfirmedBookings
              ? l10n.driverRideCancelBookingsWarning
              : l10n.driverRideCancelNoBookings,
        _RideAction.depart => l10n.driverRideDepartWarning,
        _RideAction.complete => l10n.driverRideCompleteWarning,
      };
}
