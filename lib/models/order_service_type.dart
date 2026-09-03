import 'package:flutter/material.dart';

enum OrderServiceType {
  city('city', 'Такси', Icons.local_taxi),
  delivery('delivery', 'Доставка', Icons.local_shipping_outlined),
  intercity('intercity', 'Межгород', Icons.route);

  const OrderServiceType(this.apiValue, this.title, this.icon);

  final String apiValue;
  final String title;
  final IconData icon;

  bool get isDelivery => this == OrderServiceType.delivery;
  bool get isIntercity => this == OrderServiceType.intercity;
  bool get isImplemented => true;
  String get driverOrderLabel => title.toUpperCase();
  String get newDriverOrderMessage => 'Новый заказ — $driverOrderLabel';

  static OrderServiceType fromValue(Object? value) {
    return OrderServiceType.values.firstWhere(
      (type) => type.apiValue == value?.toString(),
      orElse: () => OrderServiceType.city,
    );
  }

  String get passengerSearchingText => switch (this) {
    OrderServiceType.delivery => 'Поиск свободного курьера...',
    OrderServiceType.intercity => 'Поиск водителя для межгорода...',
    OrderServiceType.city => 'Поиск свободного водителя...',
  };

  String get passengerAcceptedText => switch (this) {
    OrderServiceType.delivery => 'Курьер едет за посылкой',
    OrderServiceType.city ||
    OrderServiceType.intercity => 'Водитель едет к вам',
  };

  String get passengerArrivedText => switch (this) {
    OrderServiceType.delivery => 'Курьер прибыл за посылкой',
    OrderServiceType.intercity => 'Водитель прибыл',
    OrderServiceType.city => 'Водитель на месте и ожидает вас!',
  };

  String get passengerArrivedHint => isDelivery
      ? 'Передайте посылку курьеру'
      : 'Пожалуйста, выходите к автомобилю';

  String get passengerInProgressText => switch (this) {
    OrderServiceType.delivery => 'Посылка в пути',
    OrderServiceType.intercity => 'Поездка началась',
    OrderServiceType.city => 'Поездка в процессе',
  };

  String get passengerCompletedText => switch (this) {
    OrderServiceType.delivery => 'Доставка завершена',
    OrderServiceType.intercity => 'Междугородняя поездка завершена',
    OrderServiceType.city => 'Поездка завершена!',
  };

  String get driverSectionTitle => switch (this) {
    OrderServiceType.city => 'Заказы такси',
    OrderServiceType.delivery => 'Заказы доставки',
    OrderServiceType.intercity => 'Межгород',
  };
}
