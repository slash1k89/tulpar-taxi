import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TulparApiException implements Exception {
  const TulparApiException(this.statusCode, this.message, {this.data});

  final int statusCode;
  final String message;
  final Map<String, dynamic>? data;

  @override
  String toString() => 'TulparApiException($statusCode, $message)';
}

class TulparApiClient {
  TulparApiClient({FirebaseAuth? auth, http.Client? client})
    : _auth = auth ?? FirebaseAuth.instance,
      _client = client ?? http.Client();

  static const String baseUrl = 'https://212.19.134.57';

  final FirebaseAuth _auth;
  final http.Client _client;

  Future<String> _token() async {
    final user = _auth.currentUser;

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

    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TulparApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Ошибка сервера',
        data: body,
      );
    }

    return body;
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

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final raw = await _getApi('/api/users/me');

    if (raw is! Map) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(raw);
  }

  Future<void> syncCurrentUser({String? name, String? phone}) async {
    final body = <String, dynamic>{};

    final normalizedName = name?.trim() ?? '';
    final normalizedPhone = phone?.trim() ?? '';

    if (normalizedName.isNotEmpty) {
      body['name'] = normalizedName;
    }

    if (normalizedPhone.isNotEmpty) {
      body['phone'] = normalizedPhone;
    }

    final response = await _client
        .post(
          Uri.parse('$baseUrl/api/users/sync'),
          headers: await _headers(),
          body: body.isEmpty ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    await _decode(response);
  }

  Future<Map<String, dynamic>> createCityOrder({
    required int passengerPrice,
    required String pickupAddress,
    required String destinationAddress,
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    await syncCurrentUser();

    final response = await _client
        .post(
          Uri.parse('$baseUrl/api/orders'),
          headers: await _headers(),
          body: jsonEncode({
            'serviceType': 'city',
            'passengerPrice': passengerPrice,
            'pickupAddress': pickupAddress,
            'destinationAddress': destinationAddress,
            'pickupLat': pickupLat,
            'pickupLng': pickupLng,
            'destinationLat': destinationLat,
            'destinationLng': destinationLng,
          }),
        )
        .timeout(const Duration(seconds: 10));

    return _decode(response);
  }

  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/api/orders/$orderId/details'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 8));

    final data = await _decode(response);

    // ?????????? ????? VPS API ? ???????,
    // ??????? ???? ??????? ???????????? Flutter UI.
    final driver = data['driver'];
    final passenger = data['passenger'];

    final rawStatus = data['status']?.toString() ?? 'searching';
    final legacyStatus = rawStatus == 'driver_arrived' ? 'arrived' : rawStatus;

    return {
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

      'delivery': data['delivery'],
      'intercity': data['intercity'],

      'createdAt': data['createdAt'],
      'acceptedAt': data['acceptedAt'],
      'driverArrivedAt': data['driverArrivedAt'],
      'startedAt': data['startedAt'],
      'completedAt': data['completedAt'],
      'cancelledAt': data['cancelledAt'],
    };
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

    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 8));

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
        body['error']?.toString() ?? '????? ???????? ???????',
        data: body,
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw const TulparApiException(
        500,
        '?????? ?????? ???????????? ?????? ???????.',
      );
    }

    return decoded
        .whereType<Map>()
        .map((item) => _availableOrderToLegacy(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, dynamic> _availableOrderToLegacy(Map<String, dynamic> data) {
    return {
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

      'distanceMeters': data['distanceMeters'],
      'createdAt': data['createdAt'],

      'delivery': data['delivery'],
      'intercity': data['intercity'],
    };
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

  Future<dynamic> _getApi(String path) async {
    final response = await _client
        .get(Uri.parse('$baseUrl$path'), headers: await _headers())
        .timeout(const Duration(seconds: 8));

    dynamic body;

    if (response.body.isNotEmpty) {
      body = jsonDecode(response.body);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final map = body is Map
          ? Map<String, dynamic>.from(body)
          : <String, dynamic>{};

      throw TulparApiException(
        response.statusCode,
        map['error']?.toString() ?? '????? ???????',
        data: map,
      );
    }

    return body;
  }

  Future<Map<String, dynamic>> _patchApi(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    Map<String, dynamic> decoded = {};

    if (response.body.isNotEmpty) {
      final raw = jsonDecode(response.body);

      if (raw is Map) {
        decoded = Map<String, dynamic>.from(raw);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TulparApiException(
        response.statusCode,
        decoded['error']?.toString() ?? '?????? ???????',
        data: decoded,
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> _postApi(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    Map<String, dynamic> decoded = {};

    if (response.body.isNotEmpty) {
      final raw = jsonDecode(response.body);

      if (raw is Map) {
        decoded = Map<String, dynamic>.from(raw);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TulparApiException(
        response.statusCode,
        decoded['error']?.toString() ?? '????? ???????',
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

  Future<Map<String, dynamic>> driverArrived(String orderId) {
    return _postApi('/api/orders/$orderId/arrive');
  }

  Future<Map<String, dynamic>> startRide(String orderId) {
    return _postApi('/api/orders/$orderId/start');
  }

  Future<Map<String, dynamic>> completeRide(String orderId) {
    return _postApi('/api/orders/$orderId/complete');
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId) {
    return _postApi('/api/orders/$orderId/cancel');
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

    return Map<String, dynamic>.from(active);
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

    return Map<String, dynamic>.from(active);
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

  Future<void> sendChatMessage({
    required String orderId,
    required String text,
  }) async {
    await _postApi('/api/orders/$orderId/messages', body: {'text': text});
  }

  Future<void> submitRating({
    required String orderId,
    required int score,
  }) async {
    await _postApi('/api/orders/$orderId/rating', body: {'score': score});
  }

  Future<void> registerPushToken({
    required String token,
    String platform = 'android',
  }) async {
    await _postApi(
      '/api/push/token',
      body: {'token': token, 'platform': platform},
    );
  }
}
