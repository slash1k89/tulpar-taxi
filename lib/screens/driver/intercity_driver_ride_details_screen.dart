import 'package:flutter/material.dart';

import '../../models/intercity_ride.dart';
import '../../models/intercity_ride_booking.dart';
import '../../services/intercity_ride_service.dart';
import '../../utils/intercity_ride_formatters.dart';
import '../intercity/intercity_pickup_viewer_screen.dart';
import 'intercity_create_ride_screen.dart';
import 'intercity_driver_rides_screen.dart';

class IntercityDriverRideDetailsScreen extends StatefulWidget {
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

  Future<void> _transition(_RideAction action) async {
    if (_acting || _confirmationOpen || _ride == null) return;
    _confirmationOpen = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(action.title),
          content: Text(action.message(hasConfirmedBookings: _hasConfirmed)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Назад'),
            ),
            ElevatedButton(
              key: Key('driver_ride_${action.name}_confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action.confirmLabel),
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
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = intercityDriverErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Поездка')),
        body: const Center(
          key: Key('driver_ride_details_loading'),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null || _ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Поездка')),
        body: Center(
          key: const Key('driver_ride_details_error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(intercityDriverErrorMessage(_error ?? StateError('ride'))),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Повторить')),
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
      appBar: AppBar(title: const Text('Детали поездки')),
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
            _Info('Статус', intercityRideStatusLabel(ride.status)),
            _Info(
              'Отправление',
              '${formatIntercityRideDate(ride.departureAt)}, '
                  '${formatIntercityRideTime(ride.departureAt)}',
            ),
            _Info('Мест всего', '${ride.totalSeats}'),
            _Info('Свободно мест', '${ride.availableSeats}'),
            _Info('Забронировано мест', '$occupied'),
            _Info('Цена за место', formatTenge(ride.pricePerSeat)),
            _Info('Багаж', ride.allowsLuggage ? 'Разрешён' : 'Нет'),
            if (vehicle.isNotEmpty) _Info('Автомобиль', vehicle),
            if (ride.comment?.isNotEmpty == true)
              _Info('Комментарий', ride.comment!),
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
                child: const Text('Редактировать'),
              ),
              OutlinedButton(
                key: const Key('driver_ride_cancel'),
                onPressed: _acting
                    ? null
                    : () => _transition(_RideAction.cancel),
                child: const Text('Отменить поездку'),
              ),
              ElevatedButton(
                key: const Key('driver_ride_depart'),
                onPressed: _acting
                    ? null
                    : () => _transition(_RideAction.depart),
                child: const Text('Начать поездку'),
              ),
            ] else if (ride.status == IntercityRideStatus.departed)
              ElevatedButton(
                key: const Key('driver_ride_complete'),
                onPressed: _acting
                    ? null
                    : () => _transition(_RideAction.complete),
                child: const Text('Завершить поездку'),
              ),
            if (_acting)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
            const Divider(height: 32),
            Text('Пассажиры', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_bookings.isEmpty)
              const Text('Пока никто не забронировал место')
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
            Text(_bookingStatus(booking.status)),
            Text('${booking.seats} мест · ${formatTenge(booking.totalPrice)}'),
            if (passenger?.name != null) Text('Пассажир: ${passenger!.name}'),
            if (booking.status == IntercityRideBookingStatus.confirmed &&
                passenger?.phone != null)
              Text('Телефон: ${passenger!.phone}'),
            if (booking.status == IntercityRideBookingStatus.confirmed &&
                booking.pickupAddress?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text('Точка посадки: ${booking.pickupAddress}'),
              if (booking.passengerComment?.isNotEmpty == true)
                Text('Комментарий пассажира: ${booking.passengerComment}'),
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
                  label: const Text('Показать на карте'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _bookingStatus(IntercityRideBookingStatus status) => switch (status) {
  IntercityRideBookingStatus.confirmed => 'Подтверждено',
  IntercityRideBookingStatus.cancelled => 'Отменено',
  IntercityRideBookingStatus.completed => 'Завершено',
  IntercityRideBookingStatus.unknown => 'Статус неизвестен',
};

enum _RideAction { cancel, depart, complete }

extension on _RideAction {
  String get title => switch (this) {
    _RideAction.cancel => 'Отменить поездку?',
    _RideAction.depart => 'Начать поездку?',
    _RideAction.complete => 'Завершить поездку?',
  };

  String get confirmLabel => switch (this) {
    _RideAction.cancel => 'Отменить',
    _RideAction.depart => 'Начать',
    _RideAction.complete => 'Завершить',
  };

  String message({required bool hasConfirmedBookings}) => switch (this) {
    _RideAction.cancel =>
      hasConfirmedBookings
          ? 'Все бронирования пассажиров будут отменены.'
          : 'Поездка больше не будет доступна пассажирам.',
    _RideAction.depart =>
      'После отправления новые бронирования и отмена '
          'пассажиром будут недоступны.',
    _RideAction.complete => 'Подтвердите завершение поездки.',
  };
}
