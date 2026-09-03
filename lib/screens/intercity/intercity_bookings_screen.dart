import 'package:flutter/material.dart';

import '../../models/intercity_ride_booking.dart';
import '../../models/order_service_type.dart';
import '../../services/intercity_ride_service.dart';
import '../../utils/intercity_ride_formatters.dart';
import '../../widgets/app_drawer.dart';

class IntercityBookingsScreen extends StatefulWidget {
  const IntercityBookingsScreen({super.key, this.repository});

  final IntercityRideRepository? repository;

  @override
  State<IntercityBookingsScreen> createState() =>
      _IntercityBookingsScreenState();
}

class _IntercityBookingsScreenState extends State<IntercityBookingsScreen> {
  late final IntercityRideRepository _repository;
  final Set<String> _cancelling = {};
  List<IntercityRideBooking> _bookings = const [];
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
      final bookings = await _repository.getMyBookings();
      if (mounted) setState(() => _bookings = bookings);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(IntercityRideBooking booking) async {
    if (_cancelling.contains(booking.bookingId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить бронь?'),
        content: const Text('Забронированные места снова станут доступными.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Назад'),
          ),
          ElevatedButton(
            key: const Key('intercity_cancel_booking_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отменить бронь'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling.add(booking.bookingId));
    try {
      final updated = await _repository.cancelBooking(booking.bookingId);
      if (!mounted) return;
      setState(() {
        _bookings = _bookings
            .map((item) => item.bookingId == updated.bookingId ? updated : item)
            .toList(growable: false);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось отменить бронь. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling.remove(booking.bookingId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Мои бронирования')),
    drawer: const AppDrawer(
      mode: AppMode.passenger,
      selectedServiceType: OrderServiceType.intercity,
    ),
    body: _body(),
  );

  Widget _body() {
    if (_loading) {
      return const Center(
        key: Key('intercity_bookings_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const Key('intercity_bookings_error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Не удалось загрузить бронирования'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_bookings.isEmpty) {
      return const Center(
        key: Key('intercity_bookings_empty'),
        child: Text('У вас пока нет бронирований'),
      );
    }
    final groups = <IntercityRideBookingStatus, List<IntercityRideBooking>>{};
    for (final booking in _bookings) {
      groups.putIfAbsent(booking.status, () => []).add(booking);
    }
    const order = [
      IntercityRideBookingStatus.confirmed,
      IntercityRideBookingStatus.cancelled,
      IntercityRideBookingStatus.completed,
      IntercityRideBookingStatus.unknown,
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final status in order)
            if (groups[status]?.isNotEmpty == true) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  _statusTitle(status),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final booking in groups[status]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BookingCard(
                    booking: booking,
                    cancelling: _cancelling.contains(booking.bookingId),
                    onCancel: () => _cancel(booking),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.cancelling,
    required this.onCancel,
  });

  final IntercityRideBooking booking;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final driver = booking.driver;
    final vehicle = [
      driver?.carModel,
      driver?.carColor,
      driver?.carNumber,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return Card(
      key: Key('intercity_booking_${booking.bookingId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${booking.route.originCity} → ${booking.route.destinationCity}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatIntercityRideDate(booking.departureAt)}, '
              '${formatIntercityRideTime(booking.departureAt)}',
            ),
            Text('${booking.seats} мест · ${formatTenge(booking.totalPrice)}'),
            if (booking.pickupAddress?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text('Точка посадки: ${booking.pickupAddress}'),
            ],
            if (booking.passengerComment?.isNotEmpty == true)
              Text('Комментарий водителю: ${booking.passengerComment}'),
            if (booking.status == IntercityRideBookingStatus.confirmed &&
                driver != null) ...[
              if (driver.name != null) Text('Водитель: ${driver.name}'),
              if (vehicle.isNotEmpty) Text(vehicle),
              if (driver.phone != null) Text('Телефон: ${driver.phone}'),
            ],
            if (booking.canCancel) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                key: Key('intercity_cancel_booking_${booking.bookingId}'),
                onPressed: cancelling ? null : onCancel,
                child: cancelling
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Отменить бронь'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _statusTitle(IntercityRideBookingStatus status) => switch (status) {
  IntercityRideBookingStatus.confirmed => 'Предстоящие',
  IntercityRideBookingStatus.cancelled => 'Отменённые',
  IntercityRideBookingStatus.completed => 'Завершённые',
  IntercityRideBookingStatus.unknown => 'Другие',
};
