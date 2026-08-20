import 'dart:async';

import 'package:latlong2/latlong.dart';

import 'minimum_fare_service.dart';
import 'tulpar_api_client.dart';

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
  });

  final String fromAddress;
  final String toAddress;
  final int price;
  final LatLng fromPoint;
  final LatLng toPoint;
  final String cityId;

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
      final result = await _apiClient.createCityOrder(
        passengerPrice: draft.price,
        pickupAddress: draft.fromAddress.trim(),
        destinationAddress: draft.toAddress.trim(),
        pickupLat: draft.fromPoint.latitude,
        pickupLng: draft.fromPoint.longitude,
        destinationLat: draft.toPoint.latitude,
        destinationLng: draft.toPoint.longitude,
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
    );

    final operation = _create(draft);

    _inFlight = operation;

    return operation;
  }

  Future<String> _create(OrderDraft draft) async {
    try {
      draft.validate();

      final minimumFare = _minimumFareService.currentMinimumFare;

      if (draft.price < minimumFare) {
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
