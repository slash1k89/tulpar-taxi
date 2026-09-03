import 'package:flutter/material.dart';

import '../../models/intercity_ride.dart';
import '../../models/order_service_type.dart';
import '../../services/intercity_ride_service.dart';
import '../../utils/intercity_ride_formatters.dart';
import '../../widgets/app_drawer.dart';
import 'intercity_driver_ride_details_screen.dart';

class IntercityDriverRidesScreen extends StatefulWidget {
  const IntercityDriverRidesScreen({super.key, this.repository});

  final IntercityDriverRideRepository? repository;

  @override
  State<IntercityDriverRidesScreen> createState() =>
      _IntercityDriverRidesScreenState();
}

class _IntercityDriverRidesScreenState
    extends State<IntercityDriverRidesScreen> {
  late final IntercityDriverRideRepository _repository;
  List<IntercityRide> _rides = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IntercityRideService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rides = await _repository.getMyDriverRides();
      if (mounted) setState(() => _rides = rides);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(IntercityRide ride) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => IntercityDriverRideDetailsScreen(
          repository: _repository,
          rideId: ride.rideId,
          initialRide: ride,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Мои поездки')),
    drawer: const AppDrawer(
      mode: AppMode.driver,
      selectedServiceType: OrderServiceType.intercity,
    ),
    body: _body(),
  );

  Widget _body() {
    if (_loading) {
      return const Center(
        key: Key('driver_rides_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const Key('driver_rides_error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Не удалось загрузить поездки'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_rides.isEmpty) {
      return const Center(
        key: Key('driver_rides_empty'),
        child: Text('Вы ещё не публиковали поездки'),
      );
    }
    const statuses = [
      IntercityRideStatus.scheduled,
      IntercityRideStatus.departed,
      IntercityRideStatus.completed,
      IntercityRideStatus.cancelled,
      IntercityRideStatus.unknown,
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final status in statuses)
            if (_rides.any((ride) => ride.status == status)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  intercityRideStatusGroup(status),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final ride in _rides.where((item) => item.status == status))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DriverIntercityRideCard(
                    ride: ride,
                    onDetails: () => _open(ride),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class DriverIntercityRideCard extends StatelessWidget {
  const DriverIntercityRideCard({
    super.key,
    required this.ride,
    required this.onDetails,
  });

  final IntercityRide ride;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('driver_ride_${ride.rideId}'),
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
          const SizedBox(height: 8),
          Text(
            '${formatIntercityRideDate(ride.departureAt)}, '
            '${formatIntercityRideTime(ride.departureAt)}',
          ),
          Text('${ride.totalSeats} мест всего'),
          Text('Свободно: ${ride.availableSeats}'),
          Text(
            '${formatTenge(ride.pricePerSeat)} / место',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              key: Key('driver_ride_details_${ride.rideId}'),
              onPressed: onDetails,
              child: const Text('Подробнее'),
            ),
          ),
        ],
      ),
    ),
  );
}

String intercityRideStatusLabel(IntercityRideStatus status) => switch (status) {
  IntercityRideStatus.scheduled => 'Запланирована',
  IntercityRideStatus.departed => 'В пути',
  IntercityRideStatus.completed => 'Завершена',
  IntercityRideStatus.cancelled => 'Отменена',
  IntercityRideStatus.unknown => 'Статус неизвестен',
};

String intercityRideStatusGroup(IntercityRideStatus status) => switch (status) {
  IntercityRideStatus.scheduled => 'Предстоящие',
  IntercityRideStatus.departed => 'В пути',
  IntercityRideStatus.completed => 'Завершённые',
  IntercityRideStatus.cancelled => 'Отменённые',
  IntercityRideStatus.unknown => 'Другие',
};
