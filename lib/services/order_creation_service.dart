import 'dart:async';

import 'package:latlong2/latlong.dart';

import 'minimum_fare_service.dart';
import 'tulpar_api_client.dart';
import '../utils/formatters.dart';

enum OrderCreationFailure {
  notAuthenticated,
  activeOrderExists,
  belowMinimumFare,
  invalidData,
  permissionDenied,
  unavailable,
  unknown,
}

class OrderCreationException implements Exception {
  const OrderCreationException(
    this.failure,
    this.userMessage, {
    this.cause,
    this.activeOrderId,
    this.minimumFare,
  });

  final OrderCreationFailure failure;
  final String userMessage;
  final Object? cause;
  final String? activeOrderId;
  final int? minimumFare;

  @override
  String toString() => 'OrderCreationException($failure, cause: $cause)';
}

class OrderDraft {
  const OrderDraft({
    required this.fromAddress,
    required this.toAddress,
    required this.price,
    required this.fromPoint,
    required this.toPoint,
    required this.cityId,
    this.serviceType = 'city',
    this.delivery,
    this.intercity,
  });

  final String fromAddress;
  final String toAddress;
  final int price;
  final LatLng fromPoint;
  final LatLng toPoint;
  final String cityId;
  final String serviceType;
  final DeliveryOrderDetails? delivery;
  final IntercityOrderDetails? intercity;

  void validate() {
    final from = fromAddress.trim();
    final to = toAddress.trim();

    final coordinates = [
      fromPoint.latitude,
      fromPoint.longitude,
      toPoint.latitude,
      toPoint.longitude,
    ];

    final coordinatesAreValid =
        coordinates.every((coordinate) => coordinate.isFinite) &&
        fromPoint.latitude >= -90 &&
        fromPoint.latitude <= 90 &&
        toPoint.latitude >= -90 &&
        toPoint.latitude <= 90 &&
        fromPoint.longitude >= -180 &&
        fromPoint.longitude <= 180 &&
        toPoint.longitude >= -180 &&
        toPoint.longitude <= 180;

    if (from.isEmpty ||
        from.length > 300 ||
        to.isEmpty ||
        to.length > 300 ||
        price <= 0 ||
        price > 1000000 ||
        cityId.trim().isEmpty ||
        !coordinatesAreValid) {
      throw const OrderCreationException(
        OrderCreationFailure.invalidData,
        'Проверьте адреса, цену и точки маршрута.',
      );
    }

    if (serviceType != 'city' &&
        serviceType != 'delivery' &&
        serviceType != 'intercity') {
      throw const OrderCreationException(
        OrderCreationFailure.invalidData,
        'Выберите доступный тип услуги.',
      );
    }

    if (serviceType == 'delivery') {
      delivery?.validate();
      if (delivery == null) {
        throw const OrderCreationException(
          OrderCreationFailure.invalidData,
          'Заполните данные доставки.',
        );
      }
    }

    if (serviceType == 'intercity') {
      intercity?.validate();
      if (intercity == null) {
        throw const OrderCreationException(
          OrderCreationFailure.invalidData,
          'Заполните данные междугородней поездки.',
        );
      }
    }
  }

  Map<String, Object?> toFirestore({
    required String passengerId,
    required Object createdAt,
  }) {
    return {
      'passengerId': passengerId,
      'fromAddress': fromAddress.trim(),
      'toAddress': toAddress.trim(),
      'price': price,
      'passengerPrice': price,
      'agreedPrice': null,
      'fromLat': fromPoint.latitude,
      'fromLng': fromPoint.longitude,
      'toLat': toPoint.latitude,
      'toLng': toPoint.longitude,
      'status': 'searching',
      'createdAt': createdAt,
    };
  }
}

class IntercityOrderDetails {
  const IntercityOrderDetails({
    required this.scheduledAt,
    required this.passengerCount,
    required this.hasLuggage,
    this.comment = '',
  });

  final DateTime scheduledAt;
  final int passengerCount;
  final bool hasLuggage;
  final String comment;

  void validate({DateTime? now}) {
    final currentInstant = (now ?? DateTime.now()).toUtc();
    if (passengerCount < 1 ||
        passengerCount > 8 ||
        comment.trim().length > 500 ||
        !scheduledAt.toUtc().isAfter(currentInstant)) {
      throw const OrderCreationException(
        OrderCreationFailure.invalidData,
        'Выберите будущее время и проверьте данные поездки.',
      );
    }
  }

  String get departureAtIso => scheduledAt.toUtc().toIso8601String();
}

const Duration kazakhstanUtcOffset = Duration(hours: 5);

DateTime kazakhstanWallClock([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().add(kazakhstanUtcOffset);

DateTime kazakhstanDepartureUtc({
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
}) =>
    DateTime.utc(year, month, day, hour, minute).subtract(kazakhstanUtcOffset);

String formatHourMinute24(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:'
    '${minute.toString().padLeft(2, '0')}';

class DeliveryOrderDetails {
  const DeliveryOrderDetails({
    required this.itemDescription,
    required this.recipientName,
    required this.recipientPhone,
    this.destinationApartment = '',
  });

  final String itemDescription;
  final String recipientName;
  final String recipientPhone;
  final String destinationApartment;

  void validate() {
    if (itemDescription.trim().isEmpty ||
        itemDescription.trim().length > 500 ||
        recipientName.trim().isEmpty ||
        recipientName.trim().length > 150 ||
        destinationApartment.trim().length > 30 ||
        !isCompleteRuPhone(recipientPhone)) {
      throw const OrderCreationException(
        OrderCreationFailure.invalidData,
        'Заполните описание посылки, имя и телефон получателя.',
      );
    }
  }

  String get normalizedRecipientPhone => normalizeRuPhone(recipientPhone);
}

abstract interface class OrderCreationGateway {
  Future<String> create(OrderDraft draft);
}

class VpsOrderCreationGateway implements OrderCreationGateway {
  VpsOrderCreationGateway({TulparApiClient? apiClient})
    : _apiClient = apiClient ?? TulparApiClient();

  final TulparApiClient _apiClient;

  @override
  Future<String> create(OrderDraft draft) async {
    draft.validate();

    try {
      final result = await _apiClient.createOrder(
        serviceType: draft.serviceType,
        passengerPrice: draft.price,
        pickupAddress: draft.fromAddress.trim(),
        destinationAddress: draft.toAddress.trim(),
        pickupLat: draft.fromPoint.latitude,
        pickupLng: draft.fromPoint.longitude,
        destinationLat: draft.toPoint.latitude,
        destinationLng: draft.toPoint.longitude,
        itemDescription: draft.delivery?.itemDescription,
        recipientName: draft.delivery?.recipientName,
        recipientPhone: draft.delivery?.normalizedRecipientPhone,
        destinationApartment: draft.delivery?.destinationApartment.trim(),
        departureAt: draft.intercity?.departureAtIso,
        passengerCount: draft.intercity?.passengerCount,
        hasLuggage: draft.intercity?.hasLuggage,
        comment: draft.intercity?.comment.trim(),
      );

      final id = result['id'];

      if (id is! String || id.isEmpty) {
        throw const OrderCreationException(
          OrderCreationFailure.unknown,
          'Сервер создал заказ, но не вернул его идентификатор.',
        );
      }

      return id;
    } on TulparApiException catch (error) {
      if (error.statusCode == 401) {
        throw OrderCreationException(
          OrderCreationFailure.notAuthenticated,
          'Войдите в аккаунт и повторите попытку.',
          cause: error,
        );
      }

      if (error.statusCode == 403) {
        throw OrderCreationException(
          OrderCreationFailure.permissionDenied,
          'Нет доступа к созданию заказа.',
          cause: error,
        );
      }

      if (error.statusCode == 409) {
        throw OrderCreationException(
          OrderCreationFailure.activeOrderExists,
          'У вас уже есть активный заказ.',
          cause: error,
        );
      }

      if (error.statusCode == 400) {
        final minimumFare = error.data?['minimumFare'];

        if (minimumFare is int) {
          throw OrderCreationException(
            OrderCreationFailure.belowMinimumFare,
            'Минимальная стоимость поездки сейчас — $minimumFare ₸.',
            cause: error,
            minimumFare: minimumFare,
          );
        }

        throw OrderCreationException(
          OrderCreationFailure.invalidData,
          error.message,
          cause: error,
        );
      }

      throw OrderCreationException(
        OrderCreationFailure.unknown,
        'Не удалось создать заказ. Попробуйте ещё раз.',
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw OrderCreationException(
        OrderCreationFailure.unavailable,
        'Нет связи с сервером. Попробуйте ещё раз.',
        cause: error,
      );
    }
  }
}

class OrderCreationService {
  OrderCreationService({
    OrderCreationGateway? gateway,
    MinimumFareService? minimumFareService,
  }) : _gateway = gateway ?? VpsOrderCreationGateway(),
       _minimumFareService = minimumFareService ?? MinimumFareService();

  final OrderCreationGateway _gateway;
  final MinimumFareService _minimumFareService;

  Future<String>? _inFlight;

  int get currentMinimumFare => _minimumFareService.currentMinimumFare;

  int priceWithCurrentMinimum(int proposedPrice) =>
      _minimumFareService.priceWithMinimum(proposedPrice);

  String minimumFareMessage(int minimumFare) =>
      _minimumFareService.messageForMinimum(minimumFare);

  Future<String> createOrder({
    required String fromAddress,
    required String toAddress,
    required int price,
    required LatLng fromPoint,
    required LatLng toPoint,
    required String cityId,
    String serviceType = 'city',
    DeliveryOrderDetails? delivery,
    IntercityOrderDetails? intercity,
  }) {
    final current = _inFlight;

    if (current != null) {
      return current;
    }

    final draft = OrderDraft(
      fromAddress: fromAddress,
      toAddress: toAddress,
      price: price,
      fromPoint: fromPoint,
      toPoint: toPoint,
      cityId: cityId,
      serviceType: serviceType,
      delivery: delivery,
      intercity: intercity,
    );

    final operation = _create(draft);

    _inFlight = operation;

    return operation;
  }

  Future<String> _create(OrderDraft draft) async {
    try {
      draft.validate();

      final minimumFare = _minimumFareService.currentMinimumFare;

      if (draft.serviceType == 'city' && draft.price < minimumFare) {
        throw OrderCreationException(
          OrderCreationFailure.belowMinimumFare,
          _minimumFareService.messageForMinimum(minimumFare),
          minimumFare: minimumFare,
        );
      }

      return await _gateway.create(draft);
    } finally {
      _inFlight = null;
    }
  }
}

String orderCreationUserMessage(Object error) {
  return error is OrderCreationException
      ? error.userMessage
      : 'Не удалось создать заказ. Попробуйте ещё раз.';
}
