import 'package:flutter/material.dart';

import '../../models/intercity_ride.dart';
import '../../models/intercity_ride_search_draft.dart';
import '../../services/intercity_ride_service.dart';
import '../../utils/intercity_ride_formatters.dart';
import 'intercity_request_screen.dart';
import 'intercity_ride_details_screen.dart';
import '../../l10n/generated/app_localizations.dart';

class IntercityRideResultsScreen extends StatefulWidget {
  const IntercityRideResultsScreen({
    super.key,
    required this.draft,
    this.repository,
  });

  final IntercityRideSearchDraft draft;
  final IntercityRideRepository? repository;

  @override
  State<IntercityRideResultsScreen> createState() =>
      _IntercityRideResultsScreenState();
}

class _IntercityRideResultsScreenState
    extends State<IntercityRideResultsScreen> {
  late final IntercityRideRepository _repository;
  late Future<List<IntercityRide>> _rides;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IntercityRideService();
    _rides = _load();
  }

  Future<List<IntercityRide>> _load() => _repository.searchRides(
    originCity: widget.draft.origin.name,
    destinationCity: widget.draft.destination.name,
    travelDate: widget.draft.travelDate,
    seats: widget.draft.seats,
  );

  void _retry() {
    setState(() {
      _rides = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context).intercityMatchingTrips),
    ),
    body: FutureBuilder<List<IntercityRide>>(
      future: _rides,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            key: Key('intercity_results_loading'),
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return _ResultsMessage(
            key: const Key('intercity_results_error'),
            icon: Icons.cloud_off_outlined,
            title: AppLocalizations.of(context).intercityTripsLoadFailed,
            actionLabel: AppLocalizations.of(context).retry,
            onAction: _retry,
          );
        }
        final rides = snapshot.data ?? const [];
        if (rides.isEmpty) {
          return _ResultsMessage(
            key: const Key('intercity_results_empty'),
            icon: Icons.route_outlined,
            title: AppLocalizations.of(context).intercityNoTrips,
            actionLabel: AppLocalizations.of(context).intercityLeaveRequest,
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IntercityRequestScreen(
                  repository: _repository,
                  initialDraft: widget.draft,
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            final future = _load();
            setState(() {
              _rides = future;
            });
            await future;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ride = rides[index];
              return IntercityRideCard(
                ride: ride,
                onDetails: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IntercityRideDetailsScreen(
                      repository: _repository,
                      ride: ride,
                      initialSeats: widget.draft.seats,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class IntercityRideCard extends StatelessWidget {
  const IntercityRideCard({
    super.key,
    required this.ride,
    required this.onDetails,
  });

  final IntercityRide ride;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final vehicle = [
      ride.driver?.carModel,
      ride.driver?.carColor,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return Card(
      key: Key('intercity_ride_${ride.rideId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ride.originCity} → ${ride.destinationCity}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 8),
                Text(formatIntercityRideDate(ride.departureAt)),
                const SizedBox(width: 16),
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 6),
                Text(formatIntercityRideTime(ride.departureAt)),
              ],
            ),
            if (vehicle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.directions_car_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(vehicle)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(
                context,
              ).intercityAvailableSeats(ride.availableSeats),
              key: Key('intercity_available_${ride.rideId}'),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(
                context,
              ).intercityPerSeat(formatTenge(ride.pricePerSeat)),
              key: Key('intercity_price_per_seat_${ride.rideId}'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                key: Key('intercity_details_${ride.rideId}'),
                onPressed: onDetails,
                child: Text(AppLocalizations.of(context).intercityDetails),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsMessage extends StatelessWidget {
  const _ResultsMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
