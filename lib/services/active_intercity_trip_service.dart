import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/intercity_ride.dart';
import '../models/intercity_ride_booking.dart';
import '../models/intercity_pickup_draft.dart';
import 'intercity_ride_service.dart';

enum ActiveIntercityTripResolutionKind { found, confirmedNone, unknown }

class ActiveIntercityTrip {
  const ActiveIntercityTrip({required this.ride, required this.bookings});

  final IntercityRide ride;
  final List<IntercityRideBooking> bookings;

  String get rideId => ride.rideId;

  List<IntercityPickupDraft> get remainingPickups =>
      intercityNavigationPickups(bookings);
}

class ActiveIntercityTripResolution {
  const ActiveIntercityTripResolution._(
    this.kind, {
    this.trip,
    this.lastKnownRideId,
  });

  ActiveIntercityTripResolution.found(ActiveIntercityTrip trip)
    : this._(
        ActiveIntercityTripResolutionKind.found,
        trip: trip,
        lastKnownRideId: trip.rideId,
      );

  const ActiveIntercityTripResolution.confirmedNone()
    : this._(ActiveIntercityTripResolutionKind.confirmedNone);

  const ActiveIntercityTripResolution.unknown({
    ActiveIntercityTrip? lastKnownTrip,
    String? lastKnownRideId,
  }) : this._(
         ActiveIntercityTripResolutionKind.unknown,
         trip: lastKnownTrip,
         lastKnownRideId: lastKnownRideId,
       );

  final ActiveIntercityTripResolutionKind kind;
  final ActiveIntercityTrip? trip;
  final String? lastKnownRideId;

  bool get canResume => trip != null;
}

abstract interface class ActiveIntercityTripCache {
  Future<String?> readRideId();

  Future<void> writeRideId(String? rideId);
}

class SharedPreferencesActiveIntercityTripCache
    implements ActiveIntercityTripCache {
  static const _key = 'active_intercity_driver_ride_id';

  @override
  Future<String?> readRideId() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> writeRideId(String? rideId) async {
    final preferences = await SharedPreferences.getInstance();
    if (rideId == null) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(_key, rideId);
    }
  }
}

class ActiveIntercityTripResolver {
  ActiveIntercityTripResolver({
    IntercityDriverRideRepository? repository,
    ActiveIntercityTripCache? cache,
    this.timeout = const Duration(seconds: 8),
  }) : _repository = repository ?? IntercityRideService(),
       _cache = cache ?? SharedPreferencesActiveIntercityTripCache();

  final IntercityDriverRideRepository _repository;
  final ActiveIntercityTripCache _cache;
  final Duration timeout;

  static ActiveIntercityTrip? _lastKnownTrip;

  ActiveIntercityTrip? get lastKnownTrip => _lastKnownTrip;

  Future<ActiveIntercityTripResolution> resolve() async {
    String? cachedRideId;
    try {
      cachedRideId = await _cache.readRideId();
    } catch (_) {
      cachedRideId = _lastKnownTrip?.rideId;
    }

    try {
      final rides = await _repository.getMyDriverRides().timeout(timeout);
      IntercityRide? activeRide;
      for (final ride in rides) {
        if (ride.status == IntercityRideStatus.departed) {
          activeRide = ride;
          break;
        }
      }

      if (activeRide == null) {
        _lastKnownTrip = null;
        await _writeCacheSafely(null);
        return const ActiveIntercityTripResolution.confirmedNone();
      }

      final bookings = await _repository
          .getDriverRideBookings(activeRide.rideId)
          .timeout(timeout);
      final trip = ActiveIntercityTrip(
        ride: activeRide,
        bookings: List.unmodifiable(bookings),
      );
      _lastKnownTrip = trip;
      await _writeCacheSafely(activeRide.rideId);
      return ActiveIntercityTripResolution.found(trip);
    } catch (_) {
      final lastKnown = _lastKnownTrip;
      return ActiveIntercityTripResolution.unknown(
        lastKnownTrip: lastKnown,
        lastKnownRideId: lastKnown?.rideId ?? cachedRideId,
      );
    }
  }

  Future<void> clearIfMatches(String rideId) async {
    if (_lastKnownTrip?.rideId == rideId) _lastKnownTrip = null;
    String? cached;
    try {
      cached = await _cache.readRideId();
    } catch (_) {
      return;
    }
    if (cached == rideId) await _writeCacheSafely(null);
  }

  Future<void> _writeCacheSafely(String? rideId) async {
    try {
      await _cache.writeRideId(rideId);
    } catch (_) {
      // The backend result remains authoritative even if local persistence is
      // temporarily unavailable.
    }
  }

  static void resetMemoryForTest() => _lastKnownTrip = null;
}
