import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

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

extension LocalizedOrderServiceType on OrderServiceType {
  String localizedTitle(AppLocalizations l10n) => switch (this) {
    OrderServiceType.city => l10n.serviceCity,
    OrderServiceType.delivery => l10n.serviceDelivery,
    OrderServiceType.intercity => l10n.serviceIntercity,
  };

  String localizedDriverSectionTitle(AppLocalizations l10n) => switch (this) {
    OrderServiceType.city => l10n.driverCityOrders,
    OrderServiceType.delivery => l10n.driverDeliveryOrders,
    OrderServiceType.intercity => l10n.serviceIntercity,
  };

  String localizedSearchingText(AppLocalizations l10n) => switch (this) {
    OrderServiceType.city => l10n.statusSearchingDriver,
    OrderServiceType.delivery => l10n.statusSearchingCourier,
    OrderServiceType.intercity => l10n.statusSearchingIntercity,
  };

  String localizedAcceptedText(AppLocalizations l10n) =>
      isDelivery ? l10n.statusCourierComing : l10n.statusDriverComing;

  String localizedArrivedText(AppLocalizations l10n) => switch (this) {
    OrderServiceType.city => l10n.statusDriverArrived,
    OrderServiceType.delivery => l10n.statusCourierArrived,
    OrderServiceType.intercity => l10n.statusIntercityDriverArrived,
  };

  String localizedArrivedHint(AppLocalizations l10n) =>
      isDelivery ? l10n.statusHandPackage : l10n.statusGoToCar;

  String localizedInProgressText(AppLocalizations l10n) => switch (this) {
    OrderServiceType.city => l10n.statusTripInProgress,
    OrderServiceType.delivery => l10n.statusPackageOnWay,
    OrderServiceType.intercity => l10n.statusTripStarted,
  };

  String localizedCompletedText(AppLocalizations l10n) => switch (this) {
    OrderServiceType.city => l10n.statusTripCompleted,
    OrderServiceType.delivery => l10n.statusDeliveryCompleted,
    OrderServiceType.intercity => l10n.statusIntercityCompleted,
  };
}
