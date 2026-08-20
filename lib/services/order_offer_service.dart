import 'package:firebase_auth/firebase_auth.dart';

import 'order_price_service.dart';
import 'tulpar_api_client.dart';

class DriverOffer {
  const DriverOffer({
    this.offerId = '',
    required this.driverId,
    required this.price,
    required this.status,
    required this.driverName,
    required this.driverPhone,
    required this.carModel,
    required this.carColor,
    required this.carNumber,
    required this.driverRating,
    this.createdAt,
    this.updatedAt,
  });

  final String offerId;
  final String driverId;
  final int price;
  final String status;
  final String driverName;
  final String driverPhone;
  final String carModel;
  final String carColor;
  final String carNumber;
  final double driverRating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'pending';

  static DateTime? _timestamp(dynamic value) {
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  factory DriverOffer.fromMap(Map<String, dynamic> data) {
    final driver = data['driver'];

    dynamic read(String camel, String snake) {
      return data[camel] ?? data[snake];
    }

    dynamic driverRead(String key) {
      if (driver is Map) {
        return driver[key];
      }

      return null;
    }

    return DriverOffer(
      offerId:
          (read('id', 'id') ?? read('offerId', 'offer_id'))?.toString() ?? '',
      driverId:
          (read('driverId', 'driver_id') ?? driverRead('id'))?.toString() ?? '',
      price: OrderPriceService.readInteger(read('price', 'price')) ?? 0,
      status: read('status', 'status')?.toString() ?? '',
      driverName:
          (read('driverName', 'driver_name') ?? driverRead('name'))
              ?.toString() ??
          'Р вЂ™Р С•Р Т‘Р С‘РЎвЂљР ВµР В»РЎРЉ',
      driverPhone:
          (read('driverPhone', 'driver_phone') ?? driverRead('phone'))
              ?.toString() ??
          '',
      carModel:
          (read('carModel', 'car_model') ?? driverRead('carModel'))
              ?.toString() ??
          '',
      carColor:
          (read('carColor', 'car_color') ?? driverRead('carColor'))
              ?.toString() ??
          '',
      carNumber:
          (read('carNumber', 'car_number') ?? driverRead('carNumber'))
              ?.toString() ??
          '',
      driverRating:
          ((read('driverRating', 'driver_rating') ?? driverRead('rating'))
                  as num?)
              ?.toDouble() ??
          5.0,
      createdAt: _timestamp(read('createdAt', 'created_at')),
      updatedAt: _timestamp(read('updatedAt', 'updated_at')),
    );
  }
}

class OrderOfferException implements Exception {
  const OrderOfferException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OrderOfferService {
  OrderOfferService({FirebaseAuth? auth, TulparApiClient? apiClient})
    : _auth = auth ?? FirebaseAuth.instance,
      _apiClient = apiClient ?? TulparApiClient();

  final FirebaseAuth _auth;
  final TulparApiClient _apiClient;

  Stream<DriverOffer?> watchOwnOffer(String orderId) async* {
    final user = _requireUser();

    await for (final offers in _apiClient.watchOrderOffers(orderId)) {
      DriverOffer? own;

      for (final raw in offers) {
        final offer = DriverOffer.fromMap(raw);

        if (offer.driverId == user.uid) {
          own = offer;
          break;
        }
      }

      yield own;
    }
  }

  Stream<List<DriverOffer>> watchPendingOffers(String orderId) {
    return _apiClient.watchOrderOffers(orderId).map((items) {
      final offers = items
          .map(DriverOffer.fromMap)
          .where((offer) => offer.isPending && offer.price > 0)
          .toList();

      offers.sort((left, right) {
        final byPrice = left.price.compareTo(right.price);

        if (byPrice != 0) {
          return byPrice;
        }

        final leftTime = left.createdAt?.millisecondsSinceEpoch ?? 0;

        final rightTime = right.createdAt?.millisecondsSinceEpoch ?? 0;

        return leftTime.compareTo(rightTime);
      });

      return offers;
    });
  }

  Future<void> submitOffer({
    required String orderId,
    required int price,
  }) async {
    _requireUser();

    if (price <= 0 || price > OrderPriceService.maximumOrderPrice) {
      throw const OrderOfferException(
        'Р Р€Р С”Р В°Р В¶Р С‘РЎвЂљР Вµ Р С”Р С•РЎР‚РЎР‚Р ВµР С”РЎвЂљР Р…РЎС“РЎР‹ РЎвЂ Р ВµР Р…РЎС“.',
      );
    }

    try {
      await _apiClient.submitOrderOffer(orderId: orderId, price: price);
    } on TulparApiException catch (error) {
      throw OrderOfferException(_messageForApiError(error));
    }
  }

  Future<void> acceptOffer({
    required String orderId,
    required String driverId,
  }) async {
    _requireUser();

    try {
      final offers = await _apiClient.getOrderOffers(orderId);

      String? offerId;

      for (final raw in offers) {
        final offer = DriverOffer.fromMap(raw);

        if (offer.driverId == driverId && offer.status == 'pending') {
          offerId = offer.offerId;
          break;
        }
      }

      if (offerId == null || offerId.isEmpty) {
        throw const OrderOfferException(
          'РЎР‚Р ВµР Т‘Р В»Р С•Р В¶Р ВµР Р…Р С‘Р Вµ Р Р†Р С•Р Т‘Р С‘РЎвЂљР ВµР В»РЎРЏ Р В±Р С•Р В»РЎРЉРЎв‚¬Р Вµ Р Р…Р ВµР Т‘Р С•РЎРѓРЎвЂљРЎС“Р С—Р Р…Р С•.',
        );
      }

      await _apiClient.acceptOrderOffer(orderId: orderId, offerId: offerId);
    } on OrderOfferException {
      rethrow;
    } on TulparApiException catch (error) {
      throw OrderOfferException(_messageForApiError(error));
    }
  }

  static void validateOfferPrice(int price, {required int passengerPrice}) {
    if (price <= passengerPrice) {
      throw const OrderOfferException(
        'РЎР‚Р ВµР Т‘Р В»Р С•Р В¶Р ВµР Р…Р С‘Р Вµ Р Р†Р С•Р Т‘Р С‘РЎвЂљР ВµР В»РЎРЏ Р Т‘Р С•Р В»Р В¶Р Р…Р С• Р В±РЎвЂ№РЎвЂљРЎРЉ Р Р†РЎвЂ№РЎв‚¬Р Вµ РЎвЂ Р ВµР Р…РЎвЂ№ Р С—Р В°РЎРѓРЎРѓР В°Р В¶Р С‘РЎР‚Р В°.',
      );
    }

    if (price > OrderPriceService.maximumOrderPrice) {
      throw const OrderOfferException(
        'Р В¦Р ВµР Р…Р В° Р С—РЎР‚Р ВµР Т‘Р В»Р С•Р В¶Р ВµР Р…Р С‘РЎРЏ Р Р…Р Вµ Р СР С•Р В¶Р ВµРЎвЂљ Р С—РЎР‚Р ВµР Р†РЎвЂ№РЎв‚¬Р В°РЎвЂљРЎРЉ 1 000 000 РІвЂљС‘.',
      );
    }
  }

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw const OrderOfferException(
        'Р С•Р в„–Р Т‘Р С‘РЎвЂљР Вµ Р Р† Р В°Р С”Р С”Р В°РЎС“Р Р…РЎвЂљ, РЎвЂЎРЎвЂљР С•Р В±РЎвЂ№ Р С—РЎР‚Р С•Р Т‘Р С•Р В»Р В¶Р С‘РЎвЂљРЎРЉ.',
      );
    }

    return user;
  }

  String _messageForApiError(TulparApiException error) {
    switch (error.statusCode) {
      case 400:
        return error.message;
      case 401:
        return 'Р С•Р в„–Р Т‘Р С‘РЎвЂљР Вµ Р Р† Р В°Р С”Р С”Р В°РЎС“Р Р…РЎвЂљ, РЎвЂЎРЎвЂљР С•Р В±РЎвЂ№ Р С—РЎР‚Р С•Р Т‘Р С•Р В»Р В¶Р С‘РЎвЂљРЎРЉ.';
      case 403:
        return 'Р ВµР Т‘Р С•РЎРѓРЎвЂљР В°РЎвЂљР С•РЎвЂЎР Р…Р С• Р С—РЎР‚Р В°Р Р† Р Т‘Р В»РЎРЏ РЎРЊРЎвЂљР С•Р С–Р С• Р Т‘Р ВµР в„–РЎРѓРЎвЂљР Р†Р С‘РЎРЏ.';
      case 404:
        return 'Р В°Р С”Р В°Р В· Р С‘Р В»Р С‘ Р С—РЎР‚Р ВµР Т‘Р В»Р С•Р В¶Р ВµР Р…Р С‘Р Вµ Р В±Р С•Р В»РЎРЉРЎв‚¬Р Вµ Р Р…Р Вµ РЎРѓРЎС“РЎвЂ°Р ВµРЎРѓРЎвЂљР Р†РЎС“Р ВµРЎвЂљ.';
      case 409:
        return error.message;
      default:
        return 'Р Вµ РЎС“Р Т‘Р В°Р В»Р С•РЎРѓРЎРЉ Р С•Р В±РЎР‚Р В°Р В±Р С•РЎвЂљР В°РЎвЂљРЎРЉ Р С—РЎР‚Р ВµР Т‘Р В»Р С•Р В¶Р ВµР Р…Р С‘Р Вµ. Р С•Р С—РЎР‚Р С•Р В±РЎС“Р в„–РЎвЂљР Вµ Р ВµРЎвЂ°РЎвЂ РЎР‚Р В°Р В·.';
    }
  }
}
