import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'api_config.dart';
import 'tulpar_auth_session.dart';

import '../models/next_order.dart';
import '../models/order_stops.dart';

class TulparApiException implements Exception {
  const TulparApiException(this.statusCode, this.message, {this.data});

  final int statusCode;
  final String message;
  final Map<String, dynamic>? data;

  int? get retryAfterSeconds {
    final value = data?['retryAfterSeconds'];
    if (value is int && value > 0) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  String toString() => 'TulparApiException($statusCode, $message)';
}

Map<String, dynamic>? normalizeDeliveryData(Object? rawDelivery) {
  if (rawDelivery is! Map) return null;

  final delivery = Map<String, dynamic>.from(rawDelivery);
  return {
    ...delivery,
    'itemDescription':
        delivery['itemDescription'] ?? delivery['item_description'],
    'recipientName': delivery['recipientName'] ?? delivery['recipient_name'],
    'recipientPhone': delivery['recipientPhone'] ?? delivery['recipient_phone'],
    'destinationApartment':
        delivery['destinationApartment'] ?? delivery['destination_apartment'],
  };
}

Map<String, dynamic>? normalizeIntercityData(Object? rawIntercity) {
  if (rawIntercity is! Map) return null;

  final intercity = Map<String, dynamic>.from(rawIntercity);
  final departureAt =
      intercity['departureAt'] ??
      intercity['departure_at'] ??
      intercity['scheduledAt'] ??
      intercity['scheduled_at'];
  return {
    ...intercity,
    'departureAt': departureAt,
    'scheduledAt': departureAt,
    'passengerCount':
        intercity['passengerCount'] ?? intercity['passenger_count'],
    'hasLuggage': intercity['hasLuggage'] ?? intercity['has_luggage'],
    'comment': intercity['comment'],
  };
}

Map<String, dynamic>? normalizeOrderIntercityData(Map<String, dynamic> order) {
  if (order['serviceType']?.toString() != 'intercity') return null;
  return normalizeIntercityData(order['intercity'] ?? order);
}

Map<String, dynamic> normalizeOrderLifecycleData(Map<String, dynamic> order) {
  return normalizeOrderStops({
    ...order,
    'queuedAfterOrderId':
        order['queuedAfterOrderId'] ?? order['queued_after_order_id'],
  });
}

Map<String, dynamic> buildOrderCreationPayload({
  required String serviceType,
  String? cityId,
  required int passengerPrice,
  required String pickupAddress,
  required String destinationAddress,
  required double pickupLat,
  required double pickupLng,
  required double destinationLat,
  required double destinationLng,
  String? itemDescription,
  String? recipientName,
  String? recipientPhone,
  String? destinationApartment,
  String? departureAt,
  int? passengerCount,
  bool? hasLuggage,
  String? comment,
  List<Map<String, Object?>> stops = const [],
}) {
  return {
    'serviceType': serviceType,
    if (serviceType == 'city' || serviceType == 'delivery')
      'cityId': cityId ?? 'esil',
    'passengerPrice': passengerPrice,
    'pickupAddress': pickupAddress,
    'destinationAddress': destinationAddress,
    'pickupLat': pickupLat,
    'pickupLng': pickupLng,
    'destinationLat': destinationLat,
    'destinationLng': destinationLng,
    if (serviceType == 'city' && stops.isNotEmpty) 'stops': stops,
    if (serviceType == 'delivery') ...{
      'itemDescription': itemDescription?.trim(),
      'recipientName': recipientName?.trim(),
      'recipientPhone': recipientPhone?.trim(),
      if (destinationApartment?.trim().isNotEmpty == true)
        'destinationApartment': destinationApartment!.trim(),
    },
    if (serviceType == 'intercity') ...{
      'departureAt': departureAt,
      'passengerCount': passengerCount,
      'hasLuggage': hasLuggage,
      if (comment?.trim().isNotEmpty == true) 'comment': comment!.trim(),
    },
  };
}

class TulparApiClient {
  TulparApiClient({
    FirebaseAuth? auth,
    http.Client? client,
    Future<String> Function()? tokenProvider,
    TulparAuthController? tulparAuth,
    Duration accountDeletionTimeout = const Duration(seconds: 12),
  }) : _auth = auth,
       _client = client ?? http.Client(),
       _tokenProvider = tokenProvider,
       _tulparAuth = tulparAuth ?? TulparAuthController.instance,
       _accountDeletionTimeout = accountDeletionTimeout;

  static const String baseUrl = TulparApiConfig.baseUrl;

  final FirebaseAuth? _auth;
  final http.Client _client;
  final Future<String> Function()? _tokenProvider;
  final TulparAuthController _tulparAuth;
  final Duration _accountDeletionTimeout;

  void close() => _client.close();

  Future<String> _token() async {
    if (_tokenProvider != null) return _tokenProvider();
    if (_tulparAuth.hasSession) return _tulparAuth.validAccessToken();
    final user = (_auth ?? FirebaseAuth.instance).currentUser;

    if (user == null) {
      throw const TulparApiException(401, 'Пользователь не авторизован.');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw const TulparApiException(
        401,
        'Не удалось получить токен авторизации.',
      );
    }

    return token;
  }

  Future<http.Response> _sendAuthenticated(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    final firstHeaders = await _headers();
    final firstToken = firstHeaders['Authorization']!.substring(7);
    var response = await send(firstHeaders);
    if (response.statusCode != 401 ||
        _tokenProvider != null ||
        !_tulparAuth.hasSession) {
      return response;
    }
    await _tulparAuth.refreshAfterUnauthorized(firstToken);
    response = await send(await _headers());
    return response;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _token();

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    Map<String, dynamic> body = {};
    final decoded = _decodeResponseBody(response);
    if (decoded is Map) body = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TulparApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Ошибка сервера',
        data: body,
      );
    }

    if (decoded != null && decoded is! Map) {
      throw const TulparApiException(502, 'Некорректный ответ сервера');
    }

    return body;
  }

  dynamic _decodeResponseBody(http.Response response) {
    final text = response.body.trim();
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      throw TulparApiException(
        response.statusCode >= 200 && response.statusCode < 300
            ? 502
            : response.statusCode,
        'Сервер вернул ответ в неподдерживаемом формате',
      );
    }
  }

  Future<Map<String, dynamic>> getConfig() async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/api/config'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 8));

    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> getEnabledCities() async {
    final raw = await _getApi('/api/cities');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>?> getCurrentDriverProfile() async {
    try {
      final raw = await _getApi('/api/driver-profile/me');

      if (raw is! Map) {
        return null;
      }

      return Map<String, dynamic>.from(raw);
    } on TulparApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  Future<String> updateDriverWorkCity(String cityId) async {
    final result = await _postApi(
      '/api/driver-profile/work-city',
      body: {'cityId': cityId},
    );
    return result['cityId']?.toString() ?? cityId;
  }

  Future<Map<String, dynamic>> createCurrentDriverDraft() {
    return _postApi('/api/driver-profile/draft');
  }

  Future<Map<String, dynamic>> acceptCurrentDriverAgreement() {
    return _postApi('/api/driver-profile/agreement');
  }

  Future<Map<String, dynamic>> submitCurrentDriverVehicle({
    required String carModel,
    required String carColor,
    required String carNumber,
  }) {
    return _postApi(
      '/api/driver-profile/vehicle',
      body: {
        'carModel': carModel.trim(),
        'carColor': carColor.trim(),
        'carNumber': carNumber.trim().toUpperCase(),
      },
    );
  }

  Future<Map<String, dynamic>> updateCurrentDriverVehicleModel({
    required String carModel,
  }) {
    return _patchApi(
      '/api/driver-profile/vehicle-model',
      body: {'carModel': carModel.trim()},
    );
  }

  Future<Map<String, dynamic>> updateCurrentUserProfile({
    required String name,
  }) {
    return _patchApi('/api/users/me', body: {'name': name.trim()});
  }

  Future<void> updateCurrentUserLocale(String locale) async {
    if (!const {'ru', 'kk', 'en'}.contains(locale)) {
      throw ArgumentError.value(locale, 'locale');
    }
    await _patchApi('/api/users/me/locale', body: {'locale': locale});
  }

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final raw = await _getApi('/api/users/me');

    if (raw is! Map) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(raw);
  }

  Future<void> syncCurrentUser({String? name, String? phone}) async {
    if (_tokenProvider == null && _tulparAuth.hasSession) {
      if (name?.trim().isNotEmpty == true) {
        await updateCurrentUserProfile(name: name!.trim());
      }
      return;
    }
    final body = <String, dynamic>{};

    final normalizedName = name?.trim() ?? '';
    final normalizedPhone = phone?.trim() ?? '';

    if (normalizedName.isNotEmpty) {
      body['name'] = normalizedName;
    }

    if (normalizedPhone.isNotEmpty) {
      body['phone'] = normalizedPhone;
    }

    final response = await _sendAuthenticated(
      (headers) => _client.post(
        Uri.parse('$baseUrl/api/users/sync'),
        headers: headers,
        body: body.isEmpty ? null : jsonEncode(body),
      ),
    ).timeout(const Duration(seconds: 8));

    await _decode(response);
  }

  Future<Map<String, dynamic>> createOrder({
    String serviceType = 'city',
    String? cityId,
    required int passengerPrice,
    required String pickupAddress,
    required String destinationAddress,
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    String? itemDescription,
    String? recipientName,
    String? recipientPhone,
    String? destinationApartment,
    String? departureAt,
    int? passengerCount,
    bool? hasLuggage,
    String? comment,
    List<Map<String, Object?>> stops = const [],
  }) async {
    await syncCurrentUser();

    final response = await _sendAuthenticated(
      (headers) => _client.post(
        Uri.parse('$baseUrl/api/orders'),
        headers: headers,
        body: jsonEncode(
          buildOrderCreationPayload(
            serviceType: serviceType,
            cityId: cityId,
            passengerPrice: passengerPrice,
            pickupAddress: pickupAddress,
            destinationAddress: destinationAddress,
            pickupLat: pickupLat,
            pickupLng: pickupLng,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
            itemDescription: itemDescription,
            recipientName: recipientName,
            recipientPhone: recipientPhone,
            destinationApartment: destinationApartment,
            departureAt: departureAt,
            passengerCount: passengerCount,
            hasLuggage: hasLuggage,
            comment: comment,
            stops: stops,
          ),
        ),
      ),
    ).timeout(const Duration(seconds: 10));

    return _decode(response);
  }

  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    final response = await _sendAuthenticated(
      (headers) => _client.get(
        Uri.parse('$baseUrl/api/orders/$orderId/details'),
        headers: headers,
      ),
    ).timeout(const Duration(seconds: 8));

    final data = await _decode(response);

    // ?????????? ????? VPS API ? ???????,
    // ??????? ???? ??????? ???????????? Flutter UI.
    final driver = data['driver'];
    final passenger = data['passenger'];

    final rawStatus = data['status']?.toString() ?? 'searching';
    final legacyStatus = rawStatus == 'driver_arrived' ? 'arrived' : rawStatus;

    return normalizeOrderLifecycleData({
      ...data,
      'id': data['id'],
      'serviceType': data['serviceType'],
      'status': legacyStatus,

      'price': data['passengerPrice'],
      'passengerPrice': data['passengerPrice'],
      'agreedPrice': data['agreedPrice'],

      'fromAddress': data['pickupAddress'],
      'toAddress': data['destinationAddress'],

      'fromLat': data['pickupLat'],
      'fromLng': data['pickupLng'],
      'toLat': data['destinationLat'],
      'toLng': data['destinationLng'],
      'stops': data['stops'],

      'distanceMeters': data['distanceMeters'],

      'passengerId': passenger is Map ? passenger['id'] : null,
      'passengerName': passenger is Map ? passenger['name'] : null,
      'passengerPhone': passenger is Map ? passenger['phone'] : null,

      'driverId': driver is Map ? driver['id'] : null,
      'driverName': driver is Map ? driver['name'] : null,
      'driverPhone': driver is Map ? driver['phone'] : null,

      'carModel': driver is Map ? driver['carModel'] : null,
      'carColor': driver is Map ? driver['carColor'] : null,
      'carNumber': driver is Map ? driver['carNumber'] : null,

      // Keep the live location returned by the VPS available to the
      // passenger tracking screen. Accept snake_case during the API rollout.
      'driverLat': data['driverLat'] ?? data['driver_lat'],
      'driverLng': data['driverLng'] ?? data['driver_lng'],
      'driverLocationUpdatedAt':
          data['driverLocationUpdatedAt'] ?? data['driver_location_updated_at'],

      'delivery': normalizeDeliveryData(data['delivery']),
      'intercity': normalizeOrderIntercityData(data),

      'createdAt': data['createdAt'],
      'acceptedAt': data['acceptedAt'],
      'driverArrivedAt': data['driverArrivedAt'],
      'startedAt': data['startedAt'],
      'completedAt': data['completedAt'],
      'cancelledAt': data['cancelledAt'],
    });
  }

  Stream<Map<String, dynamic>?> watchOrderDetails(
    String orderId, {
    Duration interval = const Duration(seconds: 2),
  }) async* {
    while (true) {
      yield await getOrderDetails(orderId);
      await Future<void>.delayed(interval);
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableOrders({
    String? serviceType,
  }) async {
    final uri = Uri.parse('$baseUrl/api/orders/available').replace(
      queryParameters: serviceType == null
          ? null
          : {'serviceType': serviceType},
    );

    final response = await _sendAuthenticated((headers) async {
      final abort = Completer<void>();
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: abort.future,
      )..headers.addAll(headers);
      Future<http.Response> send() async =>
          http.Response.fromStream(await _client.send(request));
      try {
        return await send().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            if (!abort.isCompleted) abort.complete();
            throw TimeoutException('Available orders request timed out');
          },
        );
      } catch (_) {
        if (!abort.isCompleted) abort.complete();
        rethrow;
      }
    });
    if (kDebugMode) {
      debugPrint('[DriverOrdersPoll] available HTTP=${response.statusCode}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> body = {};

      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      }

      throw TulparApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Ошибка загрузки заказов',
        data: body,
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw const TulparApiException(
        500,
        'Сервер вернул некорректный список заказов.',
      );
    }

    return decoded
        .whereType<Map>()
        .map((item) => _availableOrderToLegacy(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, dynamic> _availableOrderToLegacy(Map<String, dynamic> data) {
    return normalizeOrderLifecycleData({
      ...data,
      'id': data['id'],
      'serviceType': data['serviceType'],
      'status': 'searching',

      'price': data['passengerPrice'],
      'passengerPrice': data['passengerPrice'],

      'fromAddress': data['pickupAddress'],
      'toAddress': data['destinationAddress'],

      'fromLat': data['pickupLat'],
      'fromLng': data['pickupLng'],
      'toLat': data['destinationLat'],
      'toLng': data['destinationLng'],
      'stops': data['stops'],

      'distanceMeters': data['distanceMeters'],
      'createdAt': data['createdAt'],

      'delivery': normalizeDeliveryData(data['delivery']),
      'intercity': normalizeOrderIntercityData(data),
    });
  }

  Stream<List<Map<String, dynamic>>> watchAvailableOrders({
    String? serviceType,
    Duration interval = const Duration(seconds: 2),
  }) async* {
    while (true) {
      yield await getAvailableOrders(serviceType: serviceType);

      await Future<void>.delayed(interval);
    }
  }

  Future<List<NextOrderCandidate>> getNextOrderCandidates() async {
    final raw = await _getApi('/api/orders/next-candidates');
    if (raw is! List) {
      throw const TulparApiException(
        500,
        'Сервер вернул некорректный список следующих заказов.',
      );
    }
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              NextOrderCandidate.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<dynamic> _getApi(String path) async {
    final response = await _sendAuthenticated(
      (headers) => _client.get(Uri.parse('$baseUrl$path'), headers: headers),
    ).timeout(const Duration(seconds: 8));

    final body = _decodeResponseBody(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final map = body is Map
          ? Map<String, dynamic>.from(body)
          : <String, dynamic>{};

      throw TulparApiException(
        response.statusCode,
        map['error']?.toString() ?? 'Ошибка запроса',
        data: map,
      );
    }

    return body;
  }

  Future<Map<String, dynamic>> _patchApi(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _sendAuthenticated(
      (headers) => _client.patch(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    ).timeout(const Duration(seconds: 10));

    final raw = _decodeResponseBody(response);
    final decoded = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TulparApiException(
        response.statusCode,
        decoded['error']?.toString() ?? 'Ошибка запроса',
        data: decoded,
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> _postApi(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _sendAuthenticated(
      (headers) => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    ).timeout(const Duration(seconds: 10));

    final raw = _decodeResponseBody(response);
    final decoded = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TulparApiException(
        response.statusCode,
        decoded['error']?.toString() ?? 'Ошибка запроса',
        data: decoded,
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> submitOrderOffer({
    required String orderId,
    required int price,
  }) {
    return _postApi('/api/orders/$orderId/offers', body: {'price': price});
  }

  Future<List<Map<String, dynamic>>> getOrderOffers(String orderId) async {
    final raw = await _getApi('/api/orders/$orderId/offers');

    dynamic list = raw;

    if (raw is Map) {
      list = raw['offers'];
    }

    if (list is! List) {
      return const [];
    }

    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Stream<List<Map<String, dynamic>>> watchOrderOffers(
    String orderId, {
    Duration interval = const Duration(seconds: 2),
  }) async* {
    while (true) {
      yield await getOrderOffers(orderId);
      await Future<void>.delayed(interval);
    }
  }

  Future<Map<String, dynamic>> acceptOrderOffer({
    required String orderId,
    required String offerId,
  }) {
    return _postApi('/api/orders/$orderId/offers/$offerId/accept');
  }

  Future<Map<String, dynamic>> acceptOrder(String orderId) {
    return _postApi('/api/orders/$orderId/accept');
  }

  Future<NextOrderAcceptanceResult> acceptNextOrder(String orderId) async {
    final raw = await _postApi('/api/orders/$orderId/accept-next');
    return NextOrderAcceptanceResult.fromJson(raw);
  }

  Future<Map<String, dynamic>> driverArrived(String orderId) {
    return _postApi('/api/orders/$orderId/arrive');
  }

  Future<Map<String, dynamic>> startRide(String orderId) {
    return _postApi('/api/orders/$orderId/start');
  }

  Future<List<Map<String, dynamic>>> advanceOrderStop(String orderId) async {
    final raw = await _postApi('/api/orders/$orderId/stops/advance');
    final stops = raw['stops'];
    if (stops is! List) return const [];
    return stops
        .whereType<Map>()
        .map((stop) => Map<String, dynamic>.from(stop))
        .toList(growable: false);
  }

  Future<CompleteOrderResult> completeRide(String orderId) async {
    final raw = await _postApi('/api/orders/$orderId/complete');
    return CompleteOrderResult.fromJson(raw);
  }

  Future<Map<String, dynamic>> cancelOrder(
    String orderId, {
    String? reasonCode,
    String? reasonText,
  }) {
    return _postApi(
      '/api/orders/$orderId/cancel',
      body: reasonCode == null
          ? null
          : {'reasonCode': reasonCode, 'reasonText': ?reasonText},
    );
  }

  Future<Map<String, dynamic>?> getActiveCurrentOrder() async {
    final raw = await _getApi('/api/orders/active/me');

    if (raw is! Map) {
      return null;
    }

    final data = Map<String, dynamic>.from(raw);
    final active = data['activeOrder'];

    if (active is! Map) {
      return null;
    }

    return _enrichActiveDelivery(Map<String, dynamic>.from(active));
  }

  Future<Map<String, dynamic>?> getActiveDriverOrder() async {
    final raw = await _getApi('/api/orders/active/driver');

    if (raw is! Map) {
      return null;
    }

    final data = Map<String, dynamic>.from(raw);

    final active = data['activeOrder'];

    if (active is! Map) {
      return null;
    }

    return _enrichActiveDelivery(Map<String, dynamic>.from(active));
  }

  Future<Map<String, dynamic>> getRoute({
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
    List<LatLng> intermediatePoints = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/api/routing/route').replace(
      queryParameters: {
        'startLat': startLat.toString(),
        'startLng': startLng.toString(),
        'destLat': destLat.toString(),
        'destLng': destLng.toString(),
        if (intermediatePoints.isNotEmpty)
          'waypoints': intermediatePoints
              .map((point) => '${point.longitude},${point.latitude}')
              .join(';'),
      },
    );
    final response = await _sendAuthenticated(
      (headers) => _client.get(uri, headers: headers),
    ).timeout(const Duration(seconds: 8));
    final raw = _decodeResponseBody(response);
    final decoded = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TulparApiException(
        response.statusCode,
        decoded['error']?.toString() ?? 'Ошибка построения маршрута',
        data: decoded,
      );
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> searchGeocoding({
    required String query,
    required String kind,
    String? cityId,
    String? settlement,
    double? lat,
    double? lng,
  }) async {
    final parameters = <String, String>{
      'query': query,
      'kind': kind,
      if (settlement?.trim().isNotEmpty == true)
        'settlement': settlement!.trim(),
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
    };
    if (cityId != null) parameters['cityId'] = cityId;
    final uri = Uri.parse(
      '$baseUrl/api/geocoding/search',
    ).replace(queryParameters: parameters);
    final response = await _sendAuthenticated(
      (headers) => _client.get(uri, headers: headers),
    ).timeout(const Duration(seconds: 8));
    final decoded = await _decode(response);
    final results = decoded['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> reverseGeocoding({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/geocoding/reverse',
    ).replace(queryParameters: {'lat': lat.toString(), 'lng': lng.toString()});
    final response = await _sendAuthenticated(
      (headers) => _client.get(uri, headers: headers),
    ).timeout(const Duration(seconds: 8));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _enrichActiveDelivery(
    Map<String, dynamic> activeOrder,
  ) async {
    final normalizedDelivery = normalizeDeliveryData(activeOrder['delivery']);
    final normalizedIntercity = normalizeOrderIntercityData(activeOrder);
    final normalizedOrder = normalizeOrderLifecycleData({
      ...activeOrder,
      'delivery': normalizedDelivery,
      'intercity': normalizedIntercity,
    });

    if (activeOrder['serviceType']?.toString() == 'intercity') {
      final hasSchedule =
          normalizedIntercity?['departureAt']?.toString().isNotEmpty == true;
      if (hasSchedule) return normalizedOrder;

      final orderId = activeOrder['id']?.toString() ?? '';
      if (orderId.isEmpty) return normalizedOrder;
      try {
        final details = await getOrderDetails(orderId);
        return {...normalizedOrder, 'intercity': details['intercity']};
      } on TulparApiException {
        return normalizedOrder;
      } on TimeoutException {
        return normalizedOrder;
      }
    }

    if (activeOrder['serviceType']?.toString() != 'delivery') {
      return normalizedOrder;
    }

    final hasRecipientPhone =
        normalizedDelivery?['recipientPhone']?.toString().trim().isNotEmpty ==
        true;
    if (hasRecipientPhone) return normalizedOrder;

    final orderId = activeOrder['id']?.toString() ?? '';
    if (orderId.isEmpty) return normalizedOrder;

    try {
      final details = await getOrderDetails(orderId);
      return {
        ...normalizedOrder,
        'delivery': normalizeDeliveryData(details['delivery']),
      };
    } on TulparApiException {
      return normalizedOrder;
    } on TimeoutException {
      return normalizedOrder;
    }
  }

  Stream<Map<String, dynamic>?> watchActiveDriverOrder({
    Duration interval = const Duration(seconds: 2),
  }) async* {
    while (true) {
      yield await getActiveDriverOrder();

      await Future<void>.delayed(interval);
    }
  }

  Future<Map<String, dynamic>> updateDriverLocation({
    required String orderId,
    required double lat,
    required double lng,
  }) {
    return _postApi(
      '/api/orders/$orderId/location',
      body: {'lat': lat, 'lng': lng},
    );
  }

  Future<void> sendTestPush() async {
    await _postApi('/api/push/test');
  }

  Future<void> sendChatPush({
    required String orderId,
    required String text,
  }) async {
    await _postApi('/api/chat/push', body: {'orderId': orderId, 'text': text});
  }

  Future<List<Map<String, dynamic>>> getOrderHistory() async {
    final raw = await _getApi('/api/orders/history');

    if (raw is! Map) {
      return const [];
    }

    final orders = raw['orders'];

    if (orders is! List) {
      return const [];
    }

    return orders
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getChatMessages(String orderId) async {
    final raw = await _getApi('/api/orders/$orderId/messages');

    if (raw is! Map) {
      return const [];
    }

    final items = raw['messages'];

    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<int> getChatUnreadCount(String orderId) async {
    final raw = await _getApi('/api/orders/$orderId/messages/unread');
    if (raw is! Map) return 0;
    final count = raw['unreadCount'];
    return count is int && count >= 0 ? count : 0;
  }

  Future<void> markChatRead(String orderId) async {
    await _postApi('/api/orders/$orderId/messages/read', body: const {});
  }

  Future<void> sendChatMessage({
    required String orderId,
    required String text,
  }) async {
    await _postApi('/api/orders/$orderId/messages', body: {'text': text});
  }

  Future<List<Map<String, dynamic>>> getIntercityChatMessages(
    String bookingId,
  ) async {
    final raw = await _getApi('/api/intercity-bookings/$bookingId/messages');
    final items = raw is Map ? raw['messages'] : null;
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<int> getIntercityChatUnreadCount(String bookingId) async {
    final raw = await _getApi(
      '/api/intercity-bookings/$bookingId/messages/unread',
    );
    final count = raw is Map ? raw['unreadCount'] : null;
    return count is int && count >= 0 ? count : 0;
  }

  Future<void> markIntercityChatRead(String bookingId) async {
    await _postApi(
      '/api/intercity-bookings/$bookingId/messages/read',
      body: const {},
    );
  }

  Future<void> sendIntercityChatMessage({
    required String bookingId,
    required String text,
  }) async {
    await _postApi(
      '/api/intercity-bookings/$bookingId/messages',
      body: {'text': text},
    );
  }

  Future<void> submitRating({
    required String orderId,
    required int score,
    String? comment,
  }) async {
    final trimmed = comment?.trim();
    await _postApi(
      '/api/orders/$orderId/rating',
      body: {
        'score': score,
        if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
      },
    );
  }

  Future<Map<String, dynamic>> getAssignedDriverProfile(String orderId) async {
    final raw = await _getApi(
      '/api/orders/${Uri.encodeComponent(orderId)}/driver-profile',
    );
    if (raw is! Map) {
      throw const TulparApiException(
        502,
        'Не удалось загрузить профиль водителя.',
      );
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>> searchIntercityRides({
    required String originCity,
    required String destinationCity,
    required String travelDate,
    required int seats,
  }) async {
    final path = Uri(
      path: '/api/intercity-rides/search',
      queryParameters: {
        'originCity': originCity.trim(),
        'destinationCity': destinationCity.trim(),
        'travelDate': travelDate,
        'seats': seats.toString(),
      },
    ).toString();
    final raw = await _getApi(path);
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getIntercityRide(String rideId) async {
    final raw = await _getApi('/api/intercity-rides/$rideId');
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> bookIntercityRide({
    required String rideId,
    required int seats,
    required String clientRequestId,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? passengerComment,
  }) {
    final body = <String, dynamic>{
      'seats': seats,
      'clientRequestId': clientRequestId,
    };
    _addIntercityPickup(
      body,
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      passengerComment: passengerComment,
    );
    return _postApi('/api/intercity-rides/$rideId/book', body: body);
  }

  Future<Map<String, dynamic>> getMyIntercityBookings() async {
    final raw = await _getApi('/api/intercity-rides/bookings/mine');
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> cancelIntercityBooking(String bookingId) =>
      _postApi('/api/intercity-rides/bookings/$bookingId/cancel');

  Future<Map<String, dynamic>> createIntercityRideRequest({
    required String originCity,
    required String destinationCity,
    required String travelDate,
    required int seats,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? passengerComment,
  }) {
    final body = <String, dynamic>{
      'originCity': originCity.trim(),
      'destinationCity': destinationCity.trim(),
      'travelDate': travelDate,
      'seats': seats,
    };
    _addIntercityPickup(
      body,
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      passengerComment: passengerComment,
    );
    return _postApi('/api/intercity-rides/requests', body: body);
  }

  Future<Map<String, dynamic>> getMyIntercityRideRequests() async {
    final raw = await _getApi('/api/intercity-rides/requests/mine');
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> cancelIntercityRideRequest(String requestId) =>
      _postApi('/api/intercity-rides/requests/$requestId/cancel');

  Future<Map<String, dynamic>> createIntercityDriverRide(
    Map<String, dynamic> body,
  ) => _postApi('/api/intercity-rides', body: body);

  Future<Map<String, dynamic>> getMyIntercityDriverRides() async {
    final raw = await _getApi('/api/intercity-rides/mine');
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateIntercityDriverRide({
    required String rideId,
    required Map<String, dynamic> body,
  }) => _patchApi('/api/intercity-rides/$rideId', body: body);

  Future<Map<String, dynamic>> getIntercityDriverRideBookings(
    String rideId,
  ) async {
    final raw = await _getApi('/api/intercity-rides/$rideId/bookings');
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> markIntercityPickupReached({
    required String rideId,
    required String bookingId,
  }) => _postApi(
    '/api/intercity-rides/$rideId/bookings/$bookingId/pickup-reached',
  );

  Future<Map<String, dynamic>> cancelIntercityDriverRide(String rideId) =>
      _postApi('/api/intercity-rides/$rideId/cancel');

  Future<Map<String, dynamic>> departIntercityDriverRide(String rideId) =>
      _postApi('/api/intercity-rides/$rideId/depart');

  Future<Map<String, dynamic>> completeIntercityDriverRide(String rideId) =>
      _postApi('/api/intercity-rides/$rideId/complete');

  Future<void> registerPushToken({
    required String token,
    String platform = 'android',
    String? expectedUserId,
  }) async {
    final response = await _sendAuthenticated((headers) {
      if (expectedUserId != null) {
        final userId = _tulparAuth.hasSession
            ? _tulparAuth.currentUserId
            : (_auth ?? FirebaseAuth.instance).currentUser?.uid;
        if (expectedUserId != userId) {
          throw StateError('Push registration identity changed');
        }
      }
      return _client.post(
        Uri.parse('$baseUrl/api/push/token'),
        headers: headers,
        body: jsonEncode({'token': token, 'platform': platform}),
      );
    }).timeout(const Duration(seconds: 8));
    await _decode(response);
  }

  Future<Map<String, dynamic>> deleteCurrentAccount({String? password}) =>
      _deleteCurrentAccountRequest(
        password: password,
      ).timeout(_accountDeletionTimeout);

  Future<Map<String, dynamic>> _deleteCurrentAccountRequest({
    String? password,
  }) async {
    final response = await _sendAuthenticated(
      (headers) => _client.delete(
        Uri.parse('$baseUrl/api/account'),
        headers: headers,
        body: password == null ? null : jsonEncode({'password': password}),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getTermsStatus() async {
    final response = await _sendAuthenticated(
      (headers) =>
          _client.get(Uri.parse('$baseUrl/api/terms/status'), headers: headers),
    ).timeout(const Duration(seconds: 8));
    return _decode(response);
  }

  Future<Map<String, dynamic>> acceptTerms(String version) async {
    final response = await _sendAuthenticated(
      (headers) => _client.post(
        Uri.parse('$baseUrl/api/terms/accept'),
        headers: headers,
        body: jsonEncode({'version': version}),
      ),
    ).timeout(const Duration(seconds: 8));
    return _decode(response);
  }

  Future<Map<String, dynamic>> createContentReport({
    String? reportedUserId,
    required String contextType,
    required String reasonCode,
    String? reasonText,
    String? orderId,
    String? bookingId,
    String? orderMessageId,
    String? intercityMessageId,
    String? reviewId,
  }) {
    final body = <String, dynamic>{
      'contextType': contextType,
      'reasonCode': reasonCode,
    };
    if (reportedUserId != null) body['reportedUserId'] = reportedUserId;
    if (reasonText?.trim().isNotEmpty ?? false) {
      body['reasonText'] = reasonText!.trim();
    }
    if (orderId != null) body['orderId'] = orderId;
    if (bookingId != null) body['bookingId'] = bookingId;
    if (orderMessageId != null) body['orderMessageId'] = orderMessageId;
    if (intercityMessageId != null) {
      body['intercityMessageId'] = intercityMessageId;
    }
    if (reviewId != null) body['reviewId'] = reviewId;
    return _postApi('/api/compliance/reports', body: body);
  }

  Future<Map<String, dynamic>> blockUser(String userId) =>
      _postApi('/api/compliance/blocks', body: {'blockedUserId': userId});
}

void _addIntercityPickup(
  Map<String, dynamic> body, {
  String? pickupAddress,
  double? pickupLat,
  double? pickupLng,
  String? passengerComment,
}) {
  final address = pickupAddress?.trim() ?? '';
  if (address.isNotEmpty && pickupLat != null && pickupLng != null) {
    body['pickupAddress'] = address;
    body['pickupLat'] = pickupLat;
    body['pickupLng'] = pickupLng;
  }
  final comment = passengerComment?.trim() ?? '';
  if (comment.isNotEmpty) body['passengerComment'] = comment;
}
