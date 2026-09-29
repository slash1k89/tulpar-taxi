import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/intercity_ride_booking.dart';
import '../../models/intercity_pickup_draft.dart';
import '../../services/active_intercity_trip_service.dart';
import '../../services/intercity_ride_service.dart';
import '../driver_navigation_screen.dart';
import 'intercity_driver_ride_details_screen.dart';

class ActiveIntercityTripScreen extends StatefulWidget {
  const ActiveIntercityTripScreen({
    super.key,
    required this.trip,
    this.repository,
    this.openNavigationInitially = true,
  });

  final ActiveIntercityTrip trip;
  final IntercityDriverRideRepository? repository;
  final bool openNavigationInitially;

  @override
  State<ActiveIntercityTripScreen> createState() =>
      _ActiveIntercityTripScreenState();
}

class _ActiveIntercityTripScreenState extends State<ActiveIntercityTripScreen> {
  bool _navigationOpened = false;
  late final IntercityDriverRideRepository _repository;
  late List<IntercityRideBooking> _bookings;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IntercityRideService();
    _bookings = List.of(widget.trip.bookings);
    if (widget.openNavigationInitially) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openNavigation());
      });
    }
  }

  Future<List<IntercityPickupDraft>> _markNextPickupReached() async {
    final pending = _bookings.where(
      (booking) =>
          booking.status == IntercityRideBookingStatus.confirmed &&
          booking.pickupReachedAt == null &&
          booking.pickup != null,
    );
    if (pending.isEmpty) return const [];
    await _repository.markPickupReached(
      rideId: widget.trip.rideId,
      bookingId: pending.first.bookingId,
    );
    _bookings = await _repository.getDriverRideBookings(widget.trip.rideId);
    return intercityNavigationPickups(_bookings);
  }

  Future<void> _openNavigation() async {
    if (_navigationOpened) return;
    final latitude = widget.trip.ride.destinationLat;
    final longitude = widget.trip.ride.destinationLng;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).intercityNavigationUnavailable,
          ),
        ),
      );
      return;
    }
    _navigationOpened = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => DriverNavigationScreen(
            destinationLat: latitude,
            destinationLng: longitude,
            intermediatePoints: intercityNavigationPickups(_bookings),
            intercity: true,
            onNextPickupReached: _markNextPickupReached,
          ),
        ),
      );
    } finally {
      _navigationOpened = false;
    }
  }

  @override
  Widget build(BuildContext context) => IntercityDriverRideDetailsScreen(
    rideId: widget.trip.rideId,
    initialRide: widget.trip.ride,
    repository: _repository,
  );
}
