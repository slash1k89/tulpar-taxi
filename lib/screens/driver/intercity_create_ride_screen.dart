import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_routes.dart';
import '../../models/intercity_driver_ride_draft.dart';
import '../../models/intercity_ride.dart';
import '../../services/city_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/intercity_ride_service.dart';
import '../../services/order_creation_service.dart';
import '../../services/tulpar_api_client.dart';
import '../../utils/intercity_ride_formatters.dart';
import '../../widgets/intercity_ride_fields.dart';
import '../../widgets/tulpar_time_picker.dart';
import '../../widgets/tulpar_date_picker.dart';

class IntercityCreateRideScreen extends StatefulWidget {
  const IntercityCreateRideScreen({
    super.key,
    this.repository,
    this.ride,
    this.hasConfirmedBooking = false,
    this.initialOrigin,
    this.initialDestination,
    this.initialDepartureAt,
    this.defaultCityLoader,
    this.onSaved,
  });

  final IntercityDriverRideRepository? repository;
  final IntercityRide? ride;
  final bool hasConfirmedBooking;
  final KazakhstanSettlement? initialOrigin;
  final KazakhstanSettlement? initialDestination;
  final DateTime? initialDepartureAt;
  final Future<KazakhstanSettlement> Function()? defaultCityLoader;
  final ValueChanged<IntercityRide>? onSaved;

  bool get editing => ride != null;

  @override
  State<IntercityCreateRideScreen> createState() =>
      _IntercityCreateRideScreenState();
}

class _IntercityCreateRideScreenState extends State<IntercityCreateRideScreen> {
  late final IntercityDriverRideRepository _repository;
  late final TextEditingController _priceController;
  late final TextEditingController _commentController;
  KazakhstanSettlement? _origin;
  KazakhstanSettlement? _destination;
  late bool _originHasCoordinates;
  late bool _destinationHasCoordinates;
  late DateTime _date;
  late TimeOfDay _time;
  int _seats = 1;
  bool _allowsLuggage = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IntercityRideService();
    final ride = widget.ride;
    _origin = widget.initialOrigin ?? _settlementFromRide(ride, true);
    _destination =
        widget.initialDestination ?? _settlementFromRide(ride, false);
    _originHasCoordinates =
        widget.initialOrigin != null ||
        (ride?.originLat != null && ride?.originLng != null);
    _destinationHasCoordinates =
        widget.initialDestination != null ||
        (ride?.destinationLat != null && ride?.destinationLng != null);
    final initial =
        widget.initialDepartureAt ?? ride?.departureAt ?? _defaultDeparture();
    final kazakhstan = initial.toUtc().add(const Duration(hours: 5));
    _date = DateUtils.dateOnly(kazakhstan);
    _time = TimeOfDay(hour: kazakhstan.hour, minute: kazakhstan.minute);
    _seats = ride?.totalSeats ?? 1;
    _allowsLuggage = ride?.allowsLuggage ?? false;
    _priceController = TextEditingController(
      text: ride == null ? '' : ride.pricePerSeat.toString(),
    );
    _commentController = TextEditingController(text: ride?.comment ?? '');
    if (_origin == null) _loadDefaultOrigin();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultOrigin() async {
    final value =
        await (widget.defaultCityLoader?.call() ??
            CityService.getSelectedCityDetails().then(
              KazakhstanSettlement.fromCity,
            ));
    if (mounted && _origin == null) {
      setState(() {
        _origin = value;
        _originHasCoordinates = true;
      });
    }
  }

  Future<void> _selectDate() async {
    final today = DateUtils.dateOnly(_kazakhstanNow());
    final value = await showTulparDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  Future<void> _selectTime() async {
    final value = await showTulparTimePicker(
      context: context,
      initialTime: _time,
    );
    if (value != null && mounted) setState(() => _time = value);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final draft = _draftOrShowError();
    if (draft == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = widget.editing
          ? await _repository.updateDriverRide(
              rideId: widget.ride!.rideId,
              draft: draft,
              hasConfirmedBooking: widget.hasConfirmedBooking,
            )
          : await _repository.createDriverRide(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.editing ? 'Поездка обновлена' : 'Поездка опубликована',
          ),
        ),
      );
      if (widget.onSaved != null) {
        widget.onSaved!(result);
      } else if (widget.editing) {
        Navigator.pop(context, result);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.driverIntercityRides);
      }
    } catch (error) {
      if (mounted) setState(() => _error = intercityDriverErrorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  IntercityDriverRideDraft? _draftOrShowError() {
    final origin = _origin;
    final destination = _destination;
    final price = int.tryParse(_priceController.text.trim());
    final departureAt = kazakhstanDepartureUtc(
      year: _date.year,
      month: _date.month,
      day: _date.day,
      hour: _time.hour,
      minute: _time.minute,
    );
    String? message;
    if (origin == null || destination == null) {
      message = 'Выберите города отправления и назначения.';
    } else if (_cityKey(origin.name) == _cityKey(destination.name)) {
      message = 'Города отправления и назначения должны отличаться.';
    } else if (!departureAt.isAfter(DateTime.now().toUtc())) {
      message = 'Выберите будущую дату и время.';
    } else if (_seats < 1 || _seats > intercityRideMaximumSeats) {
      message = 'Можно предложить от 1 до 7 мест.';
    } else if (price == null ||
        price < 1 ||
        price > intercityRideMaximumPricePerSeat) {
      message = 'Укажите корректную цену за место.';
    } else if (_commentController.text.trim().length >
        intercityRideMaximumCommentLength) {
      message = 'Комментарий слишком длинный.';
    }
    if (message != null) {
      setState(() => _error = message);
      return null;
    }
    return IntercityDriverRideDraft(
      originCity: origin!.name,
      originLat: _originHasCoordinates ? origin.lat : null,
      originLng: _originHasCoordinates ? origin.lng : null,
      destinationCity: destination!.name,
      destinationLat: _destinationHasCoordinates ? destination.lat : null,
      destinationLng: _destinationHasCoordinates ? destination.lng : null,
      departureAt: departureAt,
      totalSeats: _seats,
      pricePerSeat: price!,
      allowsLuggage: _allowsLuggage,
      comment: _commentController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final protected = widget.editing && widget.hasConfirmedBooking;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing ? 'Редактировать поездку' : 'Создать поездку',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (protected) ...[
              const Card(
                key: Key('driver_ride_protected_notice'),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Маршрут, время и количество мест нельзя '
                    'изменить после бронирования.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (protected)
              _ProtectedValue(
                label: 'Маршрут',
                value: '${_origin?.name ?? '—'} → ${_destination?.name ?? '—'}',
              )
            else ...[
              IntercityCitySelectionField(
                label: 'Откуда',
                value: _origin,
                onChanged: (value) => setState(() {
                  _origin = value;
                  _originHasCoordinates = true;
                }),
              ),
              const SizedBox(height: 12),
              IntercityCitySelectionField(
                label: 'Куда',
                value: _destination,
                onChanged: (value) => setState(() {
                  _destination = value;
                  _destinationHasCoordinates = true;
                }),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('driver_ride_date'),
                    onTap: protected ? null : _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Дата'),
                      child: Text(formatIntercityCalendarDate(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    key: const Key('driver_ride_time'),
                    onTap: protected ? null : _selectTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Время'),
                      child: Text(formatHourMinute24(_time.hour, _time.minute)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (protected)
              _ProtectedValue(label: 'Количество мест', value: '$_seats')
            else
              IntercitySeatsSelector(
                value: _seats,
                maximum: intercityRideMaximumSeats,
                onChanged: (value) => setState(() => _seats = value),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('driver_ride_price_per_seat'),
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Цена за место',
                suffixText: '₸',
              ),
            ),
            if (protected)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Новая цена не изменит сумму уже созданных бронирований.',
                ),
              ),
            SwitchListTile(
              key: const Key('driver_ride_luggage'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Багаж разрешён'),
              value: _allowsLuggage,
              onChanged: (value) => setState(() => _allowsLuggage = value),
            ),
            TextField(
              key: const Key('driver_ride_comment'),
              controller: _commentController,
              maxLength: intercityRideMaximumCommentLength,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('driver_ride_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                key: const Key('driver_ride_submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.editing ? 'Сохранить' : 'Опубликовать поездку',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProtectedValue extends StatelessWidget {
  const _ProtectedValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label, enabled: false),
    child: Text(value),
  );
}

DateTime _defaultDeparture() {
  final future = _kazakhstanNow().add(const Duration(hours: 2));
  return DateTime.utc(
    future.year,
    future.month,
    future.day,
    future.hour - 5,
    future.minute,
  );
}

DateTime _kazakhstanNow() =>
    DateTime.now().toUtc().add(const Duration(hours: 5));

KazakhstanSettlement? _settlementFromRide(IntercityRide? ride, bool origin) {
  if (ride == null) return null;
  final name = origin ? ride.originCity : ride.destinationCity;
  final lat = origin ? ride.originLat : ride.destinationLat;
  final lng = origin ? ride.originLng : ride.destinationLng;
  return KazakhstanSettlement(
    id: 'ride-${origin ? 'origin' : 'destination'}',
    name: name,
    region: '',
    lat: lat ?? 0,
    lng: lng ?? 0,
  );
}

String _cityKey(String value) => value
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase()
    .replaceAll('ё', 'е');

String intercityDriverErrorMessage(Object error) {
  if (error is TulparApiException) {
    return switch (error.statusCode) {
      400 => 'Проверьте данные поездки.',
      401 => 'Войдите в аккаунт и повторите.',
      403 => 'Доступ водителя не активен.',
      404 => 'Поездка не найдена.',
      409 => 'Поездка уже изменилась. Обновите данные.',
      _ => 'Не удалось сохранить поездку.',
    };
  }
  if (error is TimeoutException) {
    return 'Сервер не ответил. Повторите позже.';
  }
  return 'Не удалось сохранить поездку.';
}
