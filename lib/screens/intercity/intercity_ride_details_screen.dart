import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/intercity_ride.dart';
import '../../models/intercity_ride_booking.dart';
import '../../models/intercity_pickup_draft.dart';
import '../../services/geocoding_service.dart';
import '../../services/intercity_ride_service.dart';
import '../../services/tulpar_api_client.dart';
import '../../utils/intercity_ride_formatters.dart';
import '../../widgets/intercity_ride_fields.dart';
import '../../widgets/intercity_pickup_field.dart';

class IntercityRideDetailsScreen extends StatefulWidget {
  const IntercityRideDetailsScreen({
    super.key,
    this.ride,
    this.rideId,
    this.repository,
    this.initialSeats = 1,
    this.initialPickup,
    this.pickupPicker,
  }) : assert(ride != null || rideId != null);

  final IntercityRide? ride;
  final String? rideId;
  final IntercityRideRepository? repository;
  final int initialSeats;
  final IntercityPickupDraft? initialPickup;
  final IntercityPickupPicker? pickupPicker;

  @override
  State<IntercityRideDetailsScreen> createState() =>
      _IntercityRideDetailsScreenState();
}

class _IntercityRideDetailsScreenState
    extends State<IntercityRideDetailsScreen> {
  late final IntercityRideRepository _repository;
  IntercityRide? _ride;
  IntercityRideBooking? _bookingResult;
  bool _loading = false;
  bool _booking = false;
  bool _confirmationOpen = false;
  Object? _loadError;
  String? _bookingError;
  String? _clientRequestId;
  String? _clientRequestPayloadKey;
  late int _seats;
  IntercityPickupDraft? _pickup;
  late final TextEditingController _passengerCommentController;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IntercityRideService();
    _ride = widget.ride;
    _seats = widget.initialSeats.clamp(1, 7);
    _pickup = widget.initialPickup;
    _passengerCommentController = TextEditingController(
      text: widget.initialPickup?.passengerComment ?? '',
    );
    if (_ride == null) _loadRide();
  }

  @override
  void dispose() {
    _passengerCommentController.dispose();
    super.dispose();
  }

  Future<void> _selectPickup() async {
    final ride = _ride;
    if (ride == null) return;
    KazakhstanSettlement? settlement;
    if (ride.originLat != null && ride.originLng != null) {
      settlement = KazakhstanSettlement(
        id: ride.originCity,
        name: ride.originCity,
        region: '',
        lat: ride.originLat!,
        lng: ride.originLng!,
      );
    } else {
      final matches = await GeocodingService.searchKazakhstanSettlements(
        query: ride.originCity,
      );
      if (!mounted) return;
      for (final match in matches) {
        if (_cityKey(match.name) == _cityKey(ride.originCity)) {
          settlement = match;
          break;
        }
      }
    }
    if (settlement == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось определить город посадки.')),
        );
      }
      return;
    }
    final selected = await (widget.pickupPicker ?? showIntercityPickupPicker)(
      context,
      settlement,
      _pickup,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _pickup = selected.copyWith(
        passengerComment: _normalizedComment,
        clearPassengerComment: _normalizedComment == null,
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

  Future<void> _loadRide() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final ride = await _repository.getRide(widget.rideId!);
      if (!mounted) return;
      setState(() {
        _ride = ride;
        _seats = _seats.clamp(1, ride.availableSeats.clamp(1, 7));
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAndBook() async {
    if (_booking || _confirmationOpen || _ride == null) return;
    if (_submissionPickup == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выберите точку посадки.')));
      return;
    }
    if (_passengerCommentController.text.trim().length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Комментарий не должен превышать 1000 символов.'),
        ),
      );
      return;
    }
    _confirmationOpen = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Подтвердить бронирование?'),
          content: Text(
            '$_seats ${_seatWord(_seats)} · '
            '${formatTenge(_ride!.pricePerSeat * _seats)}\n'
            '${_submissionPickup!.address}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Назад'),
            ),
            ElevatedButton(
              key: const Key('intercity_booking_confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Забронировать'),
            ),
          ],
        ),
      );
    } finally {
      _confirmationOpen = false;
    }
    if (confirmed != true || !mounted) return;
    await _book();
  }

  Future<void> _book() async {
    if (_booking || _ride == null) return;
    final pickup = _submissionPickup;
    if (pickup == null) return;
    final payloadKey = '${_ride!.rideId}|$_seats|${pickup.logicalPayloadKey}';
    if (_clientRequestId == null || _clientRequestPayloadKey != payloadKey) {
      _clientRequestId = _repository.createClientRequestId();
      _clientRequestPayloadKey = payloadKey;
    }
    setState(() {
      _booking = true;
      _bookingError = null;
    });
    try {
      final result = await _repository.bookRide(
        rideId: _ride!.rideId,
        seats: _seats,
        clientRequestId: _clientRequestId!,
        pickup: pickup,
      );
      if (!mounted) return;
      setState(() {
        _bookingResult = result;
        _ride = _ride!.copyWith(
          availableSeats: (_ride!.availableSeats - _seats).clamp(
            0,
            _ride!.totalSeats,
          ),
        );
      });
      final openBookings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Место забронировано'),
          content: const Text('Бронь сохранена в разделе «Мои бронирования».'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Остаться'),
            ),
            ElevatedButton(
              key: const Key('intercity_open_bookings'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Мои бронирования'),
            ),
          ],
        ),
      );
      if (openBookings == true && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.intercityBookings);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _bookingError = _bookingMessage(error));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Поездка')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null || _ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Поездка')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Не удалось загрузить поездку'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadRide,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    final ride = _ride!;
    final maximumSeats = ride.availableSeats.clamp(1, 7);
    final vehicle = [
      ride.driver?.carModel,
      ride.driver?.carColor,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    final total = ride.pricePerSeat * _seats;

    return Scaffold(
      appBar: AppBar(title: const Text('Поездка')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${ride.originCity} → ${ride.destinationCity}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              text:
                  '${formatIntercityRideDate(ride.departureAt)}, '
                  '${formatIntercityRideTime(ride.departureAt)}',
            ),
            if (vehicle.isNotEmpty)
              _DetailRow(icon: Icons.directions_car_outlined, text: vehicle),
            _DetailRow(
              icon: Icons.event_seat_outlined,
              text: 'Свободно: ${ride.availableSeats} мест',
            ),
            _DetailRow(
              icon: Icons.luggage_outlined,
              text: ride.allowsLuggage ? 'Багаж разрешён' : 'Без багажа',
            ),
            if (ride.comment != null)
              _DetailRow(icon: Icons.notes_outlined, text: ride.comment!),
            const Divider(height: 32),
            IntercityPickupField(
              value: _pickup,
              onTap: _selectPickup,
              enabled: !_booking,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('intercity_booking_passenger_comment'),
              controller: _passengerCommentController,
              enabled: !_booking,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Комментарий водителю (необязательно)',
                hintText: 'Например, подъедьте к главному входу',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 8),
            IntercitySeatsSelector(
              value: _seats,
              maximum: maximumSeats,
              onChanged: (value) => setState(() => _seats = value),
            ),
            const SizedBox(height: 12),
            Text(
              '${formatTenge(ride.pricePerSeat)} × $_seats',
              key: const Key('intercity_booking_calculation'),
            ),
            const SizedBox(height: 4),
            Text(
              'Итого: ${formatTenge(total)}',
              key: const Key('intercity_booking_total'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_bookingError != null) ...[
              const SizedBox(height: 12),
              Text(
                _bookingError!,
                key: const Key('intercity_booking_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_bookingResult != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Место забронировано',
                key: Key('intercity_booking_success'),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                key: const Key('intercity_booking_submit'),
                onPressed: ride.canBook && !_booking && _bookingResult == null
                    ? _confirmAndBook
                    : null,
                child: _booking
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Забронировать $_seats ${_seatWord(_seats)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cityKey(String value) => value
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase()
    .replaceAll('ё', 'е');

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

String _seatWord(int seats) {
  if (seats == 1) return 'место';
  if (seats >= 2 && seats <= 4) return 'места';
  return 'мест';
}

String _bookingMessage(Object error) {
  if (error is TulparApiException) {
    if (error.statusCode == 409) {
      return 'Поездка изменилась или свободных мест уже недостаточно.';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return 'Необходимо войти в аккаунт и повторить попытку.';
    }
    return error.message;
  }
  if (error is TimeoutException) {
    return 'Сервер не ответил. Повторите попытку.';
  }
  return 'Не удалось забронировать место. Повторите попытку.';
}
